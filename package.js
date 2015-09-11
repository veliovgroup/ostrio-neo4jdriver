Package.describe({
  name: 'ostrio:neo4jdriver',
  summary: 'Meteor.js node-neo4j wrapper to be used with meteor applications (a.k.a. neo4j Connector)',
  version: '1.0.0',
  git: 'https://github.com/VeliovGroup/ostrio-neo4jdriver.git'
});

Package.onUse(function(api) {
  api.versionsFrom('1.0');
  api.addFiles([
    'helpers.coffee',
    'cursor.coffee',
    'data.coffee',
    'node.coffee',
    'endpoint.coffee',
    'transaction.coffee',
    'neo4jdriver.coffee'
  ], 'server');

  api.export([
    'Neo4jCursor',
    'Neo4jNode',
    'Neo4jData',
    'Neo4jEndpoint',
    'Neo4jTransaction',
    'Neo4jDB'
  ], 'server');
  api.use(['check', 'http', 'coffeescript', 'underscore', 'random', 'ejson'], 'server');
});

Package.onTest(function(api) {
  api.use(['coffeescript', 'ostrio:neo4jdriver', 'tinytest', 'underscore'], 'server');
  api.addFiles(['helpers.coffee', 'tests.coffee'], 'server');
});

Npm.depends({
  'needle': '0.10.0'
})