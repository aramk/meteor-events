moduleName = 'Events'
collection = Events.getCollection()

describe moduleName, ->

  beforeAll (test, waitFor) ->
    done = waitFor ->
    Events.config()
    if Meteor.isClient
      Meteor.subscribe('events', done)
    else
      done()

  it 'exists', ->
    expect(Events?).to.be.true

  it 'has docs', ->
    expect(collection.find().count()).not.to.equal(0)

return unless Meteor.isServer

describe "#{moduleName} Server", ->

  it 'can find events by roles', ->
    cursor = Events.findByRoles('reader')
    expect(cursor.count()).to.equal(1)
    expect(cursor.fetch()[0].label).equal('bar')

  it 'can find events by user IDs', ->
    user = Meteor.users.findOne(username: 'test1')
    cursor = Events.findByUser(user._id)
    expect(cursor.count()).to.equal(2)
    events = cursor.fetch()
    expect(events[0].label).equal('bar')
    expect(events[1].label).equal('foo')
