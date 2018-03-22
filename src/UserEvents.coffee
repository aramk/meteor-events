UserEvents =

  getCollection: -> collection

  # TODO(aramk) Run read() and unread() on the server to avoid a bug where publications cause a
  # newly created doc on the client toe be removed and re-added, trigger unnecessary logic.

  read: (selector) ->
    validateSelector(selector)
    docs = collection.find(selector).fetch()
    count = _.size(docs)
    if count > 1
      throw new Error "Marking user events as read matched #{count} documents instead of 1"
    else if count == 1 and docs[0].dateRead?
      # Ignore if event is already read.
      return
    else
      if Meteor.isClient then return Promises.serverMethodCall('userEvents/read', selector)
      newEvent = Setter.merge({dateRead: new Date()}, selector)
      if count == 0
        return collection.insert(newEvent)
      else
        docId = docs[0]._id
        collection.update docId, $set: newEvent
        return docId

  unread: (selector) ->
    # if Meteor.isClient then return Promises.serverMethodCall('userEvents/unread', selector)
    validateSelector(selector)
    collection.find(selector).forEach (doc) ->
      collection.remove(doc._id)  

  # Can be called on the client assuming docs are synced.
  isRead: (selector) -> @getDateRead(selector)? ? false

  getDateRead: (selector) ->
    validateSelector(selector)
    doc = collection.findOne(selector)
    collection.findOne(selector)?.dateRead

validateSelector = (selector) ->
  msg = 'Selector must have event ID and user ID'
  unless selector?
    throw new Error(msg)
  selector.userId ?= AccountsUtil.resolveUser()?._id
  unless selector.eventId? and selector.userId?
    throw new Error(msg)

schema = new SimpleSchema
  eventId:
    type: String
    index: true
  userId:
    type: String
    index: true
  dateRead:
    type: Date
    index: true

collection = new Meteor.Collection('userEvents')
collection.attachSchema(schema)
allowUser = (userId, doc) -> doc.userId == userId
collection.allow
  insert: -> allowUser
  update: -> allowUser
  remove: -> allowUser

# Prevent creating more than once user event for a given eventId and userId combination.

Collections.addValidation collection, (doc) ->
  return if @action == 'remove'
  if collection.findOne(eventId: doc.eventId, userId: doc.userId)
    throw new Error("Cannot add user event with existing eventId and userId combination: #{doc}")

if Meteor.isServer then Meteor.methods
  
  'userEvents/read': (selector) ->
    AccountsUtil.authorizeUser(@userId)
    selector.userId = @userId
    UserEvents.read(selector)

  'userEvents/unread': (selector) ->
    AccountsUtil.authorizeUser(@userId)
    selector.userId = @userId
    UserEvents.unread(selector)

  'userEvents/isRead': (selector) ->
    AccountsUtil.authorizeUser(@userId)
    selector.userId = @userId
    UserEvents.isRead(selector)
