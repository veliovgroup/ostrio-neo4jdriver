Package.describe({
  name: 'ostrio:neo4jdriver',
  summary: 'Neo4j REST API client, with support of https and GrapheneDB',
  version: '1.0.2-fiber',
  git: 'https://github.com/VeliovGroup/ostrio-neo4jdriver.git'
});

Package.onUse(function(api) {
  api.versionsFrom('1.0');
  api.use(['coffeescript'], 'server');
  api.addFiles(['driver.coffee'], 'server');

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
  api.use([
    'coffeescript', 
    'ostrio:neo4jdriver', 
    'tinytest', 
    'underscore', 
    'ejson'
  ], 'server');
  api.addFiles(['tests.coffee'], 'server');
});

Npm.depends({
  'needle': '0.10.0',
  'neo4j-fiber': '1.0.0-meteor',
  'fibers': '1.0.7'
})