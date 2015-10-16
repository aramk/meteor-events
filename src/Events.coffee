Events =

  config: (args) ->
    args = Setter.merge({}, args)

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

schema = new SimpleSchema
  title:
    type: String
    optional: true
  content:
    type: String
    optional: true
  userId:
    type: String
    index: true
    optional: true
  label:
    type: String
    index: true
    optional: true
  dateCreated:
    type: Date
    index: true
  dateRead:
    type: Date
    index: true
    optional: true

collection = new Meteor.Collection('events')
collection.attachSchema(schema)
