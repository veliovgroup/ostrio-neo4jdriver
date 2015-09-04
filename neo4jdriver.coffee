class Neo4jListener
  constructor: (listener, @_db) ->
    check listener, Function
    @__id = Random.id()
    @_db.listeners[@__id] = listener
  unset: ->
    @_db.listeners[@__id] = undefined
    delete @_db.listeners[@__id]

class Neo4jDB
  constructor: (@url, opts = {}) ->
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
    check @base, String

    @__service = {}
    @listeners = {}
    @batchQueue = {}
    @batchResults = {}
    @ready = false

    @defaultHeaders = Accept: "application/json", 'X-Stream': 'true'
    @defaultHeaders = _.extend @defaultHeaders, opts.headers if opts?.headers
    @defaultHeaders.Authorization = "Basic " + (new Buffer("#{opts.username}:#{opts.password}").toString('base64')) if opts.password and opts.username

    @__connect()
    @__start()

  __start: ->
    Meteor.setInterval =>
      if @ready and Object.keys(@batchQueue).length > 0
        tasks = []
        clones = {}
        for taskId, task of @batchQueue
          tasks.push _.clone task
          clones[taskId] = _.clone @batchQueue[taskId]

          @batchQueue[taskId] = undefined
          delete @batchQueue[taskId]
        
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
              for result in results.data
                if clones?[result.id]
                  if _.isEmpty result.body.errors
                    @batchResults[result.id] = result.body
                  else
                    @batchResults[result.id] = result.body.errors

                  clones[result.id] = undefined
                  delete clones[result.id]
    , 100

  __getBatchResult: (id, cb) ->
    i = 0
    timerId = Meteor.setInterval () =>
      if @batchResults?[id]
        if 1 <= id <= 999999
          reactive = true
        else
          reactive = false

        result = @__transformData _.clone(@batchResults[id]), reactive
        
        listener.call null, null, _.clone result for id, listener of @listeners

        @batchResults[id] = undefined
        delete @batchResults[id]
        Meteor.clearInterval timerId
        cb and cb null, result
      else if i > 300
        Meteor.clearInterval timerId
        cb and cb new Error "Batch request timeout"
      i++
    , 100
    return

  __batch: (task, callback, reactive) ->
    if reactive
      task.id = Math.floor(Math.random()*(999999-1+1)+1)
    else
      task.id = Math.floor(Math.random()*(999999999-1000000+1)+1000000)

    task.to = task.to.replace @root, ''
    @batchQueue[task.id] = task
    unless callback
      return Meteor.wrapAsync((cb) => @__getBatchResult task.id, cb)()
    else
      @__getBatchResult task.id, callback

  __connect: -> 
    response = @__call @root
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
      when 401
        throw new Error JSON.stringify response
      when 403
        throw new Error JSON.stringify response
      else
        throw new Error JSON.stringify response

  __httpCallSync: Meteor.wrapAsync HTTP.call

  __call: (url, options = {}, method = 'GET', callback) ->
    check url, String
    check options, Object
    check method, String
    check callback, Match.Optional Function

    if options?.headers
      options.headers = _.extend @defaultHeaders, options.headers 
    else
      options.headers = @defaultHeaders

    try
      unless callback
        return @__httpCallSync method, url, options
      else
        HTTP.call method, url, options, callback
    catch error
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
        unless _.isEmpty response.results?[0]?.data
          return @__parseResponse response.results[0].data, response.results[0].columns, reactive
        else
          return []
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

  listen: (listener) -> new Neo4jListener listener, @

  queryOne: (cypher, opts) ->
    check cypher, String
    check opts, Object
    return @query(cypher, opts).fetch()[0]

  queryAsync: (cypher, opts) -> @query cypher, opts, () -> return undefined

  query: (settings, opts, callback) ->
    if _.isObject settings
      {cypher, query, opts, parameters, params, callback, cb, type, resultDataContents, reactive, reactiveNodes} = settings
    else
      if _.isFunction opts
        callback = _.clone opts
        opts = undefined

    if _.isString settings
      cypher = settings
      settings = {}

    opts     ?= {}
    type     ?= 'transaction'
    cypher   ?= query
    opts     ?= parameters or params
    callback ?= cb
    reactive ?= reactive or reactiveNodes
    reactive ?= false
    resultDataContents ?= ['REST']

    check cypher, String
    check opts, Object
    check settings, Object
    check type, String
    check callback, Match.Optional Function

    if type is 'cypher'
      request = 
        method: 'POST'
        to: @__service.cypher.endpoint
        body:
          query: cypher
          params: opts

    if type is 'transaction'
      request = 
        method: 'POST'
        to: @__service.transaction.endpoint + '/commit'
        body:
          statements: [
            statement: cypher
            parameters: opts
            resultDataContents: resultDataContents
          ]

    return new Neo4jCursor(@__batch(request, callback, reactive)) if request