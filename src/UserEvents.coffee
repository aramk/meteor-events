UserEvents =

  getCollection: -> collection

  read: (selector) ->
    unless selector.eventId? and selector.userId?
      throw new Error('Selector must have event ID and user ID')
    docs = collection.find(selector).fetch()
    count = _.size(docs)
    if count > 1
      throw new Error "Marking user events as read matched #{count} documents instead of 1"
    else if count == 1 and docs[0].dateRead?
      # Ignore if event is already read.
      return
    else
      newEvent = Setter.merge({dateRead: new Date()}, selector)
      if count == 0
        return collection.insert(newEvent)
      else
        docId = docs[0]._id
        collection.update docId, $set: newEvent
        return docId

  # Can be called on the client assuming docs are synced.
  isRead: (selector) ->
    unless selector.eventId? and selector.userId?
      throw new Error('Selector must have event ID and user ID')
    doc = collection.findOne(selector)
    collection.findOne(selector)?.dateRead? ? false

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
# Only server-side can create events.
allowUser = (userId, doc) -> doc.userId == userId
collection.allow
  insert: -> allowUser
  update: -> allowUser
  remove: -> allowUser

Meteor.methods
  
  'userEvents/read': (selector) ->
    return unless @userId?
    selector.userId = @userId
    UserEvents.read(selector)
