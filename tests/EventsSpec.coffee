moduleName = 'Events'
collection = Events.getCollection()
userCollection = UserEvents.getCollection()

describe moduleName, ->

  beforeAll (test, waitFor) ->
    done = waitFor ->
    Events.config()
    if Meteor.isClient
      Meteor.loginWithPassword 'user1', 'password1', (err, result) ->
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

  it 'can mark events as read', ->
    expect(UserEvents.isRead(userId: 'user1', eventId: 'event1')).to.be.true

    selector = userId: 'user1', eventId: 'event2'
    expect(UserEvents.isRead(selector)).to.be.false
    docId = UserEvents.read(selector)
    expect(UserEvents.isRead(selector)).to.be.true

    # Ensure server changes are not synced to the client cause the test to fail.
    userCollection.remove(docId)
    expect(UserEvents.isRead(selector)).to.be.false

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
      cursor = Events.findByUser('user1')
      expect(cursor.count()).to.equal(2)
      events = cursor.fetch()
      expect(events[0].label).equal('bar')
      expect(events[1].label).equal('foo')

      cursor = Events.findByUser('user2')
      expect(cursor.count()).to.equal(2)
      events = cursor.fetch()
      expect(events[0].label).equal('bar')
      expect(events[1].label).equal('foo2')

if Meteor.isClient

  describe "#{moduleName} Client", ->

    it 'is logged in', ->
      expect(Meteor.userId()).to.equal('user1')

    it 'can find events for users', ->
      cursor = collection.find()
      expect(cursor.count()).to.equal(2)
      events = cursor.fetch()
      expect(events[0].label).equal('bar')
      expect(events[1].label).equal('foo')

    it 'has user events', ->
      cursor = userCollection.find()
      expect(cursor.count()).to.equal(1)
      userEvents = cursor.fetch()
      expect(userEvents[0].eventId).equal('event1')
