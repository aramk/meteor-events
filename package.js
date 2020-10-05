// Meteor package definition.
Package.describe({
  name: 'aramk:events',
  version: '1.3.0',
  summary: 'User activity events',
  git: 'https://github.com/aramk/meteor-events.git'
});

Package.onUse(function (api) {
  api.versionsFrom('METEOR@1.10.2');
  api.use([
    'accounts-password',
    'coffeescript@2.2.1_1',
    'underscore',
    'reactive-var@1.0.4',
    'tracker@1.0.5',

    'aldeed:simple-schema@1.3.2',
    'aldeed:collection2@2.3.3',
    'aramk:q@1.0.1_1',
    'digilord:roles@1.2.12',
    'matb33:collection-hooks@0.8.4',
    'peerlibrary:server-autorun@0.8.0',
    'urbanetic:accounts-ui@1.1.0',
    'urbanetic:utility@2.0.1'
  ]);
  api.use([
    'aramk:semantic-ui@2.4.1'
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

// TODO(aramk) Fails to build old packages depending on coffeescript v1.
// Package.onTest(function (api) {
//   api.use([
//     'accounts-password',
//     'coffeescript',
//     'tinytest',
//     'test-helpers',
//     'underscore',
//     'tracker',

//     'digilord:roles',
//     'momentjs:moment',
//     'practicalmeteor:munit',
//     'urbanetic:accounts-ui',
//     'urbanetic:utility',
//     // 'peterellisjones:describe',

//     'aramk:events'
//   ]);

//   api.addFiles([
//     'tests/fixtures/Fixtures.coffee',
//     'tests/fixtures/events.coffee',
//     'tests/fixtures/users.coffee',
//     'tests/fixtures/userEvents.coffee',

//     'tests/setup.coffee',
//     'tests/EventsSpec.coffee',
//   ]);
// });
