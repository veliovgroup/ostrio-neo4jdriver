class Neo4jTransaction
  __proto__: events.EventEmitter.prototype
  constructor: (@_db, settings, opts = {}) ->
    events.EventEmitter.call @
    @ready = false
    @_results = []

    @on 'commit', (statement, callback) =>
      if @ready then @__commit statement, callback else @once 'ready', => @__commit statement, callback
      return

    @on 'execute', (statement, fut) =>
      if @ready then @__execute statement, fut else @once 'ready', => @__execute statement, fut
      return

    @on 'resetTimeout', (fut) =>
      if @ready then @__resetTimeout fut else @once 'ready', => @__resetTimeout fut
      return

    @on 'rollback', (fut) =>
      if @ready then @__rollback fut else @once 'ready', => @__rollback fut
      return

    @on 'ready', (cb) => cb null, true

    statement = []
    statement.push @__prepare(settings, opts).request if settings

    Meteor.wrapAsync((cb) =>
      @_db.__call @_db.__service.transaction.endpoint, data: statements: statement, 'POST', (error, response) =>
        @__proceedResults error, response
        @_commitURL = response.data.commit
        @_execURL = response.data.commit.replace '/commit', ''
        @_expiresAt = response.data.transaction.expires
        @ready = true
        @emit 'ready', cb
    )()

  __prepare: (settings, opts = {}) ->
    {opts, cypher, resultDataContents, reactive} = @_db.__parseSettings settings, opts
      
    return {
      request:
        statement: cypher
        parameters: opts
        resultDataContents: resultDataContents
      reactive: reactive
    }

  execute: (settings, opts = {}) ->
    fut = new Future()
    @emit 'execute', @__prepare(settings, opts), fut
    return fut.wait()

  __execute: (statement, fut) ->
    @_db.__call @_execURL, data: statements: [statement.request], 'POST', (error, response) =>
      @__proceedResults error, response, statement.reactive
      fut.return @
    return

  commit: (settings, opts = {}, callback) ->
    statement = @__prepare(settings, opts) if settings

    unless callback
      return Meteor.wrapAsync((cb) =>
        @emit 'commit', statement, cb
      )()
    else
      @emit 'commit', statement, callback
      return

  __commit: (statement, callback) ->
    @_db.__call @_commitURL, data: statements: [statement.request], 'POST', (error, response) => 
      @__proceedResults error, response, statement.reactive
      callback null, @_results
      return

  resetTimeout: ->
    fut = new Future()
    @emit 'resetTimeout', fut
    return fut.wait()

  __resetTimeout: (fut) ->
    @_db.__call @_execURL, data: statements: [], 'POST', (error, response) => 
      @_expiresAt = response.data.transaction.expires
      fut.return @
    return

  rollback: ->
    fut = new Future()
    @emit 'rollback', fut
    return fut.wait()

  __rollback: (fut) ->
    @_db.__call @_execURL, null, 'DELETE', => 
      @_results = []
      fut.return undefined
    return

  __proceedResults: (error, response, reactive = false) ->
    unless error
      @_db.__cleanUpResponse response, (result) => 
        @_results.push new Neo4jCursor @_db.__transformData result, reactive
    else
      console.error error