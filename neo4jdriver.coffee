###
@locus Server
@summary Connector to Neo4j, with basic Neo4j REST API methods implementation
@class Neo4jDB
###
class Neo4jDB
  __proto__: events.EventEmitter.prototype
  constructor: (@url, opts = {}) ->
    events.EventEmitter.call @
    @url = @url or process.env.NEO4J_URL or process.env.GRAPHENEDB_URL or 'http://localhost:7474'
    check @url, String
    check opts, Object

    opts.password = opts.password or opts.pass or ''
    check opts.password, String
    opts.username = opts.username or opts.user or ''
    check opts.username, String

    @base = opts.base or opts.root or opts.path or 'db/data'
    @base = @base.replace(/^\/|\/$/g, '')
    @root = "#{@url}/#{@base}"
    @https = !!~@url.indexOf 'https://'
    check @base, String

    if @https
      @username = opts.username
      @password = opts.password

    @__service = {}
    @_ready = false

    @defaultHeaders = Accept: "application/json", 'X-Stream': 'true'
    @defaultHeaders = _.extend @defaultHeaders, opts.headers if opts?.headers
    @defaultHeaders.Authorization = "Basic " + (new Buffer("#{opts.username}:#{opts.password}").toString('base64')) if opts.password and opts.username


    @on 'ready', => @_ready = true
    @on 'batch', @__request

    tasks = []
    @on 'query', (task) => 
      task.to = task.to.replace @root, ''
      task.id ?= Math.floor(Math.random()*(999999999-1+1)+1)
      tasks.push task
      _eb = _.once =>
        @emit 'batch', tasks
        tasks = []

      if @_ready
        process.nextTick => _eb()
      else
        @once 'ready', => process.nextTick => _eb()
    
    @__connect()

  __request: (tasks) ->
    @__call @__service.batch.endpoint
    , 
      data: tasks
      headers:
        Accept: 'application/json; charset=UTF-8'
        'Content-Type': 'application/json'
    ,
      'POST'
    ,
      (error, response) =>
        unless error
          @__cleanUpResponse response, (result) => @__proceedResult result
        else
          console.error error
          console.trace()

  __cleanUpResponse: (response, cb) ->
    if response?.data and _.isObject response.data
      @__cleanUpResults response.data, cb
    else if response?.content and _.isString response.content
      try
        @__cleanUpResults JSON.parse(response.content), cb
      catch error
        console.error "Neo4j response error (Check your cypher queries):", [response.statusCode], error
        console.error "Original received data:"
        console.log response.content
        console.trace()
    else
      console.error "Empty response from Neo4j, but expecting data"
      console.trace()

  __cleanUpResults: (results, cb) ->
    if results?.results or results?.errors
      errors = results?.errors
      results = results?.results

    unless _.isEmpty errors
      console.error error.code, error.message for error in errors
    else if not _.isEmpty results
      cb result for result in results

  __proceedResult: (result) ->
    if result?.body
      if _.isEmpty result.body?.errors
        @emit result.id, null, result.body, result.id
      else
        for error in result.body.errors
          console.error error.message
          console.error {code: error.code}
        @emit result.id, error?.message, [], result.id
    else
      @emit result.id, null, [], result.id

  __batch: (task, callback, reactive = false, noTransform = false) ->
    check task, Object
    check task.to, String
    check callback, Match.Optional Function
    check reactive, Boolean

    task.id ?= Math.floor(Math.random()*(999999999-1+1)+1)
    @emit 'query', task
    unless callback
      return __wait (fut) =>
        @once task.id, (error, response) =>
          bound => 
            fut.throw error if error
            fut.return if noTransform then response else @__transformData _.clone(response), reactive
    else
      @once task.id, (error, response) =>
        bound => callback error, if noTransform then response else @__transformData _.clone(response), reactive

  __connect: -> 
    response = @__call @root
    if response?.statusCode
      switch response.statusCode
        when 200
          if response.data.password_change_required
            throw new Error "To connect to Neo4j - password change is required, please proceed to #{response.data.password_change}"
          else
            for key, endpoint of response.data
              if _.isString endpoint
                if !!~endpoint.indexOf '://'
                  @__service[key] = new Neo4jEndpoint key, endpoint, @
                else
                  @__service[key] = get: -> endpoint
                console.success "v#{endpoint}" if key is "neo4j_version"
            @emit 'ready'
            console.success "Successfully connected to Neo4j on #{@url}"
        else
          throw new Error JSON.stringify response
    else
      throw new Error "Error with connection to Neo4j"

  __call: (url, options = {}, method = 'GET', callback) ->
    check url, String
    check options, Object
    check method, String
    check callback, Match.Optional Function

    process.env.NODE_TLS_REJECT_UNAUTHORIZED = 0

    if options?.headers
      options.headers = _.extend @defaultHeaders, options.headers 
    else
      options.headers = @defaultHeaders

    options.json = true
    options.read_timeout = 10000
    options.parse_response = 'json'
    options.follow_max = 10
    _url = URL.parse(url)
    options.proxy = "#{_url.protocol}//#{@username}:#{@password}@#{_url.host}" if @https
    options.data ?= {}

    request = (method, url, body, options, callback) =>
      needle.request method, url, body, options, (error, response)->
        process.env.NODE_TLS_REJECT_UNAUTHORIZED = NTRU_def
        unless error
          result = 
            statusCode: response.statusCode
            headers: response.headers
            content: response.raw.toString 'utf8'
            data: response.body
        callback and callback error, result

    try
      unless callback
        return __wait (fut) ->
          request method, url, options.data, options, (error, response) ->
            fut.throw error if error
            fut.return response
      else
        return request method, url, options.data, options, callback
    catch error
      console.error "Error sending request to Neo4j (GrapheneDB) server:"
      console.error error
      console.trace()

  __parseNode: (currentNode) ->
    if currentNode?.metadata or currentNode?.data
      node = _service: {}
      for key, endpoint of currentNode
        if _.isString(endpoint) and !!~endpoint.indexOf '://'
          node._service[key] = new Neo4jEndpoint key, endpoint, @

      nodeData = _.extend currentNode.data, currentNode.metadata
      nodeData.metadata = currentNode.metadata

      if currentNode?['start']
        paths = currentNode.start.split '/'
        nodeData.start = paths[paths.length - 1]
      if currentNode?['end']
        paths = currentNode.end.split '/'
        nodeData.end = paths[paths.length - 1]

      return _.extend node, nodeData
    else
      return currentNode

  __parseRow: (result, columns, reactive) ->
    node = {}
    for column, index in columns

      if result?.graph
        for key, value of result.graph
          node[key] = value

      if result?.row
        row = 
          node: result.row
          isRest: false

      if result?.rest
        row = 
          node: result.rest
          isRest: true

      unless row
        row = 
          node: result
          isRest: true

      if _.isObject row.node[index]
        if row.isRest
          node[column] = new Neo4jData @__parseNode(row.node[index]), reactive
        else
          node[column] = new Neo4jData row.node[index], false
      else
        node[column] = new Neo4jData row.node[index], false
    return node

  __parseResponse: (data, columns, reactive) ->
    res = []
    for key, result of data
      res.push @__parseRow result, columns, reactive
    return res

  __transformData: (response, reactive) ->
    if response?.results or response?.errors
      unless response.exception
        parsed = []
        for result in response.results when result?.data
          parsed = parsed.concat @__parseResponse result.data, result.columns, reactive
        return parsed
      else
        console.error response.exception

    if response?.columns and response?.data
      unless _.isEmpty response.data
        return @__parseResponse response.data, response.columns, reactive
      else
        return []

    if response?.data and response?.metadata
      return new Neo4jData @__parseNode(response), if response?.self then reactive else false
    
    return new Neo4jData response

  __getCursor: (task, callback, reactive) ->
    unless callback
      return __wait (fut) =>
        @__batch task, (error, data) ->
          console.error error if error
          fut.return new Neo4jCursor data
        , reactive
    else
      @__batch task, (error, data) ->
        callback error, new Neo4jCursor data
      , reactive
      return @

  __parseSettings: (settings, opts, callback) ->
    if _.isFunction settings
      callback = settings
      cypher   = undefined
      opts     = {}
      settings = {}
    else if _.isArray settings
      cypher   = settings
      settings = {}
    else if _.isObject settings
      {cypher, query, opts, parameters, params, callback, cb, resultDataContents, reactive, reactiveNodes} = settings
    else if _.isString settings
      cypher   = settings
      settings = {}
    
    if _.isFunction opts
      callback = opts
      opts     = {}

    opts     ?= {}
    cypher   ?= query
    opts     = parameters or params or {} if not opts or _.isEmpty opts
    callback ?= cb
    reactive ?= reactive or reactiveNodes
    reactive ?= false
    resultDataContents ?= ['REST']

    check settings, Object
    check cypher, Match.Optional Match.OneOf String, [String]
    check opts, Object
    check callback, Match.Optional Function
    check resultDataContents, [String]
    check reactive, Boolean

    return {opts, cypher, callback, resultDataContents, reactive}


  ##################
  # Public Methods #
  ##################
  ###
  @locus Server
  @summary Send query via to Transactional endpoint and return results as graph representation
  @name graph
  @class Neo4jDB
  @url http://neo4j.com/docs/2.2.5/rest-api-transactional.html#rest-api-return-results-in-graph-format
  @param {Object | String} settings - Cypher query as String or object of settings
  @param {String}   settings.cypher - Cypher query, alias: `settings.query`
  @param {Object}   settings.opts - Map of cypher query parameters, aliases: `settings.parameters`, `settings.params`
  @param {Boolean}  settings.reactive - Reactive nodes updates on Neo4jCursor.fetch(). Default: `false`. Alias: `settings.reactiveNodes`
  @param {Function} settings.callback - Callback function. If passed, the method runs asynchronously. Alias: `settings.cb`
  @param {Object}   opts - Map of cypher query parameters
  @param {Function} callback - Callback function. If passed, the method runs asynchronously
  @returns {Object} - 
  ###
  graph: (settings, opts = {}, callback) ->
    {cypher, opts, callback, reactive} = @__parseSettings settings, opts, callback

    task = 
      method: 'POST'
      to: @__service.transaction.endpoint + '/commit'
      body:
        statements: [
          statement: cypher
          parameters: opts
          resultDataContents: ['graph']
        ]

    return @__getCursor task, callback, reactive

  ###
  @locus Server
  @summary Shortcut for `query`, which returns first result from your query as plain Object
  @name queryOne
  @class Neo4jDB
  @param {String} cypher - Cypher query as String
  @param {Object} opts   - Map of cypher query parameters
  @returns {Object} - Node object as {n:{id,meta,etc..}}, where is `n` is "NodeLink", for query like `MATCH n RETURN n`
  ###
  queryOne: (cypher, opts) -> @query(cypher, opts).fetch(true)[0]

  ###
  @locus Server
  @summary Shortcut for `query` (see below for more). Always runs synchronously, but without callback.
  @name querySync
  @class Neo4jDB
  @param {String} cypher - Cypher query as String
  @param {Object} opts   - Map of cypher query parameters
  @returns {Neo4jCursor}
  ###
  querySync: (cypher, opts) -> 
    check cypher, String
    check opts, Match.Optional Object
    @query cypher, opts

  ###
  @locus Server
  @summary Shortcut for `query` (see below for more). Always runs asynchronously, 
           even if no callback is passed. Best option for independent deletions.
  @name queryAsync
  @class Neo4jDB
  @returns {Neo4jCursor | undefined} - Returns Neo4jCursor only in callback
  ###
  queryAsync: (cypher, opts, callback) -> 
    if _.isFunction opts
      callback = opts
      opts = {}
    unless callback
      callback = -> return 
    return @query cypher, opts, callback

  ###
  @locus Server
  @summary Send query to Neo4j via transactional endpoint. This Transaction will be immediately committed. This transaction will be sent inside batch, so if you call multiple async queries, all of them will be sent in one batch in closest (next) event loop.
  @name query
  @class Neo4jDB
  @url http://neo4j.com/docs/2.2.5/rest-api-transactional.html#rest-api-begin-and-commit-a-transaction-in-one-request
  @param {Object | String} settings - Cypher query as String or object of settings
  @param {String}   settings.cypher - Cypher query, alias: `settings.query`
  @param {Object}   settings.opts - Map of cypher query parameters, aliases: `settings.parameters`, `settings.params`
  @param {[String]} settings.resultDataContents - Array of contents to return from Neo4j, like: 'REST', 'row', 'graph'. Default: `['REST']`
  @param {Boolean}  settings.reactive - Reactive nodes updates on Neo4jCursor.fetch(). Default: `false`. Alias: `settings.reactiveNodes`
  @param {Function} settings.callback - Callback function. If passed, the method runs asynchronously. Alias: `settings.cb`
  @param {Object}   opts - Map of cypher query parameters
  @param {Function} callback - Callback function. If passed, the method runs asynchronously.
  @returns {Neo4jCursor}
  ###
  query: (settings, opts = {}, callback) ->
    {cypher, opts, callback, resultDataContents, reactive} = @__parseSettings settings, opts, callback

    task = 
      method: 'POST'
      to: @__service.transaction.endpoint + '/commit'
      body:
        statements: [
          statement: cypher
          parameters: opts
          resultDataContents: resultDataContents
        ]

    return @__getCursor task, callback, reactive

  ###
  @locus Server
  @summary Send query to Neo4j via cypher endpoint
  @name cypher
  @class Neo4jDB
  @url http://neo4j.com/docs/2.2.5/rest-api-cypher.html
  @param {Object | String} settings - Cypher query as String or object of settings
  @param {String}   settings.cypher - Cypher query, alias: `settings.query`
  @param {Object}   settings.opts - Map of cypher query parameters, aliases: `settings.parameters`, `settings.params`
  @param {[String]} settings.resultDataContents - Array of contents to return from Neo4j, like: 'REST', 'row', 'graph'. Default: `['REST']`
  @param {Boolean}  settings.reactive - Reactive nodes updates on Neo4jCursor.fetch(). Default: `false`. Alias: `settings.reactiveNodes`
  @param {Function} settings.callback - Callback function. If passed, the method runs asynchronously. Alias: `settings.cb`
  @param {Object}   opts - Map of cypher query parameters
  @param {Function} callback - Callback function. If passed, the method runs asynchronously.
  @returns {Neo4jCursor}
  ###
  cypher: (settings, opts = {}, callback) ->
    {cypher, opts, callback, reactive} = @__parseSettings settings, opts, callback

    task = 
      method: 'POST'
      to: @__service.cypher.endpoint
      body:
        query: cypher
        params: opts

    return @__getCursor task, callback, reactive

  ###
  @locus Server
  @summary Sent tasks to batch endpoint, this method allows to work directly with Neo4j REST API
  @name batch
  @class Neo4jDB
  @url http://neo4j.com/docs/2.2.5/rest-api-batch-ops.html
  @param {[Object]} tasks - Array of tasks
  @param {String}   tasks.$.method  - HTTP(S) method used sending this task, one of: 'POST', 'GET', 'PUT', 'DELETE', 'HEAD'
  @param {String}   tasks.$.to - Endpoint (URL) for task
  @param {Number}   tasks.$.id - [Optional] Unique id to identify task. Should be always unique!
  @param {Object}   tasks.$.body - [Optional] JSONable object which will be sent as data to task
  @param {Function} callback - callback function, if present `batch()` method will be called asynchronously
  @param {Boolean}  plain - if `true`, results will be returned as simple objects instead of Neo4jCursor
  @param {Boolean}  reactive - if `true` and if `plain` is true data of node(s) will be updated before returning
  @returns {[Object]} - array of Neo4jCursor(s) or array of Object id `plain` is `true`
  ###
  batch: (tasks, callback, plain = false, reactive = false) ->
    check tasks, [Object]
    check callback, Match.Optional Function
    check plain, Boolean
    check reactive, Boolean

    results = []
    ids = []
    for task in tasks
      check task.method, Match.OneOf 'POST', 'GET', 'PUT', 'DELETE', 'HEAD'
      check task.to, String
      check task.body, Match.Optional Object

      task.id ?= Math.floor(Math.random()*(999999999-1+1)+1)
      ids.push task.id
      @emit 'query', task

    wait = (cb) =>
      qty = ids.length
      for id in ids
        @once id, (error, response, id) =>
          --qty
          response = if plain then response else @__transformData _.clone(response), reactive
          response._batchId = id
          results.push response
          cb null, results if qty is 0

    unless callback
      return __wait (fut) -> wait (error, results) -> fut.return results
    else
      wait callback
      return @

  ###
  @locus Server
  @summary Open Neo4j Transaction. All methods on Neo4jTransaction instance is chainable.
  @name transaction
  @class Neo4jDB
  @url http://neo4j.com/docs/2.2.5/rest-api-transactional.html#rest-api-begin-a-transaction
  @param {Function | Object | String | [String]} settings - [Optional] Cypher query as String or Array of Cypher queries or object of settings
  @param {String | [String]} settings.cypher - Cypher query(ies), alias: `settings.query`
  @param {Object}   settings.opts - Map of cypher query(ies) parameters, aliases: `settings.parameters`, `settings.params`
  @param {[String]} settings.resultDataContents - Array of contents to return from Neo4j, like: 'REST', 'row', 'graph'. Default: `['REST']`
  @param {Boolean}  settings.reactive - Reactive nodes updates on Neo4jCursor.fetch(). Default: `false`. Alias: `settings.reactiveNodes`
  @param {Object} opts - [Optional] Map of cypher query(ies) parameters
  @returns {Neo4jTransaction} - Neo4jTransaction instance
  ###
  transaction: (settings, opts = {}) -> new Neo4jTransaction @, settings, opts
  nodes: (id, reactive) -> new Neo4jNode @, id, reactive

