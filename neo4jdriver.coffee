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

    @['__emitBatch'] = -> return

    @on 'ready', => @_ready = true

    @on 'send', (fut, cb) ->
      if @_ready
        cb fut
      else
        @once 'ready', => cb fut

    @on 'batch', @__request

    tasks = []

    @on 'query', (id, task) => 
      tasks.push task
      _eb = _.once =>
        @emit 'batch', tasks
        tasks = []

      if @_ready
        process.nextTick => _eb()
      else
        @once 'ready', => process.nextTick => _eb()
    
    @__connect()

  __request: (tasks, cb) ->
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

    task.to = task.to.replace @root, ''
    task.id = Math.floor(Math.random()*(999999999-1+1)+1)

    @emit 'query', task.id, task
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
    @__call @root, {}, 'GET', (error, response) =>
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

    request = (method, url, body, options, callback) ->
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

  __getCursor: (request, callback, reactive) ->
    unless callback
      return __wait (fut) =>
        @__batch request, (error, data) ->
          console.error error if error
          fut.return new Neo4jCursor data
        , reactive
    else
      @__batch request, (error, data) ->
        callback error, new Neo4jCursor data
      , reactive
      return @

  __parseSettings: (settings, opts, callback) ->
    if _.isArray settings
      cypher = settings
      settings = {}
    else if _.isObject settings
      {cypher, query, opts, parameters, params, callback, cb, resultDataContents, reactive, reactiveNodes} = settings
    else if _.isString settings
      cypher = settings
      settings = {}
    
    if _.isFunction opts
      callback = opts
      opts = {}

    opts     ?= {}
    cypher   ?= query
    opts     = parameters or params or {} if not opts or _.isEmpty opts
    callback ?= cb
    reactive ?= reactive or reactiveNodes
    reactive ?= false
    resultDataContents ?= ['REST']

    check settings, Object
    check cypher, Match.OneOf String, [String]
    check opts, Object
    check callback, Match.Optional Function
    check resultDataContents, [String]
    check reactive, Boolean

    return {opts, cypher, callback, resultDataContents, reactive}


  ##################
  # Public Methods #
  ##################
  queryOne: (cypher, opts) -> @query(cypher, opts).fetch(true)[0]
  querySync: (cypher, opts) -> 
    check cypher, String
    check opts, Match.Optional Object
    @query cypher, opts
  queryAsync: (cypher, opts, callback) -> 
    if _.isFunction opts
      callback = opts
      opts = {}
    unless callback
      callback = -> return 
    return @query cypher, opts, callback

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

  cypher: (cypher, opts = {}, callback, reactive) ->
    if _.isFunction opts
      reactive = callback
      callback = opts
      opts = {}
    check cypher, String
    check opts, Object
    check callback, Match.Optional Function
    check reactive, Match.Optional Boolean

    task = 
      method: 'POST'
      to: @__service.cypher.endpoint
      body:
        query: cypher
        params: opts

    return @__getCursor task, callback, reactive

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

      task.to = task.to.replace @root, ''
      task.id ?= Math.floor(Math.random()*(999999999-1+1)+1)
      ids.push task.id
      @emit 'query', task.id, task

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