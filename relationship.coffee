###
@locus Server
@url http://neo4j.com/docs/2.2.5/rest-api-relationships.html
@summary Represents Relationship API(s)
         Most basic way to work with relationships
         Might be reactive data source, if `_isReactive` passed as `true` - data of relationship will be updated before returning

         First argument must be number (id) or object returned from db
         This class is event-driven and all methods is chainable
@class Neo4jRelationship
###
class Neo4jRelationship extends Neo4jData
  _.extend @::, events.EventEmitter.prototype
  constructor: (@_db, @_id, @_isReactive = false) ->
    events.EventEmitter.call @

    @_ready = false
    @on 'ready', (relationship, fut) =>
      if relationship and not _.isEmpty relationship
        @_id = relationship.id || relationship.metadata.id
        super @_db.__parseNode(relationship), @_isReactive
        @_ready = true
        fut.return @ if fut
      else
        fut.return undefined if fut

    @on 'apply', =>
      _arguments = arguments
      cb = arguments[arguments.length - 1]
      if @_ready then cb.apply @, _arguments else @once 'ready', => cb.apply @, _arguments
      return

    if _.isObject @_id
      if @_id?.startNode or @_id?.start
        @emit 'ready', @_id
      else
        __error "Relationship is not created or created wrongly, `startNode` or `start` is not returned!"
    else if _.isNumber @_id
      @_db.__batch method: 'GET', to: '/relationship/' + @_id, (error, relationship) =>
        @emit 'ready', relationship
      , @_isReactive, true

  __return: (cb) -> __wait (fut) => @emit 'apply', fut, (fut) -> cb.call @, fut

  ###
  @locus Server
  @summary Get relationship data
  @name get
  @class Neo4jRelationship
  @url http://neo4j.com/docs/2.2.5/rest-api-relationships.html#rest-api-get-relationship-by-id
  @returns {Object}
  ###
  get: -> @__return (fut) -> fut.return super

  ###
  @locus Server
  @summary Delete relationship
  @name delete
  @class Neo4jRelationship
  @url http://neo4j.com/docs/2.2.5/rest-api-relationships.html#rest-api-delete-relationship
  @returns {undefined}
  ###
  delete: ->
    @__return (fut) -> 
      @_db.__batch 
        method: 'DELETE'
        to: @_service.self.endpoint
      , 
        =>
          @node = undefined
          fut.return undefined
      , undefined, true

  ###
  @locus Server
  @summary Get current relationship's properties
  @name properties
  @class Neo4jRelationship
  @url http://neo4j.com/docs/2.2.5/rest-api-relationships.html#rest-api-get-all-properties-on-a-relationship
  @returns {Object}
  ###
  properties: -> @__return (fut) -> 
    @update()
    fut.return _.omit @node, ['_service', 'id', 'type', 'metadata', 'start', 'end']

  ###
  @locus Server
  @summary Set (or override, if exists) one property on current relationship
  @name setProperty
  @class Neo4jRelationship
  @url http://neo4j.com/docs/2.2.5/rest-api-relationships.html#rest-api-set-single-property-on-a-relationship
  @param {String} name  - Name of the property
  @param {String} value - Value of the property
  @returns {Neo4jRelationship}
  ###
  setProperty: (name, value) ->
    if _.isObject name
      k = Object.keys(name)[0]
      value = name[k]
      name = k

    check name, String
    check value, Match.OneOf String, Number, Boolean, [String], [Number], [Boolean]

    @__return (fut) -> 
      @_node[name] = value
      @_db.__batch 
        method: 'PUT'
        to: @_service.property.endpoint.replace '{key}', name
        body: value
      , 
        => fut.return @
      , undefined, true

  ###
  @locus Server
  @summary Set (or override, if exists) multiple property on current relationship
  @name setProperties
  @class Neo4jRelationship
  @param {Object} nameValue - Object of key:value pairs
  @returns {Neo4jRelationship}
  ###
  setProperties: (nameValue) ->
    check nameValue, Object
    @__return (fut) ->
      tasks = []
      for name, value of nameValue
        @_node[name] = value

        tasks.push
          method: 'PUT'
          to: @_service.property.endpoint.replace '{key}', name
          body: value

      @_db.batch tasks, =>
        fut.return @
      , false, true

  ###
  @locus Server
  @summary Delete a one property by name from a node
  @name deleteProperty
  @class Neo4jRelationship
  @url http://neo4j.com/docs/2.2.5/rest-api-relationship-properties.html#rest-api-remove-property-from-a-relationship
  @param {String} name  - Name of the property
  @returns {Neo4jRelationship}
  ###
  deleteProperty: (name) ->
    check name, String

    @__return (fut) -> 
      if @_node?[name]
        delete @_node[name]
        @_db.__batch 
          method: 'DELETE'
          to: @_service.property.endpoint.replace '{key}', name
        , 
          => fut.return @
        , undefined, true
      else
        fut.return @

  ###
  @locus Server
  @summary Delete all or multiple properties by name from a node. 
           If no argument is passed, - all properties will be removed from the node.
  @name deleteProperties
  @class Neo4jRelationship
  @url http://neo4j.com/docs/2.2.5/rest-api-relationship-properties.html#rest-api-remove-properties-from-a-relationship
  @param {[String]} names - Array of names
  @returns {Neo4jRelationship}
  ###
  deleteProperties: (names) ->
    check names, Match.Optional [String]
    @__return (fut) ->
      if names
        tasks = []
        for name in names
          if @_node?[name]
            delete @_node[name]
            tasks.push
              method: 'DELETE'
              to: @_service.property.endpoint.replace '{key}', name

        if tasks.length > 0
          @_db.batch tasks, =>
            fut.return @
          , false, true
        else
          fut.return @
      else
        delete @_node[k] for k, v of _.omit @_node, ['_service', 'id', 'type', 'metadata', 'start', 'end']
        @_db.__batch 
          method: 'DELETE'
          to: @_service.properties.endpoint
        , 
          => fut.return @
        , undefined, true

  ###
  @locus Server
  @summary This ~~will replace all existing properties~~ (not actually due to [this bug](https://github.com/neo4j/neo4j/issues/5341)), it will update existing properties and add new.
  @name updateProperties
  @class Neo4jRelationship
  @url http://neo4j.com/docs/2.2.5/rest-api-relationships.html#rest-api-set-all-properties-on-a-relationship
  @param {Object} nameValue - Object of key:value pairs
  @returns {Neo4jRelationship}
  ###
  updateProperties: (nameValue) ->
    check nameValue, Object
    @__return (fut) ->
      # delete @_node[k] for k, v of _.omit @_node, ['_service', 'id', 'type', 'metadata', 'start', 'end']

      for k, v of nameValue
        @_node[k] = v

      @_db.__batch 
        method: 'PUT'
        to: @_service.properties.endpoint
        body: nameValue
      , 
        => fut.return @
      , undefined, true

  ###
  @locus Server
  @summary Set / Get property on current relationship, if only first argument is passed - will return property value, if both arguments is presented - property will be updated or created
  @name setProperty
  @class Neo4jRelationship
  @url http://neo4j.com/docs/2.2.5/rest-api-relationships.html#rest-api-get-single-property-on-a-relationship
  @url http://neo4j.com/docs/2.2.5/rest-api-node-properties.html#rest-api-set-property-on-node
  @param {String} name  - Name of the property
  @param {String} value - [OPTIONAL] Value of the property
  @returns {Neo4jRelationship | String | Boolean | Number | [String] | [Boolean] | [Number]}
  ###
  property: (name, value) ->
    check name, String
    return @getProperty name if not value
    check value, Match.Optional Match.OneOf String, Number, Boolean, [String], [Number], [Boolean]
    return @setProperty name, value

  ###
  @locus Server
  @summary Get one property on current node
  @name getProperty
  @class Neo4jRelationship
  @url http://neo4j.com/docs/2.2.5/rest-api-relationships.html#rest-api-get-single-property-on-a-relationship
  @param {String} name - Name of the property
  @returns {String | Boolean | Number | [String] | [Boolean] | [Number]}
  ###
  getProperty: (name) -> @__return (fut) => 
    @update()
    fut.return @node[name]


