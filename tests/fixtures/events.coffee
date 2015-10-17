Fixtures.events = [
  {
    _id: 'event1'
    title: 'Test Event'
    content: 'This is a test'
    label: 'foo'
    dateCreated: new Date('2015-10-10T15:00:00+11:00')
    access:
      userIds: ['user1']
  }
  {
    _id: 'event2'
    title: 'Test Event'
    content: 'This is a test'
    label: 'bar'
    dateCreated: new Date('2015-10-10T16:00:00+11:00')
    access:
      roles: ['reader']
  }
  {
    _id: 'event3'
    title: 'Test Event'
    content: 'This is a test'
    label: 'foo2'
    dateCreated: new Date('2015-10-10T17:00:00+11:00')
    access:
      roles: ['writer']
  }
]
