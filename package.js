// Meteor package definition.
Package.describe({
  name: 'aramk:events',
  version: '0.1.0',
  summary: 'User activity events',
  git: 'https://github.com/aramk/meteor-events.git'
});

Package.onUse(function (api) {
  api.versionsFrom('METEOR@0.9.0');
  api.use([
    'accounts-password',
    'coffeescript',
    'underscore',
    'reactive-var@1.0.4',
    'tracker@1.0.5',

    'aldeed:simple-schema@1.3.2',
    'aldeed:collection2@2.3.3',
    'aramk:q@1.0.1_1',
    'digilord:roles@1.2.12',
    'peerlibrary:server-autorun@0.5.1',
    'urbanetic:accounts-ui@0.5.0',
    'urbanetic:utility@1.0.1'
  ]);
  api.use([
    'semantic:ui-css@2.0.8'
  ], {weak: true});
  api.export([
    'Events',
    'UserEvents',
    'UserEventStats'
    ]);
  api.addFiles([
    'src/Events.coffee',
    'src/UserEvents.coffee',
    'src/UserEventStats.coffee'
  ]);
});

Package.onTest(function (api) {
  api.use([
    'accounts-password',
    'coffeescript',
    'tinytest',
    'test-helpers',
    'underscore',
    'tracker',

    'digilord:roles',
    'momentjs:moment',
    'practicalmeteor:munit',
    'urbanetic:utility',
    // 'peterellisjones:describe',
    
    'aramk:events'
  ]);

  api.addFiles([
    'tests/fixtures/Fixtures.coffee',
    'tests/fixtures/events.coffee',
    'tests/fixtures/users.coffee',
    'tests/fixtures/userEvents.coffee',

    'tests/setup.coffee',
    'tests/EventsSpec.coffee',
  ]);
});
