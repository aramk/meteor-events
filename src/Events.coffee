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

  findByUser: (userId) ->
    selector = @getUserSelector(userId)
    collection.find(selector)

  getUserSelector: (userId) ->
    user = Meteor.users.findOne(_id: userId)
    unless user then throw new Error("Invalid User ID: #{userId}")
    # Ensure the user IDs and roles match, or there are no access restrictions.
    selector = $or: [{'access.userIds': $in: [userId]}, {access: $exists: false}]
    unless _.isEmpty(user.roles) then selector.$or.push {'access.roles': $in: user.roles}
    selector

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
    Meteor.publish 'events', ->
      unless @userId then throw new Meteor.Error(403, 'User must exist for user events publication')

      eventsCursor = Events.findByUser(@userId)
      initializing = true

      addEvents = (id, event) =>
        @added(collectionId, id, event)
        userCollection.find(eventId: id).forEach (userEvent) =>
          @added(userCollectionId, userEvent._id, userEvent)

      observeHandle = eventsCursor.observeChanges
        added: (id, event) ->
          return if initializing?
          addEvents(id, event)
        changed: (id, event) =>
          @changed(collectionId, event._id, event)
        removed: (id) =>
          @removed(collectionId, id)
          collection.find(eventId: id).forEach (userEvent) =>
            @removed(userCollectionId, userEvent._id)

      eventsCursor.forEach (event) -> addEvents(event._id, event)

      Logger.info "Published #{eventsCursor.count()} events"

      initializing = false
      @ready()
      @onStop ->
        observeHandle.stop()

      # Signal that we plan to use manual methods above.
      return undefined

  else
    Tracker.autorun ->
      userId = Meteor.userId()
      return unless userId?
      Meteor.subscribe('events')
