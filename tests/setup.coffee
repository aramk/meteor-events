return unless Meteor.isServer

createRoles = (roles) ->
  existingRoles = Roles.getAllRoles().map (role) -> role.name
  newRoles = _.difference(roles, existingRoles)
  _.each newRoles, (role) -> Roles.createRole(role)

Meteor.users.remove({})
_.each Fixtures.users, (userDoc) ->
  userId = Meteor.users.insert
    _id: userDoc.username
    username: userDoc.username
    profile: userDoc.profile
  Accounts.setPassword(userId, userDoc.password)
  if userDoc.roles
    createRoles(userDoc.roles)
    Roles.setUserRoles(userId, userDoc.roles)
Logger.info 'Users', Meteor.users.find().fetch()

Events.getCollection().remove({})
_.each Fixtures.events, (event) -> Events.add(event)

UserEvents.getCollection().remove({})
_.each Fixtures.userEvents, (userEvent) -> UserEvents.getCollection().insert(userEvent)
