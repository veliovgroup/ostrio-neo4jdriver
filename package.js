Package.describe({
  name: 'ostrio:neo4jdriver',
  summary: 'Most advanced and efficient Neo4j REST API client, with support of https and GrapheneDB',
  version: '1.1.2',
  git: 'https://github.com/VeliovGroup/ostrio-neo4jdriver.git'
});

Package.onUse(function (api) {
  api.versionsFrom('1.3');
  api.use('ecmascript', 'server');
  api.mainModule('driver.js', 'server');
});

Package.onTest(function (api) {
  api.use([
    'modules',
    'ecmascript',
    'coffeescript',
    'ostrio:neo4jdriver',
    'tinytest',
    'underscore',
    'ejson'
  ], 'server');
  api.addFiles(['tests.coffee'], 'server');
});

Npm.depends({
  'neo4j-fiber': '1.0.3'
});
