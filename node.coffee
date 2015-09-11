class Neo4jNode extends Neo4jData
  _.extend @::, events.EventEmitter.prototype
  constructor: (@_db, @_id, @_isReactive = false) ->
    events.EventEmitter.call @

    @_ready = false
    @on 'ready', (node, fut) =>
      if node and not _.isEmpty node
        @_id = node.metadata.id
        super @_db.__parseNode(node), @_isReactive
        @_ready = true
        fut.return @ if fut
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
            console.error error if error
            if node?.metadata
              @emit 'ready', node, fut
            else
              console.error "Node is not created or created wrongly, metadata is not returned!"
        , @_isReactive, true
        return
      else
        console.error "You already in node instance, create new one by calling, `db.nodes().create()`"
        fut.return @

    @on 'apply', =>
      _arguments = arguments
      cb = arguments[arguments.length - 1]
      if @_ready then cb.apply @, _arguments else @once 'ready', => cb.apply @, _arguments
      return

    if _.isObject @_id
      if _.has @_id, 'metadata'
        @emit 'ready', @_id
      else
        properties = @_id
        @_id = undefined
        @emit 'create', properties
    else if _.isNumber @_id
      @_db.__batch method: 'GET', to: @_db.__service.node.endpoint + '/' + @_id, (error, node) =>
        @emit 'ready', node
      , @_isReactive, true
    else
      @emit 'create'

  __return: (cb) -> __wait (fut) => @emit 'apply', fut, (fut) -> cb.call @, fut


  get: -> @__return (fut) -> fut.return super


  delete: -> @__return (fut) -> 
    @_db.__batch 
      method: 'DELETE'
      to: @_node._service.self.endpoint
    , 
      =>
        @node = undefined
        fut.return undefined
    , undefined, true

  properties: -> @__return (fut) -> fut.return _.omit @node, ['_service', 'id', 'labels', 'metadata']

  setProperty: (name, value) ->
    if _.isString name
      check name, String
      check value, Match.OneOf String, Number, Boolean, [String], [Number], [Boolean]
    else if _.isObject name
      k = Object.keys(name)[0]
      value = name[k]
      name = k

    @__return (fut) -> 
      @_node[name] = value
      @_db.__batch 
        method: 'PUT'
        to: @_node._service.property.endpoint.replace '{key}', name
        body: value
      , 
        => fut.return @
      , undefined, true

  setProperties: (nameValue) ->
    check nameValue, Object
    @__return (fut) ->
      tasks = []
      for name, value of nameValue
        @_node[name] = value

        tasks.push
          method: 'PUT'
          to: @_node._service.property.endpoint.replace '{key}', name
          body: value

      @_db.batch tasks, =>
        fut.return @
      , false, true

  updateProperties: (nameValue) ->
    check nameValue, Object
    @__return (fut) ->
      delete @_node[k] for k, v of _.omit @_node, ['_service', 'id', 'labels', 'metadata']

      for k, v of nameValue
        @_node[k] = v

      @_db.__batch 
        method: 'PUT'
        to: @_node._service.properties.endpoint
        body: nameValue
      , 
        => fut.return @
      , undefined, true

  property: (name, value) ->
    check name, String
    return @getProperty name if not value
    check value, Match.Optional Match.OneOf String, Number, Boolean, [String], [Number], [Boolean]
    return @setProperty name, value

  getProperty: (name) -> @__return (fut) => fut.return @node[name]