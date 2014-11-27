Package.describe({
  name: 'ostrio:neo4jdriver',
  summary: 'Meteor.js Neo4j Driver (Connector)',
  version: '0.1.0',
  git: 'https://github.com/VeliovGroup/ostrio-neo4jdriver.git'
});

Package.onUse(function(api) {
  api.versionsFrom('1.0');
  api.addFiles('ostrio:neo4jdriver.js', 'server');
});

Npm.depends({
  neo4j: '1.1.1'
});