###
@locus Server
@summary Represents Data state, relations, and data
         Represents as Nodes and Relationships, as well
         Might be reactive data source, if `_isReactive` passed as `true` - data of node will be updated before returning
@class Neo4jData
###
class Neo4jData
  constructor: (@_node, @_isReactive = false) -> @__refresh()
  __refresh: -> @_expire = (+new Date) + 2000

  @define 'node',
    get: -> 
      if @_isReactive and @_expire < +new Date
        @__refresh()
        @update()._node
      else
        @_node
    set: (newVal) -> 
      @_node = newVal unless EJSON.equals @_node, newVal

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
    if @_node?._service
      @node = @_node._service.self.get()
    return @