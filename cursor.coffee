###
@locus Server
@summary Implementation of cursor for Neo4j results
@class Neo4jCursor
###
class Neo4jCursor
  constructor: (@_cursor) ->
    @length = @_cursor.length
  @define 'cursor',
    get: -> @_cursor
    set: -> console.warn "This is not going to work, you trying to reset cursor, make new Cypher query instead"

  ###
  @locus Server
  @summary Returns array of fetched rows. If query was passed with `reactive` option - data will be updated each event loop. This method is chainable.
  @name forEach
  @class Neo4jCursor
  @returns {[Object]} - Returns array of fetched rows
  ###
  fetch: (firstOnly) -> 
    data = []
    @forEach (row) -> 
      data.push row
    , firstOnly
    data

  ###
  @locus Server
  @summary [EXPEMENETAL] Puts all unique nodes from current cursor into Mongo collection
  @name toMongo
  @class Neo4jCursor
  @param {Collection} MongoCollection - Instance of Mongo collection created via `new Mongo.Collection()`
  @returns {Collection}
  ###
  toMongo: (MongoCollection) ->
    check MongoCollection, Mongo.Collection

    MongoCollection._ensureIndex
      id: 1
    ,
      background: true
      sparse: true
      unique: true

    nodes = {}
    @forEach (row) ->
      for nodeAlias, node of row
        if node?id
          nodes[node.id] ?= columns: [nodeAlias]
          nodes[node.id].columns = _.union nodes[node.id].columns, [nodeAlias]
          nodes[node.id] = _.extend nodes[node.id], node
          if nodes[node.id]?._service
            nodes[node.id]._service = undefined
            delete nodes[node.id]._service 

          MongoCollection.upsert 
            id: node.id
          , 
            $set: nodes[node.id]

    return MongoCollection

  ###
  @locus Server
  @summary Shortcut for `forEach` method, see more info below.
  @name each
  @class Neo4jCursor
  @returns {undefined}
  ###
  each: (callback) -> @forEach callback

  ###
  @locus Server
  @summary Iterates though Neo4j query results. If query was passed with `reactive` option - data will be updated each event loop.
  @name forEach
  @class Neo4jCursor
  @param {Function} callback - Callback function, with `row`, `num` arguments
  @returns {undefined}
  ###
  forEach: (callback, firstOnly) ->
    check callback, Function
    for row, rowId in @cursor
      data = {}
      if _.isObject row
        for nodeAlias, node of row

          if nodeAlias is 'nodes'
            node = _.clone node
            for n, i in node
              node[i] = n.get() if n?.get?()

          if nodeAlias is 'relationships'
            node = _.clone node
            for r, i in node
              node[i] = r.get() if r?.get?()

          if node?.get?()
            data[nodeAlias] = node.get()
          else
            data[nodeAlias] = node
      callback data, rowId
      break if firstOnly
    return undefined
