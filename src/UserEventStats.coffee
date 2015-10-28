UserEventStats =

  config: (args) ->
    return if @_isConfig
    setUpPubSub()
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

_.extend UserEventStats,

  _setUpMap: null

  setUp: (userId) ->
    @_setUpMap ?= {}
    return if @_setUpMap[userId]
    @_initStats(userId)
    @_updateCountReactive(userId)
    @_setUpMap[userId] = true

  _initStats: (userId) ->
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
    @_updateCountReactive(userId)

  _updateCountReactive: (userId) ->
    onEventChange = _.throttle Meteor.bindEnvironment =>
      @_setUnreadCount(userId)
    , 1000

    Collections.observe Events.getCollection(), onEventChange
    Collections.observe UserEvents.getCollection(), onEventChange

    onEventChange()

Accounts.onLogin Meteor.bindEnvironment (info) -> UserEventStats.setUp(info.user._id)

Meteor.methods

  'userEvents/readAll': ->
    AccountsUtil.authorizeUser(@userId)
    UserEventStats.readAll(@userId)
