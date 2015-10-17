moduleName = 'Events'
collection = Events.getCollection()

describe moduleName, ->

  beforeAll (test, waitFor) ->
    done = waitFor ->
    Events.config()
    if Meteor.isClient
      Meteor.loginWithPassword 'test1', 'password1', (err, result) ->
        if err then return Logger.error('Failed to log in', err)
        Logger.info('Logged in')
        Meteor.subscribe 'events', ->
          Logger.info('Subscribed')
          done()
    else
      done()

  it 'exists', ->
    expect(Events?).to.be.true

  it 'has docs', ->
    expect(collection.find().count()).not.to.equal(0)

if Meteor.isServer

  describe "#{moduleName} Server", ->

    it 'can find events by roles', ->
      cursor = Events.findByRoles('reader')
      expect(cursor.count()).to.equal(1)
      expect(cursor.fetch()[0].label).equal('bar')

      cursor = Events.findByRoles('writer')
      expect(cursor.count()).to.equal(1)
      expect(cursor.fetch()[0].label).equal('foo2')

    it 'can find events by user IDs', ->
      cursor = Events.findByUser('test1')
      expect(cursor.count()).to.equal(2)
      events = cursor.fetch()
      expect(events[0].label).equal('bar')
      expect(events[1].label).equal('foo')

      cursor = Events.findByUser('test2')
      expect(cursor.count()).to.equal(2)
      events = cursor.fetch()
      expect(events[0].label).equal('bar')
      expect(events[1].label).equal('foo2')

if Meteor.isClient

  describe "#{moduleName} Client", ->

    it 'is logged in', ->
      expect(Meteor.userId()).to.equal('test1')

    it 'can find user events', ->
      cursor = collection.find()
      expect(cursor.count()).to.equal(2)
      events = cursor.fetch()
      expect(events[0].label).equal('bar')
      expect(events[1].label).equal('foo')
