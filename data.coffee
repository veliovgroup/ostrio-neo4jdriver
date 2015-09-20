###
@locus Server
@summary Represents Data state, relations, and data
         Represents as Nodes and Relationships, as well
         Might be reactive data source, if `_isReactive` passed as `true` - data of node will be updated before returning
         Usually not used directly, it is returned inside of Neo4jCursor instance until `fetch()` or `forEach` methods is called, then it's returned as plain object.
@class Neo4jData
###
class Neo4jData
  constructor: (n, @_isReactive = false, @_expiration = 0) -> 
    @node = n
    @__refresh()
  __refresh: -> @_expire = (+new Date) + @_expiration * 1000

  @define 'node',
    get: -> 
      if @_isReactive and @_expire < +new Date
        @update()._node
      else
        @_node
    set: (value) -> 
      unless EJSON.equals @_node, value
        if value?._service
          @_service = _.clone value._service
          delete value._service
        @_node = value

  ###
  @locus Server
  @summary Get Neo4j data, if data was requested with REST data
           and it's reactive, will return updated data
  @name get
  @class Neo4jData
  @url http://neo4j.com/docs/2.2.5/rest-api-nodes.html#rest-api-get-node
  @returns {Object | [Object] | [String]} - Depends from cypher query
  ###
  get: -> @node

  ###
  @locus Server
  @summary Update Neo4j data, only if data was requested as REST and instance is reactive
  @name update
  @class Neo4jData
  @url http://neo4j.com/docs/2.2.5/rest-api-nodes.html#rest-api-get-node
  @param {Boolean} force - Force node's data update
  @returns {Object | [Object] | [String]} - Depends from cypher query
  ###
  update: (force = false) ->
    if @_node and @_service and @_isReactive or force
      @__refresh()
      @node = @_service.self.__getAndProceed '__parseNode' 
    return @