class Neo4jCursor
  constructor: (@_cursor) ->
  fetch: (firstOnly) -> 
    data = []
    @forEach (row) -> 
      data.push row
    , firstOnly
    data

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

  each: (callback) -> @forEach callback

  forEach: (callback, firstOnly) ->
    check callback, Function
    for row, rowId in @cursor
      data = {}
      if _.isObject row
        for nodeAlias, node of row
          if node?.get?()
            data[nodeAlias] = node.get()
          else
            data[nodeAlias] = node
      callback data, rowId
      break if firstOnly
    return undefined

  @define 'cursor',
    get: -> @_cursor
    set: -> console.warn "This is not going to work, you trying to reset cursor, make new Cypher query instead"