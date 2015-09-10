###
@locus Server
@summary Represents Data state, relations, and data
         Represents as Nodes and Relationships, as well
         Might be reactive data source, if `_isReactive` passed as `true` - data of node will be updated before returning
         Usually not used directly, it is returned inside of Neo4jCursor instance until `fetch()` or `forEach` methods is called, then it's returned as plain object.
@class Neo4jData
###
class Neo4jData
  constructor: (@_node, @_isReactive = false, @_expiration = 0) -> @__refresh()
  __refresh: -> @_expire = (+new Date) + @_expiration * 1000

  @define 'node',
    get: -> 
      if @_isReactive and @_expire < +new Date
        @__refresh()
        @update()._node
      else
        @_node
    set: (newVal) -> 
      unless EJSON.equals @_node, newVal
        console.warn "[@define 'node'] [set] UPDATED!"
        @_node = newVal 

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
  @summary Update Neo4j data, only if data was requested as REST
  @name update
  @class Neo4jData
  @url http://neo4j.com/docs/2.2.5/rest-api-nodes.html#rest-api-get-node
  @returns {Object | [Object] | [String]} - Depends from cypher query
  ###
  update: ->
    @node = @_node._service.self.__getAndProceed '__parseNode' if @_node?._service
    return @