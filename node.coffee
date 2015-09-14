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
            __error error if error
            if node?.metadata
              @emit 'ready', node, fut
            else
              __error "Node is not created or created wrongly, metadata is not returned!"
        , @_isReactive, true
        return
      else
        __error "You already in node instance, create new one by calling, `db.nodes().create()`"
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
    , 
      =>
        @node = undefined
        fut.return undefined
    , undefined, true

  ###
  @locus Server
  @summary Get current node's properties
  @name properties
  @class Neo4jNode
  @url http://neo4j.com/docs/2.2.5/rest-api-node-properties.html#rest-api-get-properties-for-node
  @returns {Object}
  ###
  properties: -> @__return (fut) -> 
    @update()
    fut.return _.omit @node, ['_service', 'id', 'labels', 'metadata']

  ###
  @locus Server
  @summary Set (or override, if exists) one property on current node
  @name setProperty
  @class Neo4jNode
  @url http://neo4j.com/docs/2.2.5/rest-api-node-properties.html#rest-api-set-property-on-node
  @param {String} name  - Name of the property
  @param {String} value - Value of the property
  @returns {Neo4jNode}
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
  @summary Set (or override, if exists) multiple property on current node
  @name setProperties
  @class Neo4jNode
  @param {Object} nameValue - Object of key:value pairs
  @returns {Neo4jNode}
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
  @class Neo4jNode
  @url http://neo4j.com/docs/2.2.5/rest-api-node-properties.html#rest-api-delete-a-named-property-from-a-node
  @param {String} name  - Name of the property
  @returns {Neo4jNode}
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
  @class Neo4jNode
  @url http://neo4j.com/docs/2.2.5/rest-api-node-properties.html#rest-api-delete-all-properties-from-node
  @param {[String]} names - Array of names
  @returns {Neo4jNode}
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
        delete @_node[k] for k, v of _.omit @_node, ['_service', 'id', 'labels', 'metadata']
        @_db.__batch 
          method: 'DELETE'
          to: @_service.properties.endpoint
        , 
          => fut.return @
        , undefined, true

  ###
  @locus Server
  @summary This will replace all existing properties on the node with the new set of attributes.
  @name updateProperties
  @class Neo4jNode
  @url http://neo4j.com/docs/2.2.5/rest-api-node-properties.html#rest-api-update-node-properties
  @param {Object} nameValue - Object of key:value pairs
  @returns {Neo4jNode}
  ###
  updateProperties: (nameValue) ->
    check nameValue, Object
    @__return (fut) ->
      delete @_node[k] for k, v of _.omit @_node, ['_service', 'id', 'labels', 'metadata']

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
  @summary Set / Get property on current node, if only first argument is passed - will return property value, if both arguments is presented - property will be updated or created
  @name setProperty
  @class Neo4jNode
  @url http://neo4j.com/docs/2.2.5/rest-api-node-properties.html#rest-api-get-property-for-node
  @url http://neo4j.com/docs/2.2.5/rest-api-node-properties.html#rest-api-set-property-on-node
  @param {String} name  - Name of the property
  @param {String} value - [OPTIONAL] Value of the property
  @returns {Neo4jNode | String | Boolean | Number | [String] | [Boolean] | [Number]}
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
  @class Neo4jNode
  @url http://neo4j.com/docs/2.2.5/rest-api-node-properties.html#rest-api-get-property-for-node
  @param {String} name - Name of the property
  @returns {String | Boolean | Number | [String] | [Boolean] | [Number]}
  ###
  getProperty: (name) -> @__return (fut) => 
    @update()
    fut.return @node[name]

  ###
  @locus Server
  @summary Set one label for node
  @name setLabel
  @class Neo4jNode
  @url http://neo4j.com/docs/2.2.5/rest-api-node-labels.html#rest-api-adding-a-label-to-a-node
  @param {String} label - Name of the Label
  @returns {Neo4jNode}
  ###
  setLabel: (label) ->
    check label, String
    @__return (fut) ->
      if label.length > 0 and !~@_node.metadata.labels.indexOf label
        @_node.metadata.labels.push label
        @_db.__batch 
          method: 'POST'
          to: @_service.labels.endpoint
          body: label
        , 
          => fut.return @
        , undefined, true
      else
        fut.return @

  ###
  @locus Server
  @summary Set multiple labels for node
  @name setLabels
  @class Neo4jNode
  @url http://neo4j.com/docs/2.2.5/rest-api-node-labels.html#rest-api-adding-multiple-labels-to-a-node
  @param {[String]} labels - Array of Label names
  @returns {Neo4jNode}
  ###
  setLabels: (labels) ->
    check labels, [String]
    @__return (fut) ->
      labels = _.uniq labels
      labels = (label for label in labels when label.length > 0)
      if labels.length > 0
        @_node.metadata.labels.push label for label in labels

        @_db.__batch 
          method: 'POST'
          to: @_service.labels.endpoint
          body: labels
        , 
          => fut.return @
        , undefined, true
      else
        fut.return @

  ###
  @locus Server
  @summary This removes any labels currently on a node, and replaces them with the labels passed in as the request body.
  @name replaceLabels
  @class Neo4jNode
  @url http://neo4j.com/docs/2.2.5/rest-api-node-labels.html#rest-api-replacing-labels-on-a-node
  @param {[String]} labels - Array of new Label names
  @returns {Neo4jNode}
  ###
  replaceLabels: (labels) ->
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
        , 
          => fut.return @
        , undefined, true
      else
        fut.return @

  ###
  @locus Server
  @summary Remove one label from node
  @name deleteLabel
  @class Neo4jNode
  @url http://neo4j.com/docs/2.2.5/rest-api-node-labels.html#rest-api-removing-a-label-from-a-node
  @param {String} label - Name of Label to be removed
  @returns {Neo4jNode}
  ###
  deleteLabel: (label) ->
    check label, String
    @__return (fut) ->
      if label.length > 0 and !!~@_node.metadata.labels.indexOf label
        @_node.metadata.labels.splice @_node.metadata.labels.indexOf(label), 1
        @_db.__batch 
          method: 'DELETE'
          to: @_service.labels.endpoint + '/' + label
        , 
          => fut.return @
        , undefined, true
      else
        fut.return @

  ###
  @locus Server
  @summary Remove multiple labels from node
  @name deleteLabels
  @class Neo4jNode
  @url http://neo4j.com/docs/2.2.5/rest-api-node-labels.html#rest-api-removing-a-label-from-a-node
  @param {[String]} label - Array of Label names to be removed
  @returns {Neo4jNode}
  ###
  deleteLabels: (labels) ->
    check labels, [String]
    @__return (fut) ->
      labels = _.uniq labels
      labels = (label for label in labels when label.length > 0 and !!~@_node.metadata.labels.indexOf label)

      if labels.length > 0
        tasks = []
        for label in labels
          @_node.metadata.labels.splice @_node.metadata.labels.indexOf(label), 1

          tasks.push
            method: 'DELETE'
            to: @_service.labels.endpoint + '/' + label

        @_db.batch tasks, =>
          fut.return @
        , false, true
      else
        fut.return @

  ###
  @locus Server
  @summary Return list of labels, or set new labels. If `labels` parameter is passed to the function new labels will be added to node.
  @name labels
  @class Neo4jNode
  @url http://neo4j.com/docs/2.2.5/rest-api-node-labels.html#rest-api-listing-labels-for-a-node
  @url http://neo4j.com/docs/2.2.5/rest-api-node-labels.html#rest-api-adding-multiple-labels-to-a-node
  @param {[String]} labels - Array of Label names
  @returns {Neo4jNode | [String]}
  ###
  labels: (labels) ->
    check labels, Match.Optional [String]
    return @setLabels labels if labels
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

    @_db.createRelation @_id, to, type, properties

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

    @_db.createRelation from, @_id, type, properties

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
