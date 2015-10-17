Events =

  config: (args) ->
    args = Setter.merge({}, args)

    return if @_isConfig
    setUpPubSub()
    @_isConfig = true

  parse: (arg) ->
    if Types.isString(arg)
      arg = {content: arg}
    if Types.isObjectLiteral(arg)
      arg.dateCreated ?= new Date()
      return arg
      # args.userId = AccountsUtil.resolveUser()?._id
    else
      throw new Error('Invalid event argument: ' + arg)

  add: (arg) ->
    df = Q.defer()
    parsed = @parse(arg)
    collection.insert arg, Promises.toCallback(df)
    df.promise

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
    selector = $or: [{'access.userIds': $in: [userId]}]
    unless _.isEmpty(user.roles) then selector.$or.push {'access.roles': $in: user.roles}
    selector

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

# pubs = {}

setUpPubSub = ->
  if Meteor.isServer
    Meteor.publish 'events', ->
      unless @userId then throw new Meteor.Error(403, 'User must exist for events publication')

      selector = Events.getUserSelector(@userId)
      options =
        sort: dateCreated: -1
        limit: 10
      collection.find(selector, options)
  else
    Tracker.autorun ->
      userId = Meteor.userId()
      return unless userId?
      Meteor.subscribe('events')

  # if Meteor.isServer
  #   Meteor.publish 'events', (args) ->
  #     return unless @userId

  #     # subscriptionId = args.subscriptionId
  #     # unless subscriptionId
  #     #   throw new Error('Subscription ID not provided')
  #     # pubs[@subscriptionId] ?= @

  #     selector = $or: [
  #       {userId: $exists: false}
  #       {userId: @userId}
  #     ]

  #     options =
  #       sort: dateCreated: -1
  #       limit: 10
      
  #     cursor = collection.find(selector, options)

  #     console.log 'cursor', cursor.count()

  #     return cursor

  #     # initializing = true

  #     # Signal that we plan to use manual methods above.
  #     # return undefined
  # else
  #   subscriptionId = Collections.generateId()
  #   Meteor.subscribe 'events', subscriptionId: subscriptionId

# return unless Meteor.isServer

# Meteor.methods

#   'events/unreadCount': (args) ->
#     collection.find(userId: @userId).count()

#   'events/clearAll': ->
#     selector = {userId: @userId, dateRead: $exists: false}
#     collection.update selector, {dateRead: $exists: new Date()}, {multi: true}
