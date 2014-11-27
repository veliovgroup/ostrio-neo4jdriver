Package.describe({
  name: 'ostrio:neo4jdriver',
  summary: ' /* Fill me in! */ ',
  version: '1.0.0',
  git: ' /* Fill me in! */ '
});

Package.onUse(function(api) {
  api.versionsFrom('1.0');
  api.addFiles('ostrio:neo4jdriver.js');
});

Package.onTest(function(api) {
  api.use('tinytest');
  api.use('ostrio:neo4jdriver');
  api.addFiles('ostrio:neo4jdriver-tests.js');
});
