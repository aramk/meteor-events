Events =

  config: (options) ->
    unless @_options
      options = Setter.merge {
        resolveDoc: (collectionId, docId) -> null
      }, options
      @_options = options
      setUpPubSub()
      UserEventStats.config(options)
    @_options

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
  eventsCollection = Events.getCollection()
  if Meteor.isServer
    
    publications = {}
    MIN_PUBLISH_LIMIT = 10
    PUBLISH_INCREMENT = 10

    eventsCollection.after.insert (userId, event) ->
      pub = publications[userId]
      pub?.addEvent(event._id, event, {freeNecessarySpace: true})
    
    eventsCollection.after.update (userId, event) ->
      pub = publications[userId]
      id = event._id
      return unless @addedMap[id] and pub?
      pub.changed(collectionId, id, event)
    
    eventsCollection.after.remove (userId, event) ->
      pub = publications[userId]
      pub?.removeEvent(event._id)
    
    # Ensure changing and removing user events are published to the client. Otherwise
    # modifications on the client will be reject by the server.

    userCollection.after.insert (userId, userEvent) ->
      pub = publications[userId]
      id = userEvent._id
      # If a new user event is added belonging to an already published event, add it on the
      # client.
      return unless @addedMap[userEvent.eventId] and pub?
      pub.added(userCollectionId, id, userEvent)
      pub.addedUserMap[id] = true

    userCollection.after.update (userId, userEvent) ->
      pub = publications[userId]
      id = userEvent._id
      return unless pub? and pub.addedUserMap[id]
      pub.changed(userCollectionId, id, userEvent)

    userCollection.after.remove (userId, userEvent) ->
      pub = publications[userId]
      id = userEvent._id
      return unless pub? and pub.addedUserMap[id]
      delete pub.addedUserMap[id]
      pub.removed(userCollectionId, id)

    Meteor.publish 'events', ->
      unless @userId then throw new Meteor.Error(403, 'User must exist for user events publication')

      publications[@userId] = @
      Logger.info "Created events publication for user #{@userId}"
      console.log('>>> 1')
      @eventsCursor = Events.findByUser(@userId, limit: MIN_PUBLISH_LIMIT)
      console.log('>>> 2')
      initializing = true
      @reactiveLimit = new ReactiveVar(MIN_PUBLISH_LIMIT)
      @addedMap = addedMap = {}
      @addedUserMap = addedUserMap = {}
      addedCount = 0

      @addEvent = (id, event, options) =>
        if addedCount >= @reactiveLimit.get()
          if options?.freeNecessarySpace
            # Remove the oldest event to make room for the new event.
            sortedEvents = _.sortBy _.values(addedMap), (event) -> event.dateCreated.getTime()
            oldId = sortedEvents[0]?._id
            @removeEvent(oldId) if oldId?
          # Falls through if space could not be freed.
          return if addedCount >= @reactiveLimit.get()
        return if addedMap[id]?
        @added(collectionId, id, event)
        # Also publish any collections related to the event.
        if event.doc?
          doc = Events.config().resolveDoc(event.doc.collection, event.doc.id)
          if doc then @added(event.doc.collection, event.doc.id, doc)
        addedMap[id] = event
        event._id = id
        addedCount++
        userCollection.find(eventId: id).forEach (userEvent) =>
          @added(userCollectionId, userEvent._id, userEvent)
          addedUserMap[userEvent._id] = true

      @removeEvent = (id) =>
        return unless addedMap[id]
        @removed(collectionId, id)
        delete addedMap[id]
        addedCount--
        collection.find(eventId: id).forEach (userEvent) =>
          return unless addedUserMap[userEvent._id]
          @removed(userCollectionId, userEvent._id)
          delete addedUserMap[userEvent._id]

      # observeHandle = @eventsCursor.observeChanges
      #   added: (id, event) ->
      #     return if initializing
      #     addEvent(id, event, {freeNecessarySpace: true})
      #   changed: (id, event) =>
      #     return unless addedMap[id]
      #     @changed(collectionId, id, event)
      #   removed: (id) -> removeEvent(id)

      console.log('>>> 3')

      # Ensure changing and removing user events are published to the client. Otherwise
      # modifications on the client will be reject by the server.
      # userObserveHandle = userCollection.find().observeChanges
      #   added: (id, userEvent) =>
      #     # If a new user event is added belonging to an already published event, add it on the
      #     # client.
      #     return unless addedMap[userEvent.eventId]
      #     @added(userCollectionId, id, userEvent)
      #     addedUserMap[id] = true
      #   changed: (id, userEvent) =>
      #     return unless addedUserMap[id]
      #     @changed(userCollectionId, id, userEvent)
      #   removed: (id) =>
      #     return unless addedUserMap[id]
      #     delete addedUserMap[id]
      #     @removed(userCollectionId, id)

      console.log('>>> 4')

      trackerHandle = Tracker.autorun =>
        limit = @reactiveLimit.get()
        @eventsCursor.forEach (event) => @addEvent(event._id, event)
        Logger.info "Published #{addedCount} initial events"

      console.log('>>> 5')

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
