UserEventStats =

  config: (args) ->
    return if @_isConfig
    setUpPubSub()
    if Meteor.isServer then @_setUpEventWatcher()
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

  _setUpEventWatcher: () ->
    updateAllUsers = _.throttle Meteor.bindEnvironment(=>
      Meteor.user.find().forEach (user) => @_setUnreadCount(user._id)
    ), 1000
    eventsCollection.after.insert(updateAllUsers)
    userEventsCollection.after.insert(updateAllUsers)

  getStats: (userId) ->
    unless Meteor.users.findOne(_id: userId) then throw new Error('Invalid User ID')
    stats = collection.findOne(userId: userId)
    unless stats
      collection.insert {userId: userId, unreadCount: 0, readAllDate: new Date()}
      stats = collection.findOne(userId: userId)
    stats

  _setUnreadCount: (userId) ->
    count = @getUnreadCount(userId)
    collection.update {userId: userId}, $set: unreadCount: count

  getUnreadCount: (userId) ->
    stats = collection.findOne(userId: userId)
    return unless stats?
    readAllDate = stats.readAllDate
    eventSelector = Events.getUserSelector(userId)
    # Consider all events before read all date as read.
    if readAllDate
      eventSelector = $and: [eventSelector, {dateCreated: $gt: readAllDate}]
    unread = 0
    eventsCollection.find(eventSelector).forEach (event) ->
      unread++ unless UserEvents.isRead(userId: userId, eventId: event._id)
    unread

  readAll: (userId) ->
    collection.update {userId: userId}, {$set: readAllDate: new Date()}
    @_setUnreadCount(userId)

# Create stats on first login.
Accounts.onLogin Meteor.bindEnvironment (info) -> UserEventStats.getStats(info.user._id)

Meteor.methods

  'userEvents/readAll': ->
    AccountsUtil.authorizeUser(@userId)
    UserEventStats.readAll(@userId)
