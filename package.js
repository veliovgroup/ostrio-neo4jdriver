Package.describe({
  name: 'ostrio:neo4jdriver',
  summary: 'Neo4j REST API client, with support of https and GrapheneDB',
  version: '1.0.0',
  git: 'https://github.com/VeliovGroup/ostrio-neo4jdriver.git'
});

Package.onUse(function(api) {
  api.versionsFrom('1.2.0.1');
  api.use(['check', 'http', 'coffeescript', 'underscore', 'random', 'ejson', 'ecmascript'], 'server');
  api.addFiles([
    'helpers.js',
    'cursor.coffee',
    'data.coffee',
    'relationship.coffee',
    'node.coffee',
    'endpoint.coffee',
    'transaction.coffee',
    'neo4jdriver.coffee'
  ], 'server');

  api.export([
    'Neo4jCursor',
    'Neo4jRelationship',
    'Neo4jNode',
    'Neo4jData',
    'Neo4jEndpoint',
    'Neo4jTransaction',
    'Neo4jDB'
  ], 'server');
});

Package.onTest(function(api) {
  api.use(['coffeescript', 'ostrio:neo4jdriver', 'tinytest', 'underscore', 'ejson', 'ecmascript'], 'server');
  api.addFiles(['helpers.js', 'tests.coffee'], 'server');
});

Npm.depends({
  'needle': '0.10.0'
})