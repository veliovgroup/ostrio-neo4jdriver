/*jshint strict:false */
/*global Meteor:false */
/*global Npm:false */
/*global process:false */
/*global HTTP:false */
/*global console:false */
/*global check:false */
/*global Match:false */
/*global _:false */

/*
 *
 * @function
 * @name Neo4j
 * @description Get GraphDatabase from node-neo4j npm package
 *
 */
Meteor.Neo4j = (function() {
  /*
   *
   * @function
   * @name Neo4j
   * @param url {string} - url to Neo4j database
   * @description Get GraphDatabase from node-neo4j npm package
   *
   */
  function Neo4j(url) {
    check(url, Match.Optional(Match.OneOf(String, null)));

    var _this = this;

    this.message = ' connection to Neo4j DataBase, please check your settings and what Neo4j database is running. Note: URL to Neo4j database is better to set via environment variable NEO4J_URL or GRAPHENEDB_URL';
    this.warning = 'Neo4j DataBase is not ready, check your settings and DB availability';
    this.ready = false;
    this.url = (url) ? url : process.env.NEO4J_URL || process.env.GRAPHENEDB_URL || 'http://localhost:7474';

    /*
     * Check connection to Neo4j
     * If something is wrong - throw message 
     */
    try {
      var connectionSettings = {};
      var _url = this.url;
      if(_url && _url.indexOf('@') !== -1){
        _url = _url.replace('http://', '');
        var auth = _url.split('@')[0];
        _url = 'http://' + _url.split('@')[1];
        connectionSettings = {
          auth: auth
        };
      }

      var httpRes = HTTP.call('GET', _url + '/db/manage/', connectionSettings);
      if(httpRes.statusCode === 200){
        this.ready = true;
        console.info('Meteor is successfully connected to Neo4j on ' + this.url);
      }else{
        console.warn('Bad' + this.message, httpRes.toString());
      }
    } catch (e) {
      console.warn('No' + this.message);
      console.warn(e.toString());
    }

    var _n4j = Npm.require('neo4j');

    var GraphDatabase = new _n4j.GraphDatabase(this.url);
    GraphDatabase.callbacks = [];

    /*
     *
     * @function
     * @namespace N4j.GraphDatabase
     * @name query
     * @param query {String}      - The Cypher query. NOTE: Can't be multi-line.
     * @param opts {Object}       - A map of parameters for the Cypher query.
     * @param callback {Function} - Callback function
     * @description Replace standard GraphDatabase.query method
     *              Add functionality of callbacks which runs on every query execution
     *
     */
    GraphDatabase.query = function(query, opts, callback){
      check(query, String);
      check(opts, Match.Optional(Match.OneOf(Object, null)));
      check(callback, Match.Optional(Function));

      if(_this.ready){
        return new _n4j.GraphDatabase(_this.url).query(query, opts, function(err, results){
          _.forEach(GraphDatabase.callbacks, function(cb){
            if(cb){
              cb(query, opts);
            }
          });

          if(callback){
            callback(err, results);
          }
        });
      }else{
        console.warn('GraphDatabase.query', _this.warning);
      }
    };

    /*
     *
     * @function
     * @namespace N4j.GraphDatabase
     * @name listen
     * param callback {Function} - Callback function with:
     *                              - @param query {String} - The Cypher query. NOTE: Can't be multi-line.
     *                              - @param opts  {Object} - A map of parameters for the Cypher query.
     * @description Add callback function
     *
     */
    GraphDatabase.listen = function(callback){
      check(callback, Match.Optional(Function));

      if(_this.ready){
        GraphDatabase.callbacks.push(callback);
      }else{
        console.warn('GraphDatabase.listen', _this.warning);
      }
    };

    return GraphDatabase;
  }

  return Neo4j;
})();