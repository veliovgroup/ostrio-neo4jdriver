/*jshint strict:false */
/*global Meteor:false */
/*global process:false */
/*global _n4j:false */
/*global _:false */

/*
 *
 * @function
 * @name Neo4j
 * @description Get GraphDatabase from node-neo4j npm package
 *
 */
this.Neo4j = (function() {
  /*
   *
   * @function
   * @name Neo4j
   * @param url {string} - url to Neo4j database
   * @description Get GraphDatabase from node-neo4j npm package
   *
   */
  function Neo4j(url) {
    this.url = (url != null) ? url : process.env['NEO4J_URL'] || process.env['GRAPHENEDB_URL'] || 'http://localhost:7474';
    this.N4j = Meteor.npmRequire('neo4j');
    _n4j = this.N4j;

    var GraphDatabase = new _n4j.GraphDatabase(this.url);
    GraphDatabase.callbacks = [];

    /*
     *
     * @function
     * @namespace N4j.GraphDatabase
     * @name query
     * @param query {String}      - The Cypher query. NOTE: Can't be multi-line.
     * @param opts {Object}       - A map of parameters for the Cypher query.
     * @param callback {function} - Callback function
     * @description Replace standard GraphDatabase.query method
     *              Add functionality of callbacks which runs on every query execution
     *
     */
    GraphDatabase.query = function(query, opts, callback){
      return new _n4j.GraphDatabase(this.url).query(query, opts, function(err, results){
        _.forEach(GraphDatabase.callbacks, function(cb){
          if(cb){
            cb(query, opts);
          }
        });

        if(callback){
          callback(err, results);
        }
      });
    };

    /*
     *
     * @function
     * @namespace N4j.GraphDatabase
     * @name listen
     * param callback {function} - Callback function with:
    *                                 @param query {String} - The Cypher query. NOTE: Can't be multi-line.
    *                                 @param opts {Object}  - A map of parameters for the Cypher query.
     * @description Add callback function
     *
     */
    GraphDatabase.listen = function(callback){
      GraphDatabase.callbacks.push(callback);
    };

    return GraphDatabase;
  }

  return Neo4j;
})();