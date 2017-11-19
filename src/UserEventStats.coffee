UserEventStats =

  # Limit value to avoid excessive width.
  MAX_COUNT: 100

  config: (args={}) ->
    return if @_isConfig
    setUpPubSub()
    if Meteor.isServer and args.watchEvents != false then @_setUpEventWatcher()
    @_isConfig = true

  getCollection: -> collection

  get: (userId) ->
    if Meteor.isClient
      userId = Meteor.userId()
    collection.findOne(userId: userId)

schema = new SimpleSchema
  userId:
    type: String
    index: true
  unreadCount:
    type: Number
  # The date since the user read all events.
  readAllDate:
    type: Date
    index: true

collection = new Meteor.Collection('userEventStats')
collection.attachSchema(schema)
# Only server-side can create event stats.
collection.allow
  insert: -> false
  update: -> false
  remove: -> false

setUpPubSub = ->
  if Meteor.isServer
    Meteor.publish 'userEventStats', ->
      return unless @userId
      collection.find(userId: @userId)
  else
    Meteor.subscribe('userEventStats')

return unless Meteor.isServer

eventsCollection = Events.getCollection()
userEventsCollection = UserEvents.getCollection()

_.extend UserEventStats,

  _isSetUp: false

  _setUpEventWatcher: () ->
    return if @_isSetUp
    updateAllUsers = _.throttle Meteor.bindEnvironment((userId, doc)=>
      # UserEvents collection is targeted at a single user.
      if doc.userId?
        @_setUnreadCount(doc.userId)
      else
        Meteor.users.find().forEach (user) => @_setUnreadCount(user._id)
    ), 5000
    eventsCollection.after.insert(updateAllUsers)
    userEventsCollection.after.insert(updateAllUsers)
    @_isSetUp = true

  getStats: (userId) ->
    unless Meteor.users.findOne(_id: userId) then throw new Error('Invalid User ID')
    stats = collection.findOne(userId: userId)
    unless stats
      collection.insert {userId: userId, unreadCount: 0, readAllDate: new Date()}
      stats = collection.findOne(userId: userId)
    stats

  _setUnreadCount: (userId, options) ->
    count = @getUnreadCount(userId, options)
    collection.update {userId: userId}, {$set: {unreadCount: count}}

  getUnreadCount: (userId, options) ->
    options = Setter.merge {ignoreMax: false}, options
    unread = 0
    stats = collection.findOne(userId: userId)
    if stats?
      # If unread count is already at maximum, no point in querying until events are read.
      if !options.ignoreMax and stats.unreadCount >= UserEventStats.MAX_COUNT then return UserEventStats.MAX_COUNT
      readAllDate = stats.readAllDate
      eventSelector = Events.getUserSelector(userId)
      # Consider all events before read all date as read.
      if readAllDate
        eventSelector = $and: [eventSelector, {dateCreated: $gt: readAllDate}]
      eventsCollection.find(eventSelector, {limit: UserEventStats.MAX_COUNT}).forEach (event) ->
        unread++ unless UserEvents.isRead(userId: userId, eventId: event._id)
    return unread

  readAll: (userId) ->
    collection.update {userId: userId}, {$set: readAllDate: new Date()}
    @_setUnreadCount(userId, ignoreMax: true)

# Create stats on first login.
Accounts.onLogin Meteor.bindEnvironment (info) -> UserEventStats.getStats(info.user._id)

Meteor.methods

  'userEvents/readAll': ->
    AccountsUtil.authorizeUser(@userId)
    UserEventStats.readAll(@userId)
