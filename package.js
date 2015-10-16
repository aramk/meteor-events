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
    'coffeescript',
    'underscore',
    'reactive-var@1.0.4',
    'tracker@1.0.5',
    'aldeed:simple-schema@1.3.2',
    'aldeed:collection2@2.3.3',
    'aramk:q@1.0.1_1',
    'urbanetic:utility@1.0.1'
  ], ['client', 'server']);
  api.use([
    'semantic:ui-css@2.0.8'
  ], {weak: true});
  api.imply('semantic:ui-css');
  api.export('Events', ['client', 'server']);
  api.addFiles([
    'src/Events.coffee'
  ], ['client', 'server']);
});