class Neo4jNode extends Neo4jData
  _.extend @::, events.EventEmitter.prototype
  constructor: (@_db, @_id, @_isReactive = false) ->
    events.EventEmitter.call @
    @_ready = false
    @on 'ready', (node, fut) =>
      if node and not _.isEmpty node
        console.log "[onReady]", {@_ready}
        super @_db.__parseNode(node), @_isReactive
        @_ready = true
        console.log 
        fut.return @ if fut
        console.log "[onReady]", {@_ready}
      else
        fut.return undefined if fut

    @on 'create', (properties, fut) =>
      unless @_ready
        @_db.__batch
          method: 'POST'
          to: @_db.__service.node.endpoint
          body: properties
        , 
          (error, node) =>
            if node?.metadata
              @_id = node.metadata.id
              @emit 'ready', node, fut
        , @_isReactive, true
        return
      else
        console.error "You already in node instance, create new one by calling, `db.nodes().create()`"
        fut.return @

    @on 'setProperty', (name, value, fut) =>
      if @_ready then @__setProperty name, value, fut else @once 'ready', => @__setProperty name, value, fut
      return

    @on 'delete', (fut) =>
      if @_ready then @__delete fut else @once 'ready', => @__delete fut
      return

    @on 'get', (cb) =>
      if @_ready then cb() else @once 'ready', => cb()
      return

    if @_id
      task = 
        method: 'GET'
        to: @_db.__service.node.endpoint + '/' + @_id

      @_db.__batch task, (error, node) =>
        @emit 'ready', node
      , @_isReactive, true

  get: ->
    __wait (fut) => @emit 'get', => fut.return super

  __delete: (fut) ->
    @_db.__batch 
      method: 'DELETE'
      to: @_node._service.self.endpoint
    , 
      => fut.return undefined
    , undefined, true
    return

  __setProperty: (name, value, fut) ->
    @_node[name] = value
    @_db.__batch 
      method: 'PUT'
      to: @_node._service.property.endpoint.replace '{key}', name
      body: value
    , 
      => fut.return @
    , undefined, true
    return

  __updateProperties: (name, value, fut) ->
    
  create: (properties = {}) ->
    check properties, Match.Optional Object
    __wait (fut) => @emit 'create', properties, fut

  delete: -> __wait (fut) => @emit 'delete', fut

  properties: -> _.emit @_node, ['_service', 'id', 'labels', 'metadata']

  setProperty: (name, value) ->
    check name, String
    check value, Match.OneOf String, Number, Boolean, [String], [Number], [Boolean]
    __wait (fut) => @emit 'setProperty', name, value, fut

  setProperties: (nameValue) ->
    check nameValue, Object
    __wait (fut) => @emit 'setProperties', nameValue, fut

  updateProperties: (nameValue) ->
    check name, Object
    @_node[name] = value
    __wait (fut) => @emit 'updateProperties', nameValue, fut

  property: (name, value) ->
    check name, String
    return @node[name] if not value
    check value, Match.Optional Match.OneOf String, Number, Boolean, [String], [Number], [Boolean]
    setProperty name unless @_node[name]
    return updateProperty name, value

  getProperty: (name) -> @node[name]