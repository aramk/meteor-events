Events =

  config: (args) ->
    args = Setter.merge({}, args)

    return if @_isConfig
    setUpPubSub()
    UserEventStats.config()
    @_isConfig = true

  parse: (arg) ->
    if Types.isString(arg)
      arg = {content: arg}
    if Types.isObjectLiteral(arg)
      arg.dateCreated ?= new Date()
      return arg
    else
      throw new Error('Invalid event argument: ' + arg)

  getCollection: -> collection

  findByRoles: (roles) ->
    if roles? and Types.isString(roles) then roles = [roles]
    return [] if _.isEmpty(roles)
    collection.find('access.roles': $in: roles)

  findByUser: (userId, options) ->
    options = Setter.merge {sort: dateCreated: -1}, options
    selector = @getUserSelector(userId)
    collection.find(selector, options)

  getUserSelector: (userId) ->
    user = Meteor.users.findOne(_id: userId)
    unless user then throw new Error("Invalid User ID: #{userId}")
    # Ensure the user IDs and roles match, or there are no access restrictions.
    userIdSelector = {'access.userIds': $in: [userId]}
    userIdNotSelector = {'access.excludedUserIds': $nin: [userId]}
    if _.isEmpty(user.roles)
      userIdRoleSelector = userIdSelector
    else
      userIdRoleSelector = {$or: [
        userIdSelector
        {'access.roles': $in: user.roles}
      ]}
    # excludedUserIds must always be honoured.
    userSelectors = {$and: [
      userIdRoleSelector
      userIdNotSelector
    ]}
    selector =
      $or: [
        userSelectors
        {access: $exists: false}
      ]

if Meteor.isServer then _.extend Events,

  add: (arg) -> collection.insert(@parse(arg))

schema = new SimpleSchema
  title:
    type: String
    optional: true
  content:
    type: String
    optional: true
  label:
    type: String
    index: true
    optional: true
  dateCreated:
    type: Date
    index: true
  'access.roles':
    type: [String]
    optional: true
    index: true
  'access.userIds':
    type: [String]
    optional: true
    index: true
  'access.excludedUserIds':
    type: [String]
    optional: true
    index: true
  # Document associated with the event.
  'doc.collection':
    type: String
    optional: true
    index: true
  'doc.id':
    type: String
    optional: true
    index: true

collection = new Meteor.Collection('events')
collection.attachSchema(schema)
# Only server-side can create events.
collection.allow
  insert: -> false
  update: -> false
  remove: -> false

setUpPubSub = ->
  collectionId = Collections.getName(collection)
  userCollection = UserEvents.getCollection()
  userCollectionId = Collections.getName(userCollection)
  if Meteor.isServer
    
    publications = {}
    MIN_PUBLISH_LIMIT = 10
    PUBLISH_INCREMENT = 10

    Meteor.publish 'events', ->
      unless @userId then throw new Meteor.Error(403, 'User must exist for user events publication')

      publications[@userId] = @
      Logger.info "Created events publication for user #{@userId}"
      @eventsCursor = Events.findByUser(@userId)
      initializing = true
      @reactiveLimit = new ReactiveVar(MIN_PUBLISH_LIMIT)
      addedMap = {}
      addedUserMap = {}
      addedCount = 0

      addEvent = (id, event, options) =>
        if addedCount >= @reactiveLimit.get()
          if options?.freeNecessarySpace
            # Remove the oldest event to make room for the new event.
            sortedEvents = _.sortBy _.values(addedMap), (event) -> event.dateCreated.getTime()
            oldId = sortedEvents[0]?._id
            removeEvent(oldId) if oldId?
          # Falls through if space could not be freed.
          return if addedCount >= @reactiveLimit.get()
        return if addedMap[id]?
        @added(collectionId, id, event)
        addedMap[id] = event
        event._id = id
        addedCount++
        userCollection.find(eventId: id).forEach (userEvent) =>
          @added(userCollectionId, userEvent._id, userEvent)
          addedUserMap[userEvent._id] = true

      removeEvent = (id) =>
        return unless addedMap[id]
        @removed(collectionId, id)
        delete addedMap[id]
        addedCount--
        collection.find(eventId: id).forEach (userEvent) =>
          return unless addedUserMap[userEvent._id]
          @removed(userCollectionId, userEvent._id)
          delete addedUserMap[userEvent._id]

      observeHandle = @eventsCursor.observeChanges
        added: (id, event) ->
          return if initializing
          addEvent(id, event, {freeNecessarySpace: true})
        changed: (id, event) =>
          return unless addedMap[id]
          @changed(collectionId, id, event)
        removed: (id) -> removeEvent(id)

      # Ensure changing and removing user events are published to the client. Otherwise
      # modifications on the client will be reject by the server.
      userObserveHandle = userCollection.find().observeChanges
        added: (id, userEvent) =>
          # If a new user event is added belonging to an already published event, add it on the
          # client.
          return unless addedMap[userEvent.eventId]
          @added(userCollectionId, id, userEvent)
          addedUserMap[id] = true
        changed: (id, userEvent) =>
          return unless addedUserMap[id]
          @changed(userCollectionId, id, userEvent)
        removed: (id) =>
          return unless addedUserMap[id]
          delete addedUserMap[id]
          @removed(userCollectionId, id)

      trackerHandle = Tracker.autorun =>
        limit = @reactiveLimit.get()
        @eventsCursor.forEach (event) -> addEvent(event._id, event)
        Logger.info "Published #{addedCount} initial events"

      initializing = false
      @ready()
      @onStop =>
        delete publications[@userId]
        observeHandle.stop()
        userObserveHandle.stop()

      # Signal that we plan to use manual methods above.
      return undefined

    getAuthorizedPub = (userId) ->
      AccountsUtil.authorizeUser(userId)
      pub = publications[userId]
      unless pub
        throw new Meteor.Error(500, "Publication not found for userId #{userId}")
      pub

    Meteor.methods

      'events/publish/more': ->
        pub = getAuthorizedPub(@userId)
        limit = pub.reactiveLimit.get()
        maxLimit = pub.eventsCursor.count()
        newLimit = Math.max(Math.min(limit + PUBLISH_INCREMENT, maxLimit), MIN_PUBLISH_LIMIT)
        pub.reactiveLimit.set(newLimit)

      'events/publish/count': ->
        pub = getAuthorizedPub(@userId)
        limit = pub.reactiveLimit.get()
        maxLimit = pub.eventsCursor.count()
        {published: limit, total: maxLimit}

  else
    subscribeDf = Q.defer()
    Events.subscribe = -> subscribeDf.promise
    Tracker.autorun ->
      userId = Meteor.userId()
      return unless userId?
      Meteor.subscribe 'events', -> subscribeDf.resolve()
