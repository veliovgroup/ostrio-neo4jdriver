NTRU_def = process.env.NODE_TLS_REJECT_UNAUTHORIZED
bound = Meteor.bindEnvironment (callback) -> return callback()

events = Npm.require 'events'
URL = Npm.require 'url'
needle = Npm.require('needle')

# class Neo4jListener
#   constructor: (listener, @_db) ->
#     check listener, Function
#     @__id = Random.id()
#     @_db.listeners[@__id] = listener
#   unset: ->
#     @_db.listeners[@__id] = undefined
#     delete @_db.listeners[@__id]

class Neo4jDB
  __proto__: events.EventEmitter.prototype;
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
    @batchResults = {}
    @ready = false

    @defaultHeaders = Accept: "application/json", 'X-Stream': 'true'
    @defaultHeaders = _.extend @defaultHeaders, opts.headers if opts?.headers
    @defaultHeaders.Authorization = "Basic " + (new Buffer("#{opts.username}:#{opts.password}").toString('base64')) if opts.password and opts.username

    @on 'batch', @__request
    tasks = []
    @on 'query', (id, task) => 
      tasks.push task
      if @ready
        @emit 'batch', tasks, -> tasks = [] 
    
    @__connect()

  __request: _.throttle (tasks, cb) ->
    bound =>
      @__call @__service.batch.endpoint
      , 
        data: tasks
        headers:
          Accept: 'application/json; charset=UTF-8'
          'Content-Type': 'application/json'
      ,
        'POST'
      ,
        (error, results) =>
          if results?.data
            unless _.isEmpty results.data
              @__proceedResult result for result in results.data
          else if results?.content
            content = JSON.parse results.content
            @__proceedResult result for result in content
      cb and cb()

  , 50

  __proceedResult: (result) ->
    if result?.body
      if _.isEmpty result.body?.errors
        @emit result.id, null, result.body
      else
        for error in result.body.errors
          console.error error.message
          console.error {code: error.code}
        @emit result.id, null, []
    else
      @emit result.id, null, []

  __batch: (task, callback, reactive) ->
    task.to = task.to.replace @root, ''
    task.id = Math.floor(Math.random()*(999999999-1+1)+1)
    @emit 'query', task.id, task
    unless callback
      return Meteor.wrapAsync((cb) =>
        @once task.id, (error, response) =>
          bound => cb error, @__transformData _.clone(response), reactive
      )()
    else
      @once task.id, (error, response) =>
        bound => callback error, @__transformData _.clone(response), reactive

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
            @ready = true
            console.success "Meteor is successfully connected to Neo4j on #{@url}"
        else
          throw new Error JSON.stringify response
    else
      throw new Error "Error with connection to Neo4j"

  __httpCallSync: Meteor.wrapAsync HTTP.call

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
    options.read_timeout = 1000
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
        callback and callback.call @, error, result

    try
      unless callback
        return Meteor.wrapAsync((cb) ->
          request method, url, options.data, options, cb
        )()
      else
        return request method, url, options.data, options, callback
    catch error
      console.error "Error sending request to Neo4j (GrapheneDB) server:"
      console.error error

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
          node[column] = new Neo4jNode @__parseNode(row.node[index]), reactive
        else
          node[column] = new Neo4jNode row.node[index]
      else
        node[column] = row.node[index]
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
        for result in response.results
          if result?.data
            parsed = parsed.concat @__parseResponse result.data, result.columns, reactive
        return parsed
      else
        return response.exception

    if response?.columns and response?.data
      unless _.isEmpty response.data
        return @__parseResponse response.data, response.columns, reactive
      else
        return []

    if response?.data and response?.metadata
      return @__parseNode response, reactive
    
    return response

  # listen: (listener) -> new Neo4jListener listener, @

  queryOne: (cypher, opts = {}) ->
    check cypher, String
    check opts, Object
    return @query(cypher, opts).fetch()[0]

  queryAsync: (cypher, opts) -> @query cypher, opts, () -> return undefined

  query: (settings, opts, callback) ->
    if _.isObject settings
      {cypher, query, opts, parameters, params, callback, cb, resultDataContents, reactive, reactiveNodes} = settings
    else
      if _.isFunction opts
        callback = _.clone opts
        opts = undefined

    if _.isString settings
      cypher = settings
      settings = {}

    opts     ?= {}
    cypher   ?= query
    opts     ?= parameters or params
    callback ?= cb
    reactive ?= reactive or reactiveNodes
    reactive ?= false
    resultDataContents ?= ['REST']

    check cypher, String
    check opts, Object
    check settings, Object
    check callback, Match.Optional Function

    request = 
      method: 'POST'
      to: @__service.transaction.endpoint + '/commit'
      body:
        statements: [
          statement: cypher
          parameters: opts
          resultDataContents: resultDataContents
        ]

    unless callback
      return Meteor.wrapAsync((cb)=>
        cb null, new Neo4jCursor @__batch request, null, reactive
      )()
    else
      @__batch request, (error, data) ->
        callback null, new Neo4jCursor data
      , reactive
      return @

  # cypher: (cypher, opts = {}, callback) ->
  #   check cypher, String
  #   check opts, Object
  #   check callback, Match.Optional Function

  #   if type is 'cypher'
  #     request = 
  #       method: 'POST'
  #       to: @__service.cypher.endpoint
  #       body:
  #         query: cypher
  #         params: opts

  #   unless callback
  #     return Meteor.wrapAsync((cb)=>
  #       cb null, new Neo4jCursor @__batch request, null, reactive
  #     )()
  #   else
  #     @__batch request, (error, data) ->
  #       callback null, new Neo4jCursor data
  #     , reactive
  #     return @

#   transaction: -> new Neo4jTransaction @

# class Neo4jTransaction
#   constructor: (_db) ->
#     request = 
#       method: 'POST'
#       to: _db.__service.transaction.endpoint
#       body:
#         statements: []
#     console.log _db.__batch request