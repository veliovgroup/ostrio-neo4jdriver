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
    @on 'ready', (relationship) =>
      if relationship and not _.isEmpty relationship
        @_id = relationship.id || relationship.metadata.id
        super @_db.__parseNode(relationship), @_isReactive
        @_ready = true

    if _.isObject @_id
      if @_id?.startNode or @_id?.start
        @emit 'ready', @_id
      else
        __error "Relationship is not created or created wrongly, `startNode` or `start` is not returned!"
    else if _.isNumber @_id
      @_db.__batch method: 'GET', to: '/relationship/' + @_id, (error, relationship) =>
        @emit 'ready', relationship
      , @_isReactive, true

    @index._current = @
    @properties = @__properties()

  __return: (cb) -> __wait (fut) => if @_ready then cb.call @, fut else @once 'ready', => cb.call @, fut

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
      , undefined, false, true
      @node = undefined
      fut.return undefined

  __properties: ->
    ###
    @locus Server
    @summary Get current relationship's one property or all properties
    @name properties.get
    @class Neo4jRelationship
    @url http://neo4j.com/docs/2.2.5/rest-api-relationships.html#rest-api-get-single-property-on-a-relationship
    @url http://neo4j.com/docs/2.2.5/rest-api-relationships.html#rest-api-get-all-properties-on-a-relationship
    @param {String} name - [OPTIONAL] Name of the property
    @returns {Object | String | Boolean | Number | [String] | [Boolean] | [Number]}
    ###
    get: (name) => 
      @__return (fut) -> 
        @update()
        if name
          @update()
          fut.return @node[name]
        else
          fut.return _.omit @node, ['_service', 'id', 'type', 'metadata', 'start', 'end']

    ###
    @locus Server
    @summary Set (or override, if exists) one property on current relationship
    @name properties.set
    @class Neo4jRelationship
    @url http://neo4j.com/docs/2.2.5/rest-api-relationships.html#rest-api-set-single-property-on-a-relationship
    @param {String | Object} n  - Name or object of key:value pairs
    @param {String} v - [OPTIONAL] Value of the property
    @returns {Neo4jRelationship}
    ###
    set: (n, v) =>
      @__return (fut) -> 
        if _.isObject n
          nameValue = n
          check nameValue, Object
          tasks = []
          for name, value of nameValue
            check value, Match.OneOf String, Number, Boolean, [String], [Number], [Boolean]

            @_node[name] = value
            tasks.push
              method: 'PUT'
              to: @_service.property.endpoint.replace '{key}', name
              body: value

          @_db.batch tasks, plain: true
        else
          check n, String
          check v, Match.OneOf String, Number, Boolean, [String], [Number], [Boolean]

          @_node[n] = v
          @_db.__batch 
            method: 'PUT'
            to: @_service.property.endpoint.replace '{key}', n
            body: v
          , undefined, false, true
        fut.return @

    ###
    @locus Server
    @summary Delete one or all propert(y|ies) by name from a node
             If no argument is passed, - all properties will be removed from the node.
    @name properties.delete
    @class Neo4jRelationship
    @url http://neo4j.com/docs/2.2.5/rest-api-relationship-properties.html#rest-api-remove-property-from-a-relationship
    @url http://neo4j.com/docs/2.2.5/rest-api-relationship-properties.html#rest-api-remove-properties-from-a-relationship
    @param {String | [String]} names - Name or array of names of the property
    @returns {Neo4jRelationship}
    ###
    delete: (names) =>
      check names, Match.Optional Match.OneOf String, [String]

      @__return (fut) -> 
        if _.isString names
          if @_node?[names]
            delete @_node[names]
            @_db.__batch 
              method: 'DELETE'
              to: @_service.property.endpoint.replace '{key}', names
            , undefined, false, true

        else if _.isArray(names) and names.length > 0
          tasks = []
          for name in names
            if @_node?[name]
              delete @_node[name]
              tasks.push
                method: 'DELETE'
                to: @_service.property.endpoint.replace '{key}', name

          @_db.batch tasks, plain: true if tasks.length > 0

        else
          delete @_node[k] for k, v of _.omit @_node, ['_service', 'id', 'type', 'metadata', 'start', 'end']
          @_db.__batch 
            method: 'DELETE'
            to: @_service.properties.endpoint
          , undefined, false, true
        fut.return @

    ###
    @locus Server
    @summary This ~~will replace all existing properties~~ (not actually due to [this bug](https://github.com/neo4j/neo4j/issues/5341)), it will update existing properties and add new.
    @name properties.update
    @class Neo4jRelationship
    @url http://neo4j.com/docs/2.2.5/rest-api-relationships.html#rest-api-set-all-properties-on-a-relationship
    @param {Object} nameValue - Object of key:value pairs
    @returns {Neo4jRelationship}
    ###
    update: (nameValue) =>
      check nameValue, Object
      @__return (fut) ->
        # delete @_node[k] for k, v of _.omit @_node, ['_service', 'id', 'type', 'metadata', 'start', 'end']

        for k, v of nameValue
          @_node[k] = v

        @_db.__batch 
          method: 'PUT'
          to: @_service.properties.endpoint
          body: nameValue
        , undefined, false, true
        fut.return @

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
    return @properties.get name if not value
    check value, Match.Optional Match.OneOf String, Number, Boolean, [String], [Number], [Boolean]
    return @properties.set name, value

  index:
    ###
    @locus Server
    @summary Create index on relationship for label
             This API poorly described in Neo4j Docs, so it may work in some different way - we are expecting
    @name index.create
    @class Neo4jRelationship
    @param {String} label - Label name
    @param {[String]} key - Index key
    @param {String} type - [OPTIONAL] Indexing type, one of: `exact` or `fulltext`, by default: `exact`
    @returns {Object}
    ###
    create: (label, key, type = 'exact') ->
      check label, String
      check key, String
      check type, Match.OneOf 'exact', 'fulltext'

      @_current._db.__batch 
        method: 'POST'
        to: @_current._db.__service.relationship_index.endpoint + '/' + label
        body: 
          key: key
          uri: @_current._service.self.endpoint
          value: type
      , undefined, false, true

    ###
    @locus Server
    @summary Get indexes on relationship for label
             This API poorly described in Neo4j Docs, so it may work in some different way - we are expecting
    @name index.get
    @class Neo4jRelationship
    @param {String} label - Label name
    @param {[String]} key - Index key
    @param {String} type - [OPTIONAL] Indexing type, one of: `exact` or `fulltext`, by default: `exact`
    @returns {[Object]}
    ###
    get: (label, key, type = 'exact') ->
      check label, String
      check key, String
      check type, Match.OneOf 'exact', 'fulltext'

      @_current._db.__batch 
        method: 'GET'
        to: "#{@_current._db.__service.relationship_index.endpoint}/#{label}/#{key}/#{type}/#{@_current._id}"
      , undefined, false, true

    ###
    @locus Server
    @summary Drop (remove) index on relationship for label
             This API poorly described in Neo4j Docs, so it may work in some different way - we are expecting
    @name index.drop
    @class Neo4jRelationship
    @param {String} label - Label name
    @param {String} key - Index key
    @param {String} type - [OPTIONAL] Indexing type, one of: `exact` or `fulltext`, by default: `exact`
    @returns {[]} - Empty array
    ###
    drop: (label, key, type = 'exact') ->
      check label, String
      check key, String
      check type, Match.OneOf 'exact', 'fulltext'

      @_current._db.__batch 
        method: 'DELETE'
        to: "#{@_current._db.__service.relationship_index.endpoint}/#{label}/#{key}/#{type}/#{@_current._id}"
      , undefined, false, true