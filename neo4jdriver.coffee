console.success = (message) -> console.info '\x1b[1m', '\x1b[32m', message, '\x1b[0m'

class Neo4jListener
  constructor: (listener, @db) ->
    check listener, Function
    @__id = Random.id()
    @db.listeners[@__id] = listener
  unset: ->
    @db.listeners[@__id] = undefined
    delete @db.listeners[@__id]


class Neo4jEndpoint
  constructor: (@key, @endpoint, @db) ->
    check @key, String
    check @endpoint, String
  get: (method = 'GET', body = {}, callback) -> 
    @db.__batch
      method: method
      to: @endpoint
      body: body
    ,
      callback

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
          JSONableTask = _.clone task
          delete JSONableTask.fut
          tasks.push JSONableTask
          clones[taskId] = _.clone @batchQueue[taskId]

          @batchQueue[taskId] = undefined
          delete @batchQueue[taskId]
        
        results = @__call @__service.batch.endpoint
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
                  @batchResults[result.id] = result.body

                  clones[result.id] = undefined
                  delete clones[result.id]
    , 10

  __getBatchResult: (id, cb) ->
    timer = Meteor.setInterval () =>
      if @batchResults?[id]
        result = _.clone @batchResults[id]
        for id, listener of @listeners
          listener.call null, null, _.clone result
        @batchResults[id] = undefined
        delete @batchResults[id]
        Meteor.clearInterval timer
        cb null, @__transformData result
    , 10
    return

  __batch: (task, callback) ->
    task.id = Math.floor((Math.random() * 99999 * 17) + 1)
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

  __transformData: (response) ->
    console.log "||||||||||||||||||||||||||||||||||||||||||||||||||||||||||||||||||||||||||||||"
    console.log "||||||||||||||||||||||||||||||[__transformData]|||||||||||||||||||||||||||||||"
    console.log "||||||||||||||||||||||||||||||||||||||||||||||||||||||||||||||||||||||||||||||"

    parseRow = (result, columns) ->
      node = {}
      for column, index in columns
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
          currentNode = row.node[index]
          if row.isRest
            node[column] = meta: {}
            for key, endpoint of currentNode
              if _.isString(endpoint) and !!~endpoint.indexOf '://'
                node[column].meta[key] = new Neo4jEndpoint key, endpoint, @

            nodeData = _.extend currentNode.data, currentNode.metadata
            nodeData.metadata = currentNode.metadata

            if currentNode?['start']
              paths = currentNode.start.split '/'
              nodeData.start = paths[paths.length - 1]
            if currentNode?['end']
              paths = currentNode.end.split '/'
              nodeData.end = paths[paths.length - 1]

            node[column] = _.extend node[column], nodeData
          else
            node[column] = currentNode
        else
          node[column] = row.node[index]
      return node

    parseData = (data, columns) ->
      res = []
      for key, result of data
        res.push parseRow result, columns
      return res

    if response?.results or response?.errors
      unless response.exception
        unless _.isEmpty response.results?[0]?.data
          return parseData response.results[0].data, response.results[0].columns
        else
          return []
      else
        return response.exception

    if response?.columns and response?.data
      unless _.isEmpty response.data
        return parseData response.data, response.columns
      else
        return []
    
    return response

  listen: (listener) -> new Neo4jListener listener

  query: (settings, opts, callback) ->
    if _.isObject settings
      {cypher, query, opts, parameters, params, callback, cb, type, resultDataContents} = settings
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
    resultDataContents ?= 'REST'

    check cypher, String
    check opts, Object
    check settings, Object
    check type, String
    check callback, Match.Optional Function

    if type is 'cypher'
      req = 
        method: 'POST'
        to: @__service.cypher.endpoint
        body:
          query: cypher
          params: opts

    if type is 'transaction'
      req = 
        method: 'POST'
        to: @__service.transaction.endpoint + '/commit'
        body:
          statements: [
            statement: cypher
            parameters: opts
            resultDataContents: [ resultDataContents ]
          ]

    return @__batch req, callback if req