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

    @defaultHeaders = Accept: "application/json; charset=UTF-8", 'X-Stream': 'true', 'Content-Type': 'application/json'
    @defaultHeaders = _.extend @defaultHeaders, opts.headers if opts?.headers
    @defaultHeaders.Authorization = "Basic " + (new Buffer("#{opts.username}:#{opts.password}").toString('base64')) if opts.password and opts.username

    @on 'ready', => @_ready = true
    @on 'batch', @__request

    tasks = []
    _eb = =>
      @emit 'batch', tasks
      tasks = []

    @on 'query', (task) => 
      task.to = task.to.replace @root, ''
      task.id ?= Math.floor(Math.random()*(999999999-1+1)+1)
      tasks.push task

      if @_ready
        process.nextTick => _eb() if tasks.length > 0
      else
        @once 'ready', => process.nextTick => _eb() if tasks.length > 0
    
    @__connect()
    @relationship._db = @
    @index._db = @
    @constraint._db = @

  __request: (tasks) ->
    @__call @__service.batch.endpoint
    , 
      data: tasks
      headers: @defaultHeaders
    ,
      'POST'
    ,
      (error, response) =>
        unless error
          @__cleanUpResponse response, (result) => @__proceedResult result
        else
          __error new Error error

  __cleanUpResponse: (response, cb) ->
    if response?.data and _.isObject response.data
      @__cleanUpResults response.data, cb
    else if response?.content and _.isString response.content
      try
        @__cleanUpResults JSON.parse(response.content), cb
      catch error
        __error "Neo4j response error (Check your cypher queries):", [response.statusCode], error
        __error "Originally received data:"
    else
      __error "Empty response from Neo4j, but expecting data"

  __cleanUpResults: (results, cb) ->
    if results?.results or results?.errors
      errors = results?.errors
      results = results?.results

    unless _.isEmpty errors
      __error error.code, error.message for error in errors
    else if not _.isEmpty results
      cb result for result in results

  __proceedResult: (result) ->
    if result?.body
      if _.isEmpty result.body?.errors
        @emit result.id, null, result.body, result.id
      else
        for error in result.body.errors
          __error error.message
          __error {code: error.code}
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
            if error
              fut.throw error
            else
              fut.return if noTransform then response else @__transformData _.clone(response), reactive
    else
      @once task.id, (error, response) =>
        bound => 
          callback error, if noTransform then response else @__transformData _.clone(response), reactive

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
                __success "v#{endpoint}" if key is "neo4j_version"
            @emit 'ready'
            __success "Successfully connected to Neo4j on #{@url}"
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
            if error
              fut.throw error
            else
              fut.return response
      else
        Fiber(-> request method, url, options.data, options, callback).run()
    catch error
      __error "Error sending request to Neo4j (GrapheneDB) server:"
      __error new Error error

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
        nodeData.start = parseInt paths[paths.length - 1]
      if currentNode?['end']
        paths = currentNode.end.split '/'
        nodeData.end = parseInt paths[paths.length - 1]

      return _.extend node, nodeData
    else
      return currentNode

  __parseRow: (result, columns, reactive) ->
    node = {}
    for column, index in columns

      if result?.graph
        node.relationships = []
        node.nodes = []
        for key, value of result.graph
          if _.isArray(value) and value.length > 0
            for n in value
              node.nodes.push new Neo4jData @__parseNode(n), reactive if key is 'nodes'
              node.relationships.push new Neo4jRelationship @, n, reactive if key is 'relationships'

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

      if row.node?[index]
        if _.isObject row.node[index]
          if row.isRest
            if row.node[index]?.start and row.node[index]?.end
              node[column] = new Neo4jRelationship @, row.node[index], reactive
            else
              node[column] = new Neo4jNode @, row.node[index], reactive
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
        __error response.exception

    if response?.columns and response?.data
      unless _.isEmpty response.data
        return @__parseResponse response.data, response.columns, reactive
      else
        return []

    if response?.data and response?.metadata
      if response?.start and response?.end
        return new Neo4jRelationship @, response, if response?.self then reactive else false
      else if response?.self
        return new Neo4jNode @, response, if response?.self then reactive else false
      else
        return new  Neo4Data @__parseNode(response), if response?.self then reactive else false

    if _.isArray(response) and response.length > 0
      result = []
      hasData = false
      for row in response
        if _.isObject(row) and (row?.data or row?.metadata)
          hasData = true
          if row?.start and row?.end
            result.push new Neo4jRelationship @, row, if row?.self then reactive else false
          else if row?.self
            result.push new Neo4jNode @, row, if row?.self then reactive else false
          else
            result.push new Neo4Data @__parseNode(row), if row?.self then reactive else false

      return result if hasData

    return new Neo4jData response

  __getCursor: (task, callback, reactive) ->
    unless callback
      return __wait (fut) =>
        @__batch task, (error, data) ->
          __error error if error
          fut.return new Neo4jCursor data
        , reactive
    else
      Fiber(=> @__batch task, (error, data) ->
        callback error, new Neo4jCursor data
      , reactive).run()
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
  @summary List all property keys ever used in the database
  @name propertyKeys
  @class Neo4jDB
  @url http://neo4j.com/docs/2.2.5/rest-api-property-values.html
  @returns {[String]}
  ###
  propertyKeys: ->
    data = @__batch
      method: "GET"
      to: "/propertykeys"
    , undefined, false, true
    data = data.get() if _.isFunction data?.get
    return data

  ###
  @locus Server
  @summary List all labels ever used in the database
  @name labels
  @class Neo4jDB
  @url http://neo4j.com/docs/2.2.5/rest-api-node-labels.html#rest-api-list-all-labels
  @returns {[String]}
  ###
  labels: -> @__service.node_labels.get()

  ###
  @locus Server
  @summary List all relationship types ever used in the database
  @name labels
  @class Neo4jDB
  @url http://neo4j.com/docs/2.2.5/rest-api-relationship-types.html
  @returns {[String]}
  ###
  relationshipTypes: -> @__service.relationship_types.get 'GET', {}, true

  ###
  @locus Server
  @summary Return version of Neo4j server we connected to
  @name version
  @class Neo4jDB
  @returns {String}
  ###
  version: -> @__service.neo4j_version.get()

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
  @returns {Neo4jCursor} - [{nodes: [], relationships: []}]
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
    Fiber(=> @query cypher, opts, callback).run()
    return

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
  @param {Object}   settings
  @param {Boolean}  settings.reactive - if `true` and if `plain` is true data of node(s) will be updated before returning
  @param {Boolean}  settings.plain - if `true`, results will be returned as simple objects instead of Neo4jCursor
  @returns {[Object]} - array of Neo4jCursor(s) or array of Object id `plain` is `true`
  ###
  batch: (tasks, settings = {}, callback) ->
    if _.isFunction settings
      callback = settings
      settings = {}
    else
      {reactive, plain} = settings

    reactive ?= false
    plain ?= false

    check tasks, [Object]
    check callback, Match.Optional Function
    check reactive, Boolean
    check plain, Boolean

    results = []
    ids = []
    for task in tasks
      check task.method, Match.OneOf 'POST', 'GET', 'PUT', 'DELETE', 'HEAD'
      check task.to, String
      check task.body, Match.Optional Match.OneOf Object, String, Number, Boolean, [String], [Number], [Boolean], [Object]

      task.id ?= Math.floor(Math.random()*(999999999-1+1)+1)
      ids.push task.id
      @emit 'query', task

    wait = (cb) =>
      qty = ids.length
      for id in ids
        @once id, (error, response, id) =>
          --qty
          response = if plain then response else new Neo4jCursor @__transformData _.clone(response), reactive
          response._batchId = id
          results.push response
          cb null, results if qty is 0

    unless callback
      return __wait (fut) -> wait (error, results) -> fut.return results
    else
      Fiber(-> wait callback).run()
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

  ###
  @locus Server
  @summary Create or get node object.
           If no arguments is passed, then new node will be created.
           If first argument is number, then node will be fetched from Neo4j
           If first argument is Object, then new node will be created with passed properties
  @name nodes
  @class Neo4jDB
  @url http://neo4j.com/docs/2.2.5/rest-api-nodes.html
  @param {Number, Object} id - [Optional], see description above
  @param {Boolean} reactive - if passed as `true` - data of node will be updated (only each event loop) before returning
  @returns {Neo4jNode} - Neo4jNode instance
  ###
  nodes: (id, reactive) -> new Neo4jNode @, id, reactive

  relationship:
    ###
    @locus Server
    @summary Create relationship between two nodes
    @name relationship.create
    @class Neo4jDB
    @url http://neo4j.com/docs/2.2.5/rest-api-relationships.html#rest-api-create-a-relationship-with-properties
    @param {Number | Object | Neo4jNode} from - id or instance of node
    @param {Number | Object | Neo4jNode} to - id or instance of node
    @param {String} type - Type (label) of relationship
    @param {Object} properties - Relationship's properties
    @param {Boolean} properties._reactive - Set Neo4jRelationship instance to reactive mode
    @returns {Neo4jRelationship}
    ###
    create: (from, to, type, properties = {}) ->
      from = from?.id or from?.get?().id if _.isObject from
      to = to?.id or to?.get?().id if _.isObject to
      check from, Number
      check to, Number
      check type, String
      check properties, Object

      if properties?._reactive
        reactive = properties._reactive
        delete properties._reactive

      reactive ?= false

      check reactive, Boolean

      relationship = @_db.__batch 
        method: 'POST'
        to: @_db.__service.node.endpoint + '/' + from + '/relationships'
        body: 
          to: @_db.__service.node.endpoint + '/' + to
          type: type
          data: properties
      , undefined, false, true

      new Neo4jRelationship @_db, relationship, reactive

    ###
    @locus Server
    @summary Get relationship object, by id
    @name relationship.get
    @class Neo4jDB
    @url http://neo4j.com/docs/2.2.5/rest-api-relationships.html#rest-api-get-relationship-by-id
    @param {Number} to - id or instance of node
    @param {Boolean} reactive - Set Neo4jRelationship instance to reactive mode
    @returns {Neo4jRelationship}
    ###
    get: (id, reactive) -> 
      check id, Number
      check reactive, Match.Optional Boolean
      new Neo4jRelationship @_db, id, reactive

  constraint:
    ###
    @locus Server
    @summary Create constraint for label
    @name constraint.create
    @class Neo4jDB
    @url http://neo4j.com/docs/2.2.5/rest-api-schema-constraints.html#rest-api-create-uniqueness-constraint
    @param {String} label - Label name
    @param {[String]} keys - Keys
    @param {String} type - Constraint type, default `uniqueness`
    @returns {Object}
    ###
    create: (label, keys, type = 'uniqueness') ->
      check label, String
      check keys, [String]
      check type, String
      @_db.__batch 
        method: 'POST'
        to: @_db.__service.constraints.endpoint + '/' + label + '/' + type
        body: property_keys: keys
      , undefined, false, true


    ###
    @locus Server
    @summary Create constraint for label
    @name constraint.drop
    @class Neo4jDB
    @url http://neo4j.com/docs/2.2.5/rest-api-schema-constraints.html#rest-api-drop-constraint
    @param {String} label - Label name
    @param {String} key - Key
    @param {String} type - Constraint type, default `uniqueness`
    @returns {[]} - Empty array
    ###
    drop: (label, key, type = 'uniqueness') ->
      check label, String
      check key, String
      check type, String
      @_db.__batch 
        method: 'DELETE'
        to: @_db.__service.constraints.endpoint + '/' + label + '/' + type + '/' + key
      , undefined, false, true

    ###
    @locus Server
    @summary Get constraint(s) for label, or get all DB's constraints
    @name constraint.get
    @class Neo4jDB
    @url http://neo4j.com/docs/2.2.5/rest-api-schema-constraints.html#rest-api-get-a-specific-uniqueness-constraint
    @url http://neo4j.com/docs/2.2.5/rest-api-schema-constraints.html#rest-api-get-all-uniqueness-constraints-for-a-label
    @url http://neo4j.com/docs/2.2.5/rest-api-schema-constraints.html#rest-api-get-all-constraints-for-a-label
    @url http://neo4j.com/docs/2.2.5/rest-api-schema-constraints.html#rest-api-get-all-constraints
    @param {String} label - Label name
    @param {String} key - Key
    @param {String} type - Constraint type, default `uniqueness`
    @returns {[Object]}
    ###
    get: (label, key, type) ->
      check label, Match.Optional String
      check key, Match.Optional String
      check type, Match.Optional String

      type = 'uniqueness' if not type and key

      params = []
      params.push label if label
      params.push type if type
      params.push key if key
      @_db.__batch 
        method: 'GET'
        to: @_db.__service.constraints.endpoint + '/' + params.join '/'
      , undefined, false, true

  index:
    ###
    @locus Server
    @summary Create index for label
    @name index.create
    @class Neo4jDB
    @url http://neo4j.com/docs/2.2.5/rest-api-schema-indexes.html#rest-api-create-index
    @param {String} label - Label name
    @param {[String]} keys - Index keys
    @returns {Object}
    ###
    create: (label, keys) ->
      check label, String
      check keys, [String]

      @_db.__batch 
        method: 'POST'
        to: @_db.__service.indexes.endpoint + '/' + label
        body: property_keys: keys
      , undefined, false, true

    ###
    @locus Server
    @summary Get indexes for label
    @name index.get
    @class Neo4jDB
    @url http://neo4j.com/docs/2.2.5/rest-api-schema-indexes.html#rest-api-list-indexes-for-a-label
    @param {String} label - Label name
    @returns {[Object]}
    ###
    get: (label) ->
      check label, Match.Optional String

      @_db.__batch 
        method: 'GET'
        to: @_db.__service.indexes.endpoint + '/' + label
      , undefined, false, true

    ###
    @locus Server
    @summary Drop (remove) index for label
    @name index.drop
    @class Neo4jDB
    @url http://neo4j.com/docs/2.2.5/rest-api-schema-indexes.html#rest-api-drop-index
    @param {String} label - Label name
    @param {String} key - Index key
    @returns {[]} - Empty array
    ###
    drop: (label, key) ->
      check label, String
      check key, String

      @_db.__batch 
        method: 'DELETE'
        to: @_db.__service.indexes.endpoint + '/' + label + '/' + key
      , undefined, false, true