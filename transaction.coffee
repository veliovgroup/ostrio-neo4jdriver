###
@locus Server
@summary Implementation of Transactional Cypher HTTP endpoint
         This class is event-driven and all methods is chainable
         Have to be finished by calling `.commit()` or `.rollback()` method
@class Neo4jTransaction
@url http://neo4j.com/docs/2.2.5/rest-api-transactional.html
###
class Neo4jTransaction
  __proto__: events.EventEmitter.prototype
  constructor: (@_db, settings, opts = {}) ->
    events.EventEmitter.call @
    @_ready = false
    @_results = []

    @on 'transaction', =>
      _arguments = arguments
      cb = arguments[arguments.length - 1]
      if @_ready then cb.apply @, _arguments else @once 'ready', => cb.apply @, _arguments
      return

    @on 'ready', (cb) => cb null, true

    statement = @__prepare(settings, opts) if settings
    statement = request: [] unless statement

    Meteor.wrapAsync((cb) =>
      @_db.__call @_db.__service.transaction.endpoint, data: statements: statement.request, 'POST', (error, response) =>
        @__proceedResults error, response, statement.reactive
        @_commitURL = response.data.commit
        @_execURL = response.data.commit.replace '/commit', ''
        @_expiresAt = response.data.transaction.expires
        @_ready = true
        @emit 'ready', cb
    )()

  __prepare: (settings, opts = {}, callback, asObj = false) ->
    {opts, cypher, resultDataContents, reactive, callback} = @_db.__parseSettings settings, opts, callback

    fill = (cs) ->
      statement: cs
      parameters: opts
      resultDataContents: resultDataContents
      
    statements = request: [], reactive: reactive
    if _.isArray cypher
      statements.request.push fill cypherString for cypherString in cypher
    else if _.isString cypher
      statements.request.push fill cypher

    return if asObj then {statements, callback} else statements

  __commit: (statement, callback) ->
    if statement
      data = data: statements: statement.request
      reactive = statement.reactive
    else
      data = data: statements: []
      reactive = false

    @_db.__call @_commitURL, data, 'POST', (error, response) => 
      @__proceedResults error, response, statement.reactive if statement
      if callback?.return
        callback.return @_results
      else
        callback error, @_results

  __proceedResults: (error, response, reactive = false) ->
    unless error
      @_db.__cleanUpResponse response, (result) => @_results.push new Neo4jCursor @_db.__transformData result, reactive
    else
      __error new Error error

  ###
  @locus Server
  @summary Rollback an open transaction
  @name rollback
  @class Neo4jTransaction
  @url http://neo4j.com/docs/2.2.5/rest-api-transactional.html#rest-api-rollback-an-open-transaction
  @returns {undefined}
  ###
  rollback: ->
    __wait (fut) =>
      @emit 'transaction', fut, (fut) ->
        @_db.__call @_execURL, null, 'DELETE', => 
          @_results = []
          fut.return undefined

  ###
  @locus Server
  @summary Reset transaction timeout of an open Neo4j Transaction
  @name resetTimeout
  @class Neo4jTransaction
  @url http://neo4j.com/docs/2.2.5/rest-api-transactional.html#rest-api-reset-transaction-timeout-of-an-open-transaction
  @returns Neo4jTransaction
  ###
  resetTimeout: ->
    __wait (fut) =>
      @emit 'transaction', fut, (fut) ->
        @_db.__call @_execURL, data: statements: [], 'POST', (error, response) => 
          @_expiresAt = response.data.transaction.expires
          fut.return @

  ###
  @locus Server
  @summary Execute statement in open Neo4j Transaction
  @name execute
  @class Neo4jTransaction
  @url http://neo4j.com/docs/2.2.5/rest-api-transactional.html#rest-api-execute-statements-in-an-open-transaction
  @param {Object | String | [String]} settings - Cypher query as String or Array of Cypher queries or object of settings
  @param {String | [String]} settings.cypher - Cypher query(ies), alias: `settings.query`
  @param {Object}   settings.opts - Map of cypher query(ies) parameters, aliases: `settings.parameters`, `settings.params`
  @param {[String]} settings.resultDataContents - Array of contents to return from Neo4j, like: 'REST', 'row', 'graph'. Default: `['REST']`
  @param {Boolean}  settings.reactive - Reactive nodes updates on Neo4jCursor.fetch(). Default: `false`. Alias: `settings.reactiveNodes`
  @param {Object}   opts - Map of cypher query(ies) parameters
  @returns {Neo4jTransaction}
  ###
  execute: (settings, opts = {}) ->
    __wait (fut) =>
      @emit 'transaction', @__prepare(settings, opts), fut, (statement, fut) ->
        @_db.__call @_execURL, data: statements: statement.request, 'POST', (error, response) =>
          @__proceedResults error, response, statement.reactive
          fut.return @

  ###
  @locus Server
  @summary Commit Neo4j Transaction
  @name commit
  @class Neo4jTransaction
  @url http://neo4j.com/docs/2.2.5/rest-api-transactional.html#rest-api-commit-an-open-transaction
  @param {Function | Object | String | [String]} settings - Cypher query as String or Array of Cypher queries or object of settings
  @param {String | [String]} settings.cypher - Cypher query(ies), alias: `settings.query`
  @param {Object}   settings.opts - Map of cypher query(ies) parameters, aliases: `settings.parameters`, `settings.params`
  @param {[String]} settings.resultDataContents - Array of contents to return from Neo4j, like: 'REST', 'row', 'graph'. Default: `['REST']`
  @param {Boolean}  settings.reactive - Reactive nodes updates on Neo4jCursor.fetch(). Default: `false`. Alias: `settings.reactiveNodes`
  @param {Function} settings.callback - Callback function. If passed, the method runs asynchronously. Alias: `settings.cb`
  @param {Object}   opts - Map of cypher query(ies) parameters
  @param {Function} callback - Callback function. If passed, the method runs asynchronously.
  @returns {[Neo4jCursor]} - Array of Neo4jCursor(s), or empty array if no nodes was returned during Transaction
  ###
  commit: (settings, opts = {}, callback) ->
    {statements, callback} = @__prepare settings, opts, callback, true if settings

    unless callback
      __wait (fut) => @emit 'transaction', statements, fut, @__commit
    else
      @emit 'transaction', statements, callback, @__commit
      return

  ###
  @locus Server
  @summary Get current data in Neo4j Transaction
  @name current
  @class Neo4jTransaction
  @returns {[Neo4jCursor]} - Array of Neo4jCursor(s), or empty array if no nodes was returned during Transaction
  ###
  current: () -> @_results

  ###
  @locus Server
  @summary Get last received data in Neo4j Transaction
  @name last
  @class Neo4jTransaction
  @returns {Neo4jCursor | null} - Neo4jCursor, or null if no nodes was returned during Transaction
  ###
  last: () -> if @_results.length > 0 then @_results[@_results.length - 1] else null