###
@locus Server
@summary Implementation of cursor for Neo4j results
@class Neo4jCursor
###
class Neo4jCursor
  constructor: (@_cursor) ->
    @length = @_cursor.length
    @_current = 0
    @hasNext = if @_cursor.length > 1 then true else false
    @hasPrevious = false
  @define 'cursor',
    get: -> @_cursor
    set: -> console.warn "This is not going to work, you trying to reset cursor, make new Cypher query instead"

  ###
  @locus Server
  @summary Returns array of fetched rows. If query was passed with `reactive` option - data will be updated each event loop.
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
  @summary Move cursor to first item and return it
  @name first
  @class Neo4jCursor
  @returns {[Object]} - Array of nodes or undefined if cursor has no items
  ###
  first: -> 
    @_current = 0
    @hasNext = if @_cursor.length > 1 then true else false
    @hasPrevious = false
    @_cursor[0]

  ###
  @locus Server
  @summary Get current nodes on cursor
  @name current
  @class Neo4jCursor
  @returns {[Object]} - Array of nodes
  ###
  current: -> @_cursor[@_current]

  ###
  @locus Server
  @summary Go to next item on cursor and return it
  @name next
  @class Neo4jCursor
  @returns {[Object]} - Array of nodes, or `undefined` if no next item
  ###
  next: -> 
    if @hasNext
      if @_current <= @length - 1
        ++@_current
        @hasNext = if @_current is @length - 1 then false else true
        @hasPrevious = true
        @_cursor[@_current]

  ###
  @locus Server
  @summary Go to previous item on cursor and return it
  @name previous
  @class Neo4jCursor
  @returns {[Object]} - Array of nodes, or `undefined` if no previous item
  ###
  previous: -> 
    if @hasPrevious
      if @_current >= 1
        --@_current
        @hasNext = true
        @hasPrevious = if @_current is 0 then false else true
        @_cursor[@_current]

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
  @summary Iterates thought Neo4j query results. And returns data as Neo4jData, Neo4jRelationship or Neo4jNode instance (depends from Cypher query). This function will move cursor to latest item.
  @name each
  @class Neo4jCursor
  @param {Function} callback - Callback function, with `node` (as Neo4jData, Neo4jRelationship or Neo4jNode instance), `num`, `cursor` arguments
  @returns {undefined}
  ###
  each: (callback) -> 
    check callback, Function
    if @length > 0
      first = true
      while @hasNext or first
        if first
          callback @first(), @_current, @_cursor
          first = false
        else
          callback @next(), @_current, @_cursor
    return

  ###
  @locus Server
  @summary Iterates though Neo4j query results. If query was passed with `reactive` option - data will be updated each event loop.
  @name forEach
  @class Neo4jCursor
  @param {Function} callback - Callback function, with `node` (plain object), `num`, `cursor` arguments
  @returns {undefined}
  ###
  forEach: (callback, firstOnly) ->
    check callback, Function
    for row, rowId in @cursor
      data = {}

      if _.isFunction row?.get
        data = row.get()
      else if _.isObject row
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
      callback data, rowId, @_cursor
      break if firstOnly
    return
