###
@locus Server
@summary Represents Node, Labels, Degree and Properties API(s)
         Most basic way to work with nodes
         Might be reactive data source, if `_isReactive` passed as `true` - data of node will be updated before returning

         If no arguments is passed, then new node will be created.
         If first argument is number, then node will be fetched from Neo4j
         If first argument is Object, then new node will be created with passed properties

         This class is event-driven and all methods is chainable
@class Neo4jNode
###
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

    @on 'create', (properties) =>
      unless @_ready
        @_db.__batch
          method: 'POST'
          to: @_db.__service.node.endpoint
          body: properties
        , 
          (error, node) =>
            __error error if error
            if node?.metadata
              @emit 'ready', node
            else
              __error "Node is not created or created wrongly, metadata is not returned!"
        , @_isReactive, true
        return
      else
        __error "You already in node instance, create new one by calling, `db.nodes().create()`"

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

    @index._current = @
    @properties = @__properties()
    @labels = @__labels()

  __return: (cb) -> __wait (fut) => if @_ready then cb.call @, fut else @once 'ready', => cb.call @, fut

  __properties: ->
    ###
    @locus Server
    @summary Get current node's property by name or all properties
    @name properties.get
    @class Neo4jNode
    @url http://neo4j.com/docs/2.2.5/rest-api-node-properties.html#rest-api-get-properties-for-node
    @url http://neo4j.com/docs/2.2.5/rest-api-node-properties.html#rest-api-get-property-for-node
    @param {String} name - [OPTIONAL] Name of the property
    @returns {Object | String | Boolean | Number | [String] | [Boolean] | [Number]}
    ###
    get: (name) =>
      check name, Match.Optional String
      @__return (fut) -> 
        @update()
        if not name
          fut.return _.omit @_node, ['_service', 'id', 'labels', 'metadata']
        else
          fut.return @_node[name]

    ###
    @locus Server
    @summary Set (or override, if exists) multiple property on current node
    @name properties.set
    @class Neo4jNode
    @url http://neo4j.com/docs/2.2.5/rest-api-node-properties.html#rest-api-set-property-on-node
    @param {String | Object} n  - Name of the property or Object of key:value pairs
    @param {String} v - [OPTIONAL] Value of the property
    @returns {Neo4jNode}
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
    @summary Delete all or multiple properties by name from a node. 
             If no argument is passed, - all properties will be removed from the node.
    @name properties.delete
    @class Neo4jNode
    @url http://neo4j.com/docs/2.2.5/rest-api-node-properties.html#rest-api-delete-a-named-property-from-a-node
    @url http://neo4j.com/docs/2.2.5/rest-api-node-properties.html#rest-api-delete-all-properties-from-node
    @param {[String] | String | null} names - Name or array of property names, pass `null` 
                                              or call with no arguments to remove all properties
    @returns {Neo4jNode}
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
          delete @_node[n] for n, v of _.omit @_node, ['_service', 'id', 'labels', 'metadata']
          @_db.__batch 
            method: 'DELETE'
            to: @_service.properties.endpoint
          , undefined, false, true
        fut.return @

    ###
    @locus Server
    @summary This will replace all existing properties on the node with the new set of attributes.
    @name properties.update
    @class Neo4jNode
    @url http://neo4j.com/docs/2.2.5/rest-api-node-properties.html#rest-api-update-node-properties
    @param {Object} nameValue - Object of key:value pairs
    @returns {Neo4jNode}
    ###
    update: (nameValue) =>
      check nameValue, Object
      @__return (fut) ->
        delete @_node[n] for n, v of _.omit @_node, ['_service', 'id', 'labels', 'metadata']

        for n, v of nameValue
          @_node[n] = v

        @_db.__batch 
          method: 'PUT'
          to: @_service.properties.endpoint
          body: nameValue
        , undefined, false, true
        fut.return @

  ###
  @locus Server
  @summary Get current node
  @name get
  @class Neo4jNode
  @url http://neo4j.com/docs/2.2.5/rest-api-nodes.html#rest-api-get-node
  @returns {Object}
  ###
  get: -> @__return (fut) -> fut.return super


  ###
  @locus Server
  @summary Delete current node
  @name delete
  @class Neo4jNode
  @url http://neo4j.com/docs/2.2.5/rest-api-nodes.html#rest-api-delete-node
  @returns {undefined}
  ###
  delete: -> @__return (fut) -> 
    @_db.__batch 
      method: 'DELETE'
      to: @_service.self.endpoint
    , undefined, false, true
    @node = undefined
    fut.return undefined

  ###
  @locus Server
  @summary Set / Get propert(y|ies) on current node, if only first argument is passed - will return property value, if both arguments is presented - property will be updated or created
  @name property
  @class Neo4jNode
  @url http://neo4j.com/docs/2.2.5/rest-api-node-properties.html#rest-api-get-property-for-node
  @url http://neo4j.com/docs/2.2.5/rest-api-node-properties.html#rest-api-set-property-on-node
  @param {String} name  - Name of the property
  @param {String} value - [OPTIONAL] Value of the property
  @returns {Neo4jNode | String | Boolean | Number | [String] | [Boolean] | [Number]}
  ###
  property: (name, value) ->
    check name, Match.Optional String
    return @properties.get name if not value or (not value and not name)
    check value, Match.Optional Match.OneOf String, Number, Boolean, [String], [Number], [Boolean]
    return @properties.set name, value
    

  __labels: ->
    ###
    @locus Server
    @summary Set one or multiple labels for node
    @name labels.set
    @class Neo4jNode
    @url http://neo4j.com/docs/2.2.5/rest-api-node-labels.html#rest-api-adding-multiple-labels-to-a-node
    @url http://neo4j.com/docs/2.2.5/rest-api-node-labels.html#rest-api-adding-a-label-to-a-node
    @param {[String] | String} labels - Array of Label names
    @returns {Neo4jNode}
    ###
    set: (labels) =>
      check labels, Match.OneOf String, [String]
      @__return (fut) ->
        if _.isString labels
          if labels.length > 0 and !~@_node.metadata.labels.indexOf labels
            @_node.metadata.labels.push labels
            @_db.__batch 
              method: 'POST'
              to: @_service.labels.endpoint
              body: labels
            , undefined, false, true

        else
          labels = _.uniq labels
          labels = (label for label in labels when label.length > 0)
          if labels.length > 0
            @_node.metadata.labels.push label for label in labels

            @_db.__batch 
              method: 'POST'
              to: @_service.labels.endpoint
              body: labels
            , undefined, false, true
        fut.return @

    ###
    @locus Server
    @summary This removes any labels currently exists on a node, and replaces them with the new labels passed in.
    @name labels.replace
    @class Neo4jNode
    @url http://neo4j.com/docs/2.2.5/rest-api-node-labels.html#rest-api-replacing-labels-on-a-node
    @param {[String]} labels - Array of new Label names
    @returns {Neo4jNode}
    ###
    replace: (labels) =>
      check labels, [String]
      @__return (fut) ->
        labels = _.uniq labels
        labels = (label for label in labels when label.length > 0)
        if labels.length > 0
          @_node.metadata.labels.splice 0, @_node.metadata.labels.length
          @_node.metadata.labels.push label for label in labels

          @_db.__batch 
            method: 'PUT'
            to: @_service.labels.endpoint
            body: labels
          , undefined , false, true
        fut.return @

    ###
    @locus Server
    @summary Remove one label from node
    @name labels.delete
    @class Neo4jNode
    @url http://neo4j.com/docs/2.2.5/rest-api-node-labels.html#rest-api-removing-a-label-from-a-node
    @param {String } labels - Name of Label to be removed
    @returns {Neo4jNode}
    ###
    delete: (labels) =>
      check labels, Match.OneOf String, [String]
      @__return (fut) ->
        if _.isString labels
          if labels.length > 0 and !!~@_node.metadata.labels.indexOf labels
            @_node.metadata.labels.splice @_node.metadata.labels.indexOf(labels), 1
            @_db.__batch 
              method: 'DELETE'
              to: @_service.labels.endpoint + '/' + labels
            , undefined, false, true

        else
          labels = _.uniq labels
          labels = (label for label in labels when label.length > 0 and !!~@_node.metadata.labels.indexOf label)
          if labels.length > 0
            tasks = []
            for label in labels
              @_node.metadata.labels.splice @_node.metadata.labels.indexOf(label), 1

              tasks.push
                method: 'DELETE'
                to: @_service.labels.endpoint + '/' + label

            @_db.batch tasks, plain: true
        fut.return @

  ###
  @locus Server
  @summary Return list of labels, or set new labels. If `labels` parameter is passed to the function new labels will be added to node.
  @name label
  @class Neo4jNode
  @url http://neo4j.com/docs/2.2.5/rest-api-node-labels.html#rest-api-listing-labels-for-a-node
  @url http://neo4j.com/docs/2.2.5/rest-api-node-labels.html#rest-api-adding-multiple-labels-to-a-node
  @param {[String]} labels - Array of Label names
  @returns {Neo4jNode | [String]}
  ###
  label: (labels) ->
    check labels, Match.Optional [String]
    return @labels.set labels if labels
    return @__return (fut) -> 
      @update()
      fut.return @_node.metadata.labels

  ###
  @locus Server
  @summary Return the (all | out | in) number of relationships associated with a node.
  @name degree
  @class Neo4jNode
  @url http://neo4j.com/docs/2.2.5/rest-api-node-degree.html#rest-api-get-the-degree-of-a-node
  @param {String} direction - Direction of relationships to count, one of: `all`, `out` or `in`. Default: `all`
  @param {[String]} types - Types (labels) of relationship as array
  @returns {Number}
  ###
  degree: (direction = 'all', types = []) ->
    check direction, String
    check types, Match.Optional [String]
    @__return (fut) ->
      @_db.__batch 
        method: 'GET'
        to: @_service.self.endpoint + '/degree/' + direction + '/' + types.join('&')
      , 
        (error, result) => fut.return if result.length is 0 then 0 else result
      , false, true

  ###
  @locus Server
  @summary Create relationship from current node to another
  @name to
  @class Neo4jNode
  @url http://neo4j.com/docs/2.2.5/rest-api-relationships.html#rest-api-create-a-relationship-with-properties
  @param {Number | Object | Neo4jNode} to - id or instance of node
  @param {String} type - Type (label) of relationship
  @param {Object} properties - Relationship's properties
  @param {Boolean} properties._reactive - Set Neo4jRelationship instance to reactive mode
  @returns {Neo4jRelationship}
  ###
  to: (to, type, properties = {}) ->
    to = to?.id or to?.get?().id if _.isObject to
    check to, Number
    check type, String
    check properties, Object

    @_db.relationship.create @_id, to, type, properties

  ###
  @locus Server
  @summary Create relationship to current node from another
  @name from
  @class Neo4jNode
  @url http://neo4j.com/docs/2.2.5/rest-api-relationships.html#rest-api-create-a-relationship-with-properties
  @param {Number | Object | Neo4jNode} from - id or instance of node
  @param {String} type - Type (label) of relationship
  @param {Object} properties - Relationship's properties
  @param {Boolean} properties._reactive - Set Neo4jRelationship instance to reactive mode
  @returns {Neo4jRelationship}
  ###
  from: (from, type, properties = {}) ->
    from = from?.id or from?.get?().id if _.isObject from
    check from, Number
    check type, String
    check properties, Object

    @_db.relationship.create from, @_id, type, properties

  ###
  @locus Server
  @summary Get all node's relationships
  @name relationships
  @class Neo4jNode
  @url http://neo4j.com/docs/2.2.5/rest-api-relationships.html#rest-api-get-typed-relationships
  @param {String} direction - Direction of relationships to count, one of: `all`, `out` or `in`. Default: `all`
  @param {[String]} types - Types (labels) of relationship as array
  @returns {Neo4jCursor}
  ###
  relationships: (direction = 'all', types = [], reactive = false) ->
    check direction, String
    check types, Match.Optional [String]
    check reactive, Boolean

    @__return (fut) ->
      @_db.__batch 
        method: 'GET'
        to: @_service.create_relationship.endpoint + '/' + direction + '/' + types.join('&')
      , 
        (error, result) => fut.return new Neo4jCursor result
      , reactive

  index:
    ###
    @locus Server
    @summary Create index on node for label
             This API poorly described in Neo4j Docs, so it may work in some different way - we are expecting
    @name index.create
    @class Neo4jNode
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
        to: @_current._db.__service.node_index.endpoint + '/' + label
        body: 
          key: key
          uri: @_current._service.self.endpoint
          value: type
      , undefined, false, true

    ###
    @locus Server
    @summary Get indexes on node for label
             This API poorly described in Neo4j Docs, so it may work in some different way - we are expecting
    @name index.get
    @class Neo4jNode
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
        to: "#{@_current._db.__service.node_index.endpoint}/#{label}/#{key}/#{type}/#{@_current._id}"
      , undefined, false, true

    ###
    @locus Server
    @summary Drop (remove) index on node for label
             This API poorly described in Neo4j Docs, so it may work in some different way - we are expecting
    @name index.drop
    @class Neo4jNode
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
        to: "#{@_current._db.__service.node_index.endpoint}/#{label}/#{key}/#{type}/#{@_current._id}"
      , undefined, false, true


  # path: (to, settings = {max_depth: 3, relationships: {type: 'to', direction: 'out'}, algorithm: 'shortestPath'}) ->
  #   to = to?.id or to?.get?().id if _.isObject to
  #   check to, Number
  #   check settings, {
  #     max_depth: Number
  #     cost_property: Match.Optional String
  #     relationships: {
  #       type: Match.OneOf 'to', 'from'
  #       direction: Match.OneOf 'in', 'out'
  #     }
  #     algorithm: Match.OneOf 'shortestPath', 'allSimplePaths', 'allPaths', 'dijkstra'
  #   }

  #   @__return (fut) ->
  #     @_db.__batch 
  #       method: 'POST'
  #       to: @_service..endpoint + '/' + direction + '/' + types.join('&')
  #     , 
  #       (error, result) => fut.return new Neo4jCursor result
  #     , reactive