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
    # Events created in the past are ignored when UserEventStats is initialised for a new user.
    # expect(UserEventStats.get().unreadCount).to.equal(0) if Meteor.isClient
    docId = UserEvents.read(selector)
    expect(UserEvents.isRead(selector)).to.be.true
    # expect(UserEventStats.get().unreadCount).to.equal(0) if Meteor.isClient

    # Ensure server changes are not synced to the client cause the test to fail.
    userCollection.remove(docId)
    expect(UserEvents.isRead(selector)).to.be.false
    # expect(UserEventStats.get().unreadCount).to.equal(0) if Meteor.isClient

if Meteor.isServer

  describe "#{moduleName} Server", ->

    it 'can find events by roles', ->
      cursor = Events.findByRoles('reader')
      expect(cursor.count()).to.equal(2)
      expect(cursor.fetch()[0].label).equal('bar')

      cursor = Events.findByRoles('writer')
      expect(cursor.count()).to.equal(1)
      expect(cursor.fetch()[0].label).equal('foo2')

    it 'can find events by user IDs', ->
      cursor = Events.findByUser('user1')
      expect(cursor.count()).to.equal(3)
      labels = cursor.map (event) -> event.label
      expect(_.difference(['bar', 'foo', 'foo3'], labels).length).to.equal(0)

      cursor = Events.findByUser('user2')
      expect(cursor.count()).to.equal(3)
      events = cursor.fetch()
      labels = cursor.map (event) -> event.label
      expect(_.difference(['bar', 'foo2'], labels).length).to.equal(0)

if Meteor.isClient

  describe "#{moduleName} Client", ->

    it 'is logged in', ->
      expect(Meteor.userId()).to.equal('user1')

    it 'can find events for users', ->
      cursor = collection.find()
      expect(cursor.count()).to.equal(3)
      labels = cursor.map (event) -> event.label
      expect(_.difference(['bar', 'foo', 'foo3'], labels).length).to.equal(0)

    it 'has user events', ->
      cursor = userCollection.find()
      expect(cursor.count()).to.equal(1)
      userEvents = cursor.fetch()
      expect(userEvents[0].eventId).equal('event1')

    it 'can get read count for events', ->
      expect(UserEventStats.getCollection().find().count()).to.equal(1)
      stats = UserEventStats.get()
      expect(stats.unreadCount).to.equal(1)
      expect(stats.readAllDate instanceof Date).to.be.true

    it 'can update read count', (test, waitFor) ->
      done = waitFor ->
      expect(UserEventStats.get().unreadCount).to.equal(1)

      selector = userId: 'user1', eventId: 'event4'
      expect(UserEvents.isRead(selector)).to.be.false
      docId = UserEvents.read(selector)
      expect(UserEvents.isRead(selector)).to.be.true

      _.delay ->
        expect(UserEventStats.get().unreadCount).to.equal(0)
        done()
      , 1000
