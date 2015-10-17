UserEvents =

  getCollection: -> collection

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
