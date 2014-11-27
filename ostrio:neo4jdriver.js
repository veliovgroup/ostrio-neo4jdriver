this.Neo4j = (function() {
  function Neo4j(url) {
    this.url = url != null ? url : process.env['NEO4J_URL'] || process.env['GRAPHENEDB_URL'] || 'http://localhost:7474';
    this.N4j = Meteor.npmRequire('neo4j');
    return new this.N4j.GraphDatabase(this.url);
  }

  return Neo4j;

})();