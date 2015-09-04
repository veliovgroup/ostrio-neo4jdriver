class Neo4jCursor
  _cursor = {}
  constructor: (cursor) ->
    _cursor = cursor

  fetch: -> 
    data = []
    @forEach (row) -> data.push row
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

  forEach: (callback) ->
    check callback, Function
    for row, rowId in @cursor
      data = {}
      if _.isObject row
        for nodeAlias, node of row
          data[nodeAlias] = node?.get()
      callback data, rowId
    return undefined

  @define 'cursor',
    get: -> _cursor
    set: -> console.warn "This is not going to work, you trying to reset cursor, make new Cypher query instead"