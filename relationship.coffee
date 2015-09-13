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
        to: @_node._service.self.endpoint
      , 
        =>
          @node = undefined
          fut.return undefined
      , undefined, true

  ###
  @locus Server
  @summary Create relationship between two nodes
  @name create
  @class Neo4jRelationship
  @url http://neo4j.com/docs/2.2.5/rest-api-relationships.html#rest-api-create-a-relationship-with-properties
  @returns {Neo4jRelationship}
  ###
  # create: (from, to, type, properties = {}) -> 
    # @__return (fut) -> fut.return super


