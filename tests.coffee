db = new Neo4jDB 'http://localhost:7474', {username: 'neo4j', password: '1234'}


__nodeCRC__ = (test, node, labels, props) ->
  test.isTrue _.has node, 'id'
  test.isTrue _.isNumber node.id

  test.isTrue _.has node, 'metadata'
  test.isTrue _.has node.metadata, 'id'
  test.isTrue _.isNumber node.metadata.id
  test.equal node.id, node.metadata.id

  if props
    for key, value of props
      test.isTrue _.has node, key
      test.equal node[key], value

  test.isTrue _.has node, 'labels', "node.labels always persists"
  test.isTrue _.has node.metadata, 'labels', "node.metadata.labels always persists"
  if labels
    for label in labels
      test.isTrue !!~node.labels.indexOf label

      test.isTrue !!~node.metadata.labels.indexOf label
  else
    test.equal node.labels.length, 0, "node.labels is empty if no labels"
    test.equal node.labels.metadata,length, 0, "node.metadata.labels is empty if no labels"

__SyncTest__ = (test, funcName) ->
  test.isTrue _.isFunction(db[funcName]), "[db.#{funcName}] Exists"
  cursor = db[funcName] "CREATE (n:#{funcName}SyncTests {data}) RETURN n", data: foo: funcName

  test.isTrue _.isFunction(cursor.fetch), "[db.#{funcName}] Returns Neo4jCollection"
  row = cursor.fetch()
  test.equal row.length, 1, "[CREATE] [fetch()] Returns only one record"

  test.isTrue _.has row[0], 'n'
  node = row[0].n

  __nodeCRC__ test, node, ["#{funcName}SyncTests"], {foo: funcName}

  row = db[funcName]("MATCH (n:#{funcName}SyncTests) RETURN n").fetch()
  test.equal row.length, 1, "[MATCH] [fetch()] Returns only one record"

  test.equal db[funcName]("MATCH (n:#{funcName}SyncTests) DELETE n").fetch().length, 0, "[DELETE] [fetch()] Returns empty array"

  row = db[funcName]("MATCH (n:#{funcName}SyncTests) RETURN n").fetch()
  test.equal row.length, 0, "[MATCH] [fetch] [after DELETE] Returns empty array"

__SyncReactiveTest__ = (test, funcName) ->
  test.isTrue _.isFunction(db[funcName]), "[db.#{funcName}] Exists"

  cursor = db[funcName] 
    query: "CREATE (n:#{funcName}SyncReactiveTests {data}) RETURN n"
    opts: data: foo: "#{funcName}SyncReactiveTests"
    reactive: true

  node = cursor.fetch()[0]
  __nodeCRC__ test, node.n, ["#{funcName}SyncReactiveTests"], {foo: "#{funcName}SyncReactiveTests"}

  db[funcName] "MATCH n WHERE id(n) = {id} SET n.newProp = 'rrrreactive!'", {id: node.n.id}

  node = cursor.fetch()[0]
  __nodeCRC__ test, node.n, ["#{funcName}SyncReactiveTests"], {foo: "#{funcName}SyncReactiveTests", newProp: 'rrrreactive!'}

  db[funcName] "MATCH (n:#{funcName}SyncReactiveTests) DELETE n"

__BasicsTest__ = (test, funcName) ->
  test.isTrue _.isFunction(db[funcName]), "[#{funcName}] Exists on DB object"
  cursors = []
  cursors.push db[funcName] "CREATE (n:#{funcName}TestBasics {data}) RETURN n", data: foo: 'bar'
  cursors.push db[funcName] "MATCH (n:#{funcName}TestBasics) RETURN n"
  cursors.push db[funcName] 
    query: "MATCH (n:#{funcName}TestBasics {foo: {data}}) RETURN n"
    params: data: 'bar'

  fut = new Future()
  db[funcName] 
    cypher: "MATCH (n:#{funcName}TestBasics {foo: {data}}) RETURN n"
    parameters: data: 'bar'
    cb: (error, cursor) -> fut.return cursor
  cursors.push fut.wait()

  fut = new Future()
  db[funcName] 
    cypher: "MATCH (n:#{funcName}TestBasics {foo: {data}}) RETURN n"
    opts: data: 'bar'
    callback: (error, cursor) -> fut.return cursor
  cursors.push fut.wait()

  for cursor in cursors
    test.isTrue _.isFunction(cursor.fetch), "[query] Returns Neo4jCollection"
    row = cursor.fetch()
    test.equal row.length, 1, "[CREATE | MATCH] [fetch()] Returns only one record"

    test.isTrue _.has row[0], 'n'
    node = row[0].n

    __nodeCRC__ test, node, ["#{funcName}TestBasics"], {foo: 'bar'}

  cursors = []

  cursors.push db[funcName] 
    cypher: "MATCH (n:#{funcName}TestBasics) RETURN n"
    reactive: true
  cursors.push db[funcName] 
    cypher: "MATCH (n:#{funcName}TestBasics) RETURN n"
    reactiveNodes: true

  for cursor in cursors
    test.isTrue _.isFunction cursor._cursor[0].n.get
    test.isTrue _.isFunction cursor._cursor[0].n.update
    test.isTrue _.isFunction cursor._cursor[0].n.__refresh
    test.isTrue cursor._cursor[0].n._isReactive, "Reactive node"

  test.equal db[funcName]("MATCH (n:#{funcName}TestBasics) DELETE n").fetch().length, 0, "[DELETE] [fetch()] Returns empty array"
  row = db[funcName]("MATCH (n:#{funcName}TestBasics) RETURN n").fetch()
  test.equal row.length, 0, "[MATCH] [fetch] [after DELETE] Returns empty array"

__AsyncBasicsTest__ = (test, completed, funcName) ->
  test.isTrue _.isFunction(db[funcName]), "[#{funcName}] Exists on DB object"
  db[funcName] "CREATE (n:#{funcName}AsyncTest {data}) RETURN n", {data: Async: "#{funcName}AsyncTest"}, (error, cursor) ->
    test.isNull error, "No error"
    nodes = cursor.fetch()
    test.equal nodes.length, 1, "Only one node is created"
    test.isTrue _.has nodes[0], 'n'
    __nodeCRC__ test, nodes[0].n, ["#{funcName}AsyncTest"], {Async: "#{funcName}AsyncTest"}

    db[funcName] "MATCH (n:#{funcName}AsyncTest) DELETE n", (error, cursor) ->
      test.isNull error, "No error"
      nodes = cursor.fetch()
      test.equal nodes.length, 0, "No nodes is returned on DELETE"
      completed()

__nodesInstanceCRC__ = (test, node) ->
  test.instanceOf node, Neo4jNode
  test.isTrue _.isFunction node.getProperty
  test.isTrue _.isFunction node.property
  test.isTrue _.isFunction node.updateProperties
  test.isTrue _.isFunction node.setProperties
  test.isTrue _.isFunction node.setProperty
  test.isTrue _.isFunction node.properties
  test.isTrue _.isFunction node.delete
  test.isTrue _.isFunction node.get
  test.isTrue _.isFunction node.__refresh
  test.isTrue _.isFunction node.update

Tinytest.add 'service endpoints', (test) ->
  test.isTrue _.isArray db.propertyKeys()
  test.isTrue _.isArray db.labels()
  test.isTrue _.isArray db.relationshipTypes()
  test.isTrue _.isString db.version()

###
@test 
@description basics
query: (cypher, opts = {}) ->
###
Tinytest.add 'db.query [BASICS]', (test) -> __BasicsTest__ test, 'query'

###
@test 
@description basics
cypher: (cypher, opts = {}) ->
###
Tinytest.add 'db.cypher [BASICS]', (test) -> __BasicsTest__ test, 'cypher'

###
@test 
@description Test standard query, Synchronous, with replacements
query: (cypher, opts = {}) ->
###
Tinytest.add 'db.query [SYNC]', (test) -> __SyncTest__ test, 'query'

###
Any idea how to test this one?
It throws an exception inside driver
###
# Tinytest.add 'db.query [Wrong cypher] [SYNC] (You will see errors at server console)', (test) ->
#   test.expect_fail()
#   test.throws db.query("MATCh (n:) RETRN n"), 
#     """
# "MATCh (n:) RETRN n"
#           ^  
#   { code: 'Neo.ClientError.Statement.InvalidSyntax' }  
#   Invalid input ')': expected whitespace or a label name (line 1, column 10 (offset: 9))
#     """


###
@test 
@description Passing wrong Cypher query
query: (cypher, callback) ->
###
Tinytest.addAsync 'db.query [Wrong cypher] [ASYNC] (You will see errors at server console)', (test, completed) ->
  db.query "MATCh (n:) RETRN n", (error, data) ->
    test.isTrue _.isString error
    test.isTrue _.isEmpty data.fetch()
    completed()

###
@test 
@description Test standard async query
query: (cypher, opts = {}, callback) ->
###
Tinytest.add 'db.query [ASYNC]', (test) ->
  fut = new Future()
  db.query "CREATE (n:QueryTestAsync {data}) RETURN n", data: foo: 'bar', (error, cursor) -> fut.return cursor
  cursor = fut.wait()
  test.isTrue _.isFunction(cursor.fetch), "db.query Returns Neo4jCollection"

  row = cursor.fetch()
  test.equal row.length, 1, "[CREATE] [fetch()] Returns only one record"

  test.isTrue _.has row[0], 'n'
  node = row[0].n

  __nodeCRC__ test, node, ['QueryTestAsync'], {foo: 'bar'}

  fut = new Future()
  db.query "MATCH (n:QueryTestAsync) RETURN n", (error, cursor) -> fut.return cursor.fetch()
  row = fut.wait()
  test.equal row.length, 1, "[MATCH] [fetch()] Returns only one record"

  fut = new Future()
  db.query "MATCH (n:QueryTestAsync) DELETE n", (error, cursor) -> fut.return cursor
  cursor = fut.wait()
  test.equal cursor.fetch().length, 0, "[DELETE] [fetch()] Returns empty array"

  fut = new Future()
  db.query "MATCH (n:QueryTestAsync) RETURN n", (error, cursor) -> fut.return cursor.fetch()
  row = fut.wait()
  test.equal row.length, 0, "[MATCH] [fetch] [after DELETE] Returns empty array"

###
@test 
@description Test query basics of async
query: (cypher, opts, callback) ->
###
Tinytest.addAsync 'db.query [ASYNC] [BASICS]', (test, completed) -> __AsyncBasicsTest__ test, completed, 'query'

###
@test 
@description Test cypher basics of async
cypher: (cypher, opts, callback) ->
###
Tinytest.addAsync 'db.cypher [ASYNC] [BASICS]', (test, completed) -> __AsyncBasicsTest__ test, completed, 'cypher'

###
@test 
@description Test queryAsync
queryAsync: (cypher, opts, callback) ->
###
Tinytest.addAsync 'db.queryAsync [with callback]', (test, completed) -> __AsyncBasicsTest__ test, completed, 'queryAsync'

###
@test 
@description Test queryOne
queryOne: (cypher, opts) ->
###
Tinytest.add 'db.queryOne', (test) ->
  test.isTrue _.isFunction(db.queryOne), "[queryOne] Exists on DB object"
  node = db.queryOne "CREATE (n:QueryOneTest {data}) RETURN n", data: test: true
  test.isTrue _.has node, 'n'
  __nodeCRC__ test, node.n, ['QueryOneTest'], {test: true}
  db.queryAsync "MATCH (n:QueryOneTest) DELETE n"


###
@test 
@description Test queryOne non existent node, should return undefined
queryOne: (cypher) ->
###
Tinytest.add 'db.queryOne [ForSureNonExists]', (test) ->
  test.equal db.queryOne("MATCH (n:ForSureNonExists) RETURN n"), undefined


###
@test 
@description Test queryAsync
queryAsync: (cypher, opts, callback) ->
###
Tinytest.addAsync 'db.queryAsync [no callback]', (test, completed) ->
  test.isTrue _.isFunction(db.queryAsync), "[queryAsync] Exists on DB object"
  db.queryAsync "CREATE (n:QueryAsyncNoCBTest {data}) RETURN n", {data: queryAsyncNoCB: 'queryAsyncNoCB'}

  listen = (cb) -> Meteor.setTimeout cb, 1
  getNewNode = ->
    listen ->
      nodes = db.query("MATCH (n:QueryAsyncNoCBTest) RETURN n").fetch()
      node = nodes[0]
      if not _.isEmpty(node) and _.has node, 'n'
        test.equal nodes.length, 1, "Only one node is created"
        db.queryAsync "MATCH (n:QueryAsyncNoCBTest) DELETE n"
        removeNode()
      else
        getNewNode()

  removeNode = ->
    listen ->
      node = db.queryOne "MATCH (n:QueryAsyncNoCBTest) RETURN n"
      unless node
        test.isUndefined node
        completed()
      else
        removeNode()
  getNewNode()


###
@test 
@description Test querySync
querySync: (cypher, opts) ->
###
Tinytest.add 'db.querySync', (test) -> __SyncTest__ test, 'querySync'

###
@test 
@description Test querySync
query: (settings.reactive: true, opts = {}) ->
###
Tinytest.add 'db.query [SYNC] [REACTIVE NODES]', (test) -> __SyncReactiveTest__ test, 'query'

###
@test 
@description Test cypher
cypher: (settings, opts = {}) ->
###
Tinytest.add 'db.cypher [SYNC]', (test) -> __SyncTest__ test, 'cypher'

###
@test 
@description Test cypher reactive nodes
cypher: (settings.reactive: true, opts = {}) ->
###
Tinytest.add 'db.cypher [SYNC] [REACTIVE NODES]', (test) -> __SyncReactiveTest__ test, 'cypher'

###
@test 
@description Check `.transaction` method returns Neo4jTransaction instance, and it has all required methods
db.transaction()
###
Tinytest.add 'db.transaction [BASICS / open / rollback]', (test) ->
  test.isTrue _.isFunction(db.transaction), "[transaction] exists on db object"
  t = db.transaction()
  test.instanceOf t, Neo4jTransaction
  test.isTrue _.isFunction t.last
  test.isTrue _.isFunction t.current
  test.isTrue _.isFunction t.commit
  test.isTrue _.isFunction t.execute
  test.isTrue _.isFunction t.resetTimeout
  test.isTrue _.isFunction t.rollback
  t.rollback()

Tinytest.add 'db.transaction [resetTimeout] (waits for 1 sec to see difference)', (test) ->
  t = db.transaction()
  ea = t._expiresAt
  fut = new Future()
  Meteor.setTimeout ->
    fut.return true
  ,
    1000
  fut.wait()

  t.resetTimeout()
  new_ea = t._expiresAt
  test.isFalse new_ea is ea
  t.rollback()

###
@test 
@description Check Neo4jTransaction `.current()` and  `.rollback()` methods 
db.transaction().current().rollback()
###
Tinytest.add 'db.transaction [current / rollback]', (test) ->
  t = db.transaction "CREATE (n:TransactionsTesting {data})", data: transaction: true
  current = t.current()
  test.isTrue _.isFunction current[0].fetch
  test.isTrue _.isEmpty current[0].fetch()
  t.rollback()
  test.equal db.queryOne("MATCH (n:TransactionsTesting) RETURN n"), undefined

###
@test 
@description Check Neo4jTransaction `.execute()` and  `.rollback()` methods 
db.transaction().execute().rollback()
###
Tinytest.add 'db.transaction [execute / rollback]', (test) ->
  t = db.transaction "CREATE (n:TransactionsTesting {data}) RETURN n", data: transaction: true
  current = t.current()
  node = current[0].fetch()[0]
  __nodeCRC__ test, node.n, ['TransactionsTesting'], {transaction: true}

  t.execute "CREATE (n:TransactionsTesting2 {data}) RETURN n", data: transaction2: true
  current = t.current()
  node = current[1].fetch()[0]
  __nodeCRC__ test, node.n, ['TransactionsTesting2'], {transaction2: true}

  t.rollback()
  test.equal db.queryOne("MATCH (n:TransactionsTesting) RETURN n"), undefined
  test.equal db.queryOne("MATCH (n:TransactionsTesting2) RETURN n"), undefined

###
@test 
@description Check Neo4jTransaction `.execute()` and  `.commit()` methods 
db.transaction().execute().commit()
###
Tinytest.add 'db.transaction [execute / commit]', (test) ->
  t = db.transaction "CREATE (n:TransactionsTesting {data}) RETURN n", data: transaction: true
  current = t.current()
  node = current[0].fetch()[0]
  __nodeCRC__ test, node.n, ['TransactionsTesting'], {transaction: true}

  t.execute "CREATE (n:TransactionsTesting2 {data}) RETURN n", data: transaction2: true
  current = t.current()
  node = current[1].fetch()[0]
  __nodeCRC__ test, node.n, ['TransactionsTesting2'], {transaction2: true}

  result = t.commit()
  test.equal db.queryOne("MATCH (n:TransactionsTesting) RETURN n"), result[0].fetch()[0]
  test.equal db.queryOne("MATCH (n:TransactionsTesting2) RETURN n"), result[1].fetch()[0]

  db.transaction().commit "MATCH (n:TransactionsTesting), (n2:TransactionsTesting2) DELETE n, n2"
  test.equal db.queryOne("MATCH (n:TransactionsTesting) RETURN n"), undefined
  test.equal db.queryOne("MATCH (n:TransactionsTesting2) RETURN n"), undefined

###
@test 
@description Check Neo4jTransaction `.execute()`, `.current()` and  `.rollback()` methods 
db.transaction().execute(['query', 'query']).current().rollback()
###
Tinytest.add 'db.transaction [execute multiple / current / rollback]', (test) ->
  t = db.transaction()

  t.execute ["CREATE (n:TransactionsTesting {data1}) RETURN n", "CREATE (n:TransactionsTesting2 {data2}) RETURN n"]
  , 
    data1: transaction: true
    data2: transaction2: true

  current = t.current()
  node1 = current[0].fetch()[0]
  __nodeCRC__ test, node1.n, ['TransactionsTesting'], {transaction: true}

  node2 = current[1].fetch()[0]
  __nodeCRC__ test, node2.n, ['TransactionsTesting2'], {transaction2: true}

  t.rollback()
  test.equal db.queryOne("MATCH (n:TransactionsTesting) RETURN n"), undefined
  test.equal db.queryOne("MATCH (n:TransactionsTesting2) RETURN n"), undefined

###
@test 
@description Check Neo4jTransaction `.execute()` and  `.commit()` methods 
db.transaction().execute(['query', 'query']).commit()
###
Tinytest.add 'db.transaction [execute multiple / commit]', (test) ->
  db.transaction().execute(
    ["CREATE (n:TransactionsTesting {data1})", "CREATE (n:TransactionsTesting2 {data2})"]
  , 
    data1: transaction: true
    data2: transaction2: true
  ).commit()

  node1 = db.queryOne("MATCH (n:TransactionsTesting) RETURN n")
  __nodeCRC__ test, node1.n, ['TransactionsTesting'], {transaction: true}

  node2 = db.queryOne("MATCH (n:TransactionsTesting2) RETURN n")
  __nodeCRC__ test, node2.n, ['TransactionsTesting2'], {transaction2: true}

  db.transaction().commit ["MATCH (n:TransactionsTesting) DELETE n", "MATCH (n:TransactionsTesting2) DELETE n"]
  test.equal db.queryOne("MATCH (n:TransactionsTesting) RETURN n"), undefined
  test.equal db.queryOne("MATCH (n:TransactionsTesting2) RETURN n"), undefined


###
@test 
@description Check Neo4jTransaction `.last()` method
db.transaction().execute(['query', 'query']).last().rollback()
###
Tinytest.add 'db.transaction [last]', (test) ->
  t = db.transaction().execute(
    ["CREATE (n:TransactionsTesting {data1})", "CREATE (n:TransactionsTesting2 {data2}) RETURN n"]
  , 
    data1: transaction: true
    data2: transaction2: 'true'
  )

  __nodeCRC__ test, t.last().fetch()[0].n, ['TransactionsTesting2'], {transaction2: 'true'}
  t.rollback()

###
@test 
@description Check Neo4jTransaction `.execute()` and  `.commit()` methods 
db.transaction().execute().commit(cb:function())
###
Tinytest.addAsync 'db.transaction [commit] [ASYNC]', (test, completed) ->
  db.transaction().commit
    query: "CREATE (n:TransactionsCommitAsync {foo: {data}}) RETURN n"
    params: data: 'bar'
    cb: (err, res)->
      bound ->
        node = res[0].fetch()[0]
        __nodeCRC__ test, node.n, ['TransactionsCommitAsync'], {foo: 'bar'}
        db.queryAsync "MATCH (n:TransactionsCommitAsync) DELETE n"
        completed()

###
@test 
@description Check Neo4jTransaction `.execute()` and  `.commit()` methods 
db.transaction().execute().commit(function)
###
Tinytest.addAsync 'db.transaction [commit] [ASYNC] 2', (test, completed) ->
  db.transaction("CREATE (n:TransactionsCommitAsync2 {foo: {data}}) RETURN n", {data: 'bar'}).commit (err, res)->
    bound ->
      node = res[0].fetch()[0]
      __nodeCRC__ test, node.n, ['TransactionsCommitAsync2'], {foo: 'bar'}
      db.queryAsync "MATCH (n:TransactionsCommitAsync2) DELETE n"
      completed()

###
@test 
@description Check Neo4jTransaction `.commit()` method within reactive nodes 
db.transaction()().commit()
###
Tinytest.addAsync 'db.transaction [commit] [ASYNC] [REACTIVE NODES]', (test, completed) ->
  db.transaction().commit
    query: "CREATE (n:TransactionsCommitReactiveAsync {foo: {data}}) RETURN n"
    params: data: 'TCRA'
    reactive: true
    cb: (err, res)->
      bound ->
        node = res[0].fetch()[0]
        __nodeCRC__ test, node.n, ['TransactionsCommitReactiveAsync'], {foo: 'TCRA'}

        db.querySync "MATCH n WHERE id(n) = {id} SET n.newProp = 'rrrreactive!'", {id: node.n.id}

        node = res[0].fetch()[0]
        __nodeCRC__ test, node.n, ["TransactionsCommitReactiveAsync"], {foo: "TCRA", newProp: 'rrrreactive!'}

        db.queryAsync "MATCH (n:TransactionsCommitReactiveAsync) DELETE n"
        completed()

###
@test 
@description Check Neo4jTransaction check empty transaction
db.transaction().rollback()
###
Tinytest.add 'db.transaction [rollback] [EMPTY]', (test) ->
  test.equal db.transaction().rollback(), undefined

###
@test 
@description Check Neo4jTransaction check empty transaction
db.transaction().commit()
###
Tinytest.add 'db.transaction [commit] [EMPTY]', (test) ->
  test.equal db.transaction().commit(), []

###
@test 
@description Check next tick batch
db.queryAsync(query)
###
Tinytest.addAsync 'Sending multiple async queries inside one Batch on next tick', (test, completed) ->
  conf = [
    'a'
    'b'
    'c'
    'd'
    'e'
    'f'
    'g'
    'h'
  ]

  i = 0
  f = (err, res) ->
    rows = res.fetch()
    for nodeLink in conf
      if _.has rows[0], nodeLink
        __nodeCRC__ test, rows[0][nodeLink], ['TestTickBatch', nodeLink], {foo: nodeLink}

    if ++i is conf.length
      db.queryAsync "MATCH (n:TestTickBatch) DELETE n", ->
        test.equal db.queryOne("MATCH (n:TestTickBatch) RETURN n"), undefined
        completed()

  for name in conf
    db.queryAsync "CREATE (#{name}:TestTickBatch:#{name} {data}) RETURN #{name}", {data: foo: name}, f

###
@test 
@description Check graph
db.graph()
###
Tinytest.addAsync 'db.graph', (test, completed) ->
  db.querySync "CREATE (a:FirstTest)-[r:KNOWS]->(b:SecondTest), (a:FirstTest)-[r2:WorkWith]->(c:ThirdTest), (c:ThirdTest)-[r3:KNOWS]->(b:SecondTest)"
  graph = db.graph "MATCH ()-[r]-() RETURN r"
  test.instanceOf graph, Neo4jCursor
  i = 0
  graph.forEach (n) ->
    i++
    test.isTrue _.has n, 'relationships'
    test.isTrue _.has n, 'nodes'
    test.equal n.nodes.length, 2
    test.equal n.relationships.length, 1
    if i is graph.length
      db.querySync "MATCH (a:FirstTest)-[r:KNOWS]->(b:SecondTest), (a:FirstTest)-[r2:WorkWith]->(c:ThirdTest), (c:ThirdTest)-[r3:KNOWS]->(b:SecondTest) DELETE r, r2, r3"
      db.queryAsync "MATCH (a:FirstTest), (b:SecondTest), (c:ThirdTest) DELETE a, b, c"
      completed()


###
@test 
@description Check batch
db.batch(tasks)
###
Tinytest.add 'db.batch [With custom ID]', (test) ->
  batch = db.batch [
      method: "POST"
      to: db.__service.cypher.endpoint
      body: 
        query: "CREATE (n:BatchTest {data})"
        params: data: BatchTest: true
    ,
      method: "POST"
      to: db.__service.cypher.endpoint
      body: query: "MATCH (n:BatchTest) RETURN n"
      id: 999
    ,
      method: "POST"
      to: db.__service.cypher.endpoint
      body: query: "MATCH (n:BatchTest) DELETE n"]

  test.equal batch.length, 3
  for res in batch
    test.isTrue _.isFunction res.fetch
    test.isTrue _.has res, '_batchId'
    test.isTrue _.has res, 'length'
    if res._batchId is 999
      __nodeCRC__ test, res.fetch()[0].n, ['BatchTest'], {BatchTest: true}

###
@test 
@description Check batch ASYNC
db.batch(tasks, callback)
###
Tinytest.addAsync 'db.batch [With custom ID] [ASYNC]', (test, completed) ->
  db.batch [
      method: "POST"
      to: db.__service.cypher.endpoint
      body: 
        query: "CREATE (n:BatchTestAsync {data})"
        params: data: BatchTestAsync: true
    ,
      method: "POST"
      to: db.__service.cypher.endpoint
      body: query: "MATCH (n:BatchTestAsync) RETURN n"
      id: 999
    ,
      method: "POST"
      to: db.__service.cypher.endpoint
      body: query: "MATCH (n:BatchTestAsync) DELETE n"]
  , 
    (error, batch) ->
      bound ->
        test.equal batch.length, 3
        for res in batch
          test.isTrue _.isFunction res.fetch
          test.isTrue _.has res, '_batchId'
          test.isTrue _.has res, 'length'
          if res._batchId is 999
            __nodeCRC__ test, res.fetch()[0].n, ['BatchTestAsync'], {BatchTestAsync: true}

        completed()

###
@test 
@description Check batch ASYNC
db.batch(tasks, {plain: true}, false, true)
###
Tinytest.add 'db.batch [With custom ID] [no data transform (plain)]', (test) ->
  batch = db.batch [
      method: "POST"
      to: db.__service.cypher.endpoint
      body: 
        query: "CREATE (n:BatchTestPlain {data})"
        params: data: BatchTestPlain: true
    ,
      method: "POST"
      to: db.__service.cypher.endpoint
      body: query: "MATCH (n:BatchTestPlain) RETURN n"
      id: 999
    ,
      method: "POST"
      to: db.__service.cypher.endpoint
      body: query: "MATCH (n:BatchTestPlain) DELETE n"], plain: true

  test.equal batch.length, 3
  for res in batch
    test.isTrue _.has res, '_batchId'
    test.isTrue _.has res, 'data'
    test.isTrue _.has res, 'columns'
    if res._batchId is 999
      test.isTrue !!~res.data[0][0].metadata.labels.indexOf 'BatchTestPlain'
      test.isTrue _.has res.data[0][0].data, 'BatchTestPlain'
      test.equal res.data[0][0].data['BatchTestPlain'], true

###
@test 
@description Check batch ASYNC REACTIVE
db.batch(tasks, {reactive: true}, true)
###
Tinytest.add 'db.batch [With custom ID] [REACTIVE]', (test) ->
  batch = db.batch [
      method: "POST"
      to: db.__service.cypher.endpoint
      body: 
        query: "CREATE (n:BatchTestReactive {data})"
        params: data: BatchTestReactive: true
    ,
      method: "POST"
      to: db.__service.cypher.endpoint
      body: query: "MATCH (n:BatchTestReactive) RETURN n"
      id: 999], reactive: true

  test.equal batch.length, 2
  for res in batch
    test.isTrue _.isFunction res.fetch
    test.isTrue _.has res, '_batchId'
    test.isTrue _.has res, 'length'
    if res._batchId is 999
      node = res.fetch()[0]
      __nodeCRC__ test, node.n, ['BatchTestReactive'], {BatchTestReactive: true}

      db.querySync "MATCH n WHERE id(n) = {id} SET n.newProp = 'rrrreactive!'", {id: node.n.id}

      node = res.fetch()[0]
      __nodeCRC__ test, node.n, ["BatchTestReactive"], {BatchTestReactive: true, newProp: 'rrrreactive!'}

      db.batch [
        method: "POST"
        to: db.__service.cypher.endpoint
        body: query: "MATCH (n:BatchTestReactive) DELETE n"], -> return

###
@test 
@description Check nodes creation / deletion
db.nodes(props)
###
Tinytest.add 'db.nodes create / delete', (test) ->
  node = db.nodes()
  _id = node.get().id
  
  __nodesInstanceCRC__ test, node
  __nodeCRC__ test, node.get(), [], {}

  _node = db.queryOne "MATCH n WHERE id(n) = {id} RETURN n", {id: _id}
  __nodeCRC__ test, _node.n, [], {}

  test.equal node.delete(), undefined
  test.equal node._node, undefined
  test.equal node.get(), undefined
  test.equal db.queryOne("MATCH n WHERE id(n) = {id} RETURN n", {id: _id}) , undefined

###
@test 
@description Check nodes creation / deletion
db.nodes(props)
###
Tinytest.add 'db.nodes create / delete (2nd way)', (test) ->
  node = db.nodes({testNodes: true})
  _id = node.get().id
  
  __nodesInstanceCRC__ test, node
  __nodeCRC__ test, node.get(), [], {testNodes: true}

  _node = db.queryOne "MATCH n WHERE id(n) = {id} RETURN n", {id: _id}
  __nodeCRC__ test, _node.n, [], {testNodes: true}

  test.equal node.delete(), undefined
  test.equal node._node, undefined
  test.equal node.get(), undefined
  test.equal db.queryOne("MATCH n WHERE id(n) = {id} RETURN n", {id: _id}) , undefined

###
@test 
@description Check nodes creation / setProperty / deletion
db.nodes(props).setProperty(name, val)
###
Tinytest.add 'db.nodes create / setProperty / delete', (test) ->
  node = db.nodes({testNodes: true})
  _id = node.get().id
  
  __nodesInstanceCRC__ test, node
  __nodeCRC__ test, node.get(), [], {testNodes: true}

  _node = db.queryOne "MATCH n WHERE id(n) = {id} RETURN n", {id: _id}
  __nodeCRC__ test, _node.n, [], {testNodes: true}

  node.setProperty 'newProp', 'newPropValue'

  __nodesInstanceCRC__ test, node
  __nodeCRC__ test, node.get(), [], {testNodes: true, newProp: 'newPropValue'}

  _node = db.queryOne "MATCH n WHERE id(n) = {id} RETURN n", {id: _id}
  __nodeCRC__ test, _node.n, [], {testNodes: true, newProp: 'newPropValue'}

  test.equal node.delete(), undefined
  test.equal node._node, undefined
  test.equal node.get(), undefined
  test.equal db.queryOne("MATCH n WHERE id(n) = {id} RETURN n", {id: _id}) , undefined

###
@test 
@description Check nodes creation / setProperty / deletion
db.nodes(props).setProperty({name: val})
###
Tinytest.add 'db.nodes create / setProperty (from obj) / delete', (test) ->
  node = db.nodes({testNodes2: 'true'})
  _id = node.get().id
  
  __nodesInstanceCRC__ test, node
  __nodeCRC__ test, node.get(), [], {testNodes2: 'true'}

  _node = db.queryOne "MATCH n WHERE id(n) = {id} RETURN n", {id: _id}
  __nodeCRC__ test, _node.n, [], {testNodes2: 'true'}

  node.setProperty {newProp2: 'newPropValue2'}

  __nodesInstanceCRC__ test, node
  __nodeCRC__ test, node.get(), [], {testNodes2: 'true', newProp2: 'newPropValue2'}

  _node = db.queryOne "MATCH n WHERE id(n) = {id} RETURN n", {id: _id}
  __nodeCRC__ test, _node.n, [], {testNodes2: 'true', newProp2: 'newPropValue2'}

  test.equal node.delete(), undefined
  test.equal node._node, undefined
  test.equal node.get(), undefined
  test.equal db.queryOne("MATCH n WHERE id(n) = {id} RETURN n", {id: _id}) , undefined

###
@test 
@description Check nodes creation / setProperty / deletion
db.nodes(props).updateProperties({name: val, name2: val2})
###
Tinytest.add 'db.nodes create / updateProperties / delete', (test) ->
  node = db.nodes({testNodes3: 'updateProperties', testNodes4: 'updateProperties2'})
  _id = node.get().id

  __nodesInstanceCRC__ test, node
  __nodeCRC__ test, node.get(), [], {testNodes3: 'updateProperties', testNodes4: 'updateProperties2'}

  _node = db.queryOne "MATCH n WHERE id(n) = {id} RETURN n", {id: _id}
  __nodeCRC__ test, _node.n, [], {testNodes3: 'updateProperties', testNodes4: 'updateProperties2'}

  node.updateProperties {testNodes3: 'Other val', testNodes4: 'Other val 2'}

  __nodesInstanceCRC__ test, node
  __nodeCRC__ test, node.get(), [], {testNodes3: 'Other val', testNodes4: 'Other val 2'}

  _node = db.queryOne "MATCH n WHERE id(n) = {id} RETURN n", {id: _id}
  __nodeCRC__ test, _node.n, [], {testNodes3: 'Other val', testNodes4: 'Other val 2'}

  test.equal node.delete(), undefined
  test.equal node._node, undefined
  test.equal node.get(), undefined
  test.equal db.queryOne("MATCH n WHERE id(n) = {id} RETURN n", {id: _id}) , undefined

###
@test 
@description Check nodes creation / setProperty / deletion
Expect to delete or override old props, and create new
db.nodes(props).updateProperties({name: val, name2: val2})
###
Tinytest.add 'db.nodes create / updateProperties (not previously defined) / delete', (test) ->
  node = db.nodes({testNodes3: 'updateProperties', testNodes4: 'updateProperties2'})
  _id = node.get().id

  __nodesInstanceCRC__ test, node
  __nodeCRC__ test, node.get(), [], {testNodes3: 'updateProperties', testNodes4: 'updateProperties2'}

  _node = db.queryOne "MATCH n WHERE id(n) = {id} RETURN n", {id: _id}
  __nodeCRC__ test, _node.n, [], {testNodes3: 'updateProperties', testNodes4: 'updateProperties2'}

  node.updateProperties {testNodes7: 'Other val 4', testNodes8: 'Other val 5'}

  __nodesInstanceCRC__ test, node
  __nodeCRC__ test, node.get(), [], {testNodes7: 'Other val 4', testNodes8: 'Other val 5'}

  _node = db.queryOne "MATCH n WHERE id(n) = {id} RETURN n", {id: _id}
  __nodeCRC__ test, _node.n, [], {testNodes7: 'Other val 4', testNodes8: 'Other val 5'}

  test.isTrue EJSON.equals node.properties(), {testNodes7: 'Other val 4', testNodes8: 'Other val 5'}

  test.equal node.delete(), undefined
  test.equal node._node, undefined
  test.equal node.get(), undefined
  test.equal db.queryOne("MATCH n WHERE id(n) = {id} RETURN n", {id: _id}) , undefined

###
@test 
@description Check nodes creation / setProperties / deletion
db.nodes(props).setProperties({name: val, name2: val2})
###
Tinytest.add 'db.nodes create / setProperties / delete', (test) ->
  node = db.nodes({one: 1})
  _id = node.get().id
  
  __nodesInstanceCRC__ test, node
  __nodeCRC__ test, node.get(), [], {one: 1}

  _node = db.queryOne "MATCH n WHERE id(n) = {id} RETURN n", {id: _id}
  __nodeCRC__ test, _node.n, [], {one: 1}

  node.setProperties {three: 3, four: 4}

  __nodesInstanceCRC__ test, node
  __nodeCRC__ test, node.get(), [], {one: 1, three: 3, four: 4}

  _node = db.queryOne "MATCH n WHERE id(n) = {id} RETURN n", {id: _id}
  __nodeCRC__ test, _node.n, [], {one: 1, three: 3, four: 4}

  test.isTrue EJSON.equals node.properties(), {one: 1, three: 3, four: 4}

  test.equal node.delete(), undefined
  test.equal node._node, undefined
  test.equal node.get(), undefined
  test.equal db.queryOne("MATCH n WHERE id(n) = {id} RETURN n", {id: _id}) , undefined

###
@test 
@description Check nodes creation / property / deletion
db.nodes(props).property(name)
###
Tinytest.add 'db.nodes create / property [GET] / delete', (test) ->
  node = db.nodes({one: 1, two: 2})
  test.equal node.property('two'), 2
  test.equal node.delete(), undefined
  test.equal node.get(), undefined

###
@test 
@description Check nodes creation / property / deletion
db.nodes(props).property(name, value).property(name)
###
Tinytest.add 'db.nodes create / property [SET] / delete', (test) ->
  node = db.nodes({one: 1, two: 2})
  __nodesInstanceCRC__ test, node

  _id = node.get().id
  test.equal node.property('three', 3).property('three'), 3

  _node = db.queryOne "MATCH n WHERE id(n) = {id} RETURN n", {id: _id}
  __nodeCRC__ test, _node.n, [], {one: 1, two: 2, three: 3}
  test.equal node.delete(), undefined
  test.equal node.get(), undefined

###
@test 
@description Check nodes creation / property / deletion
db.nodes(props).property(name, value).property(name)
###
Tinytest.add 'db.nodes create / property [UPDATE] / delete', (test) ->
  node = db.nodes({one: 1, two: 2})
  __nodesInstanceCRC__ test, node

  _id = node.get().id
  test.equal node.property('two', 3).property('two'), 3

  _node = db.queryOne "MATCH n WHERE id(n) = {id} RETURN n", {id: _id}
  __nodeCRC__ test, _node.n, [], {one: 1, two: 3}
  test.equal node.delete(), undefined
  test.equal node.get(), undefined

###
@test 
@description Check nodes creation / getProperty / deletion
db.nodes(props).getProperty(name)
###
Tinytest.add 'db.nodes create / getProperty / delete', (test) ->
  node = db.nodes({one: 1, two: 2})
  __nodesInstanceCRC__ test, node

  test.equal node.getProperty('two'), 2
  test.equal node.delete(), undefined
  test.equal node.get(), undefined

###
@test 
@description Check nodes creation / deletion
db.nodes({node returned from Neo4j}).delete()
###
Tinytest.add 'db.nodes initiate from obj / delete', (test) ->
  task = 
    method: 'POST'
    to: db.__service.cypher.endpoint
    body:
      query: "CREATE (n {data}) RETURN n"
      params: data: test: true
  _node = db.__batch task, undefined, false, true

  node = db.nodes(_node.data[0][0])
  __nodesInstanceCRC__ test, node
  __nodeCRC__ test, node.get(), [], {test: true}
  test.equal node.delete(), undefined
  test.equal node.get(), undefined

###
@test 
@description Check nodes creation / deletion
db.nodes({node ID}).delete()
###
Tinytest.add 'db.nodes initiate by id / delete', (test) ->
  task = 
    method: 'POST'
    to: db.__service.cypher.endpoint
    body:
      query: "CREATE (n {data}) RETURN n"
      params: data: second: '2nd'
  _node = db.__batch task, undefined, false, true
  
  node = db.nodes(_node.data[0][0].metadata.id)
  __nodeCRC__ test, node.get(), [], {second: '2nd'}
  test.equal node.delete(), undefined
  test.equal node.get(), undefined


###
@test 
@description Check nodes creation / deletion
db.nodes({node returned from Neo4j}, true).delete(name)
###
Tinytest.add 'db.nodes initiate from obj / delete [REACTIVE]', (test) ->
  task = 
    method: 'POST'
    to: db.__service.cypher.endpoint
    body:
      query: "CREATE (n {data}) RETURN n"
      params: data: test: true
  _node = db.__batch task, undefined, false, true

  node = db.nodes(_node.data[0][0], true)
  __nodesInstanceCRC__ test, node
  __nodeCRC__ test, node.get(), [], {test: true}

  db.querySync "MATCH n WHERE id(n) = {id} SET n.newProp = 'rrrrreactive!'", {id: _node.data[0][0].metadata.id}
  __nodeCRC__ test, node.get(), [], {test: true, newProp: 'rrrrreactive!'}
  test.equal node.delete(), undefined
  test.equal node.get(), undefined

###
@test 
@description Check nodes creation / deletion
db.nodes({node ID}, true).delete(name)
###
Tinytest.add 'db.nodes initiate by id / delete [REACTIVE]', (test) ->
  task = 
    method: 'POST'
    to: db.__service.cypher.endpoint
    body:
      query: "CREATE (n {data}) RETURN n"
      params: data: test: true
  _node = db.__batch task, undefined, false, true

  node = db.nodes(_node.data[0][0].metadata.id, true)
  __nodesInstanceCRC__ test, node
  __nodeCRC__ test, node.get(), [], {test: true}

  db.querySync "MATCH n WHERE id(n) = {id} SET n.newProp = 'rrrrreactive!'", {id: _node.data[0][0].metadata.id}
  __nodeCRC__ test, node.get(), [], {test: true, newProp: 'rrrrreactive!'}
  test.equal node.delete(), undefined
  test.equal node.get(), undefined

###
@test 
@description Check functionality of Neo4jCursor
###
Tinytest.add 'Neo4jCursor = db.query(...)', (test) ->
  db.transaction().commit([
    "CREATE (n:Neo4jCursorTests {data1}) RETURN n"
    "CREATE (n:Neo4jCursorTests {data2}) RETURN n"
    "CREATE (n:Neo4jCursorTests {data3}) RETURN n"
  ], 
    {
      data1: testing1: 'Neo4jCursorTests1'
      data2: testing2: 'Neo4jCursorTests2'
      data3: testing3: 'Neo4jCursorTests3'
    })

  cursor = db.query "MATCH (n:Neo4jCursorTests) RETURN n"

  test.isTrue _.isObject(cursor.cursor), "Has cursor"
  test.isTrue _.has(cursor, 'length'), "Has length"
  test.equal cursor.length, 3

  test.isTrue _.has(cursor, '_current'), "Has _current"
  test.equal cursor._current, 0

  test.isTrue _.has(cursor, 'hasNext'), "Has hasNext"
  test.equal cursor.hasNext, true

  test.isTrue _.has(cursor, 'hasPrevious'), "Has hasPrevious"
  test.equal cursor.hasPrevious, false

  test.isTrue _.isFunction(cursor.fetch), "Has fetch"
  test.isTrue _.isFunction(cursor.first), "Has first"
  test.isTrue _.isFunction(cursor.current), "Has current"
  test.isTrue _.isFunction(cursor.next), "Has next"
  test.isTrue _.isFunction(cursor.previous), "Has previous"
  test.isTrue _.isFunction(cursor.toMongo), "Has toMongo"
  test.isTrue _.isFunction(cursor.each), "Has each"
  test.isTrue _.isFunction(cursor.forEach), "Has forEach"

  _.each cursor.fetch(), (node, num) ->
    obj = {}
    obj["testing#{num + 1}"] = "Neo4jCursorTests#{ num + 1 }"
    __nodeCRC__ test, node.n, ["Neo4jCursorTests"], obj

  cursor.forEach (node, num) ->
    obj = {}
    obj["testing#{num + 1}"] = "Neo4jCursorTests#{ num + 1 }"
    __nodeCRC__ test, node.n, ["Neo4jCursorTests"], obj

  cursor.each (node, num) ->
    __nodesInstanceCRC__ test, node.n
    obj = {}
    obj["testing#{num + 1}"] = "Neo4jCursorTests#{ num + 1 }"
    __nodeCRC__ test, node.n.get(), ["Neo4jCursorTests"], obj

  cursor.each (node, num) ->
    test.equal node.n.delete(), undefined

###
@test 
@description Check nodes creation / getProperty / deletion
db.queryOne("...").nodeLink.delete()
###
Tinytest.add 'db.nodes test returned node instance from db.queryOne / delete', (test) ->
  cursor = db.query "CREATE (n:NodesTests {data}) RETURN n", {data: testing: 'NodesTests'}

  test.equal cursor.length, 1

  node = cursor.current().n
  __nodesInstanceCRC__ test, node
  __nodeCRC__ test, node.get(), ["NodesTests"], {testing: 'NodesTests'}

  test.equal node.delete(), undefined

###
@test 
@description Check nodes fetching / deletion
db.query("...").current().nodeLink.delete()
###
Tinytest.add 'db.nodes test returned node instance from db.queryOne / delete [REACTIVE]', (test) ->
  cursor = db.query 
    query: "CREATE (n:NodesTestsReactive {data}) RETURN n"
    opts: data: testingReactive: 'some data'
    reactive: true

  test.equal cursor.length, 1

  node = cursor.current().n
  __nodesInstanceCRC__ test, node
  __nodeCRC__ test, node.get(), ["NodesTestsReactive"], {testingReactive: 'some data'}

  db.querySync "MATCH n WHERE id(n) = {id} SET n.newProp = 'rrrrreactive!'", {id: node.get().id}

  __nodeCRC__ test, node.get(), ["NodesTestsReactive"], {testingReactive: 'some data', newProp: 'rrrrreactive!'}

  test.equal node.delete(), undefined


###
@test 
@description Check nodes fetching / setting label / deletion
db.nodes().setLabel('label').delete()
###
Tinytest.add 'db.nodes create / setLabel / delete', (test) ->
  node = db.nodes().setLabel('MyLabel')
  __nodesInstanceCRC__ test, node

  _node = db.queryOne "MATCH n WHERE id(n) = {id} RETURN n", {id: node.get().id}
  __nodeCRC__ test, node.get(), ["MyLabel"], {}
  __nodeCRC__ test, _node.n, ["MyLabel"], {}

  node.delete()

###
@test 
@description Check nodes fetching / setting label / deletion
db.nodes().setLabels(['label', 'label2']).delete()
###
Tinytest.add 'db.nodes create / setLabels / delete', (test) ->
  node = db.nodes().setLabels(['MyLabel', 'MyLabel2'])
  __nodesInstanceCRC__ test, node

  _node = db.queryOne "MATCH n WHERE id(n) = {id} RETURN n", {id: node.get().id}
  __nodeCRC__ test, node.get(), ["MyLabel", "MyLabel2"], {}
  __nodeCRC__ test, _node.n, ["MyLabel", "MyLabel2"], {}
  
  node.delete()

###
@test 
@description Check nodes fetching / setting label / deletion
db.nodes().setLabels(['label', 'label2']).setLabel('label').setLabels(['label', 'label2']).setLabel('label').delete()
###
Tinytest.add 'db.nodes create / setLabels / setLabel / delete', (test) ->
  node = db.nodes().setLabels(['MyLabel', 'MyLabel2']).setLabel('MyLabel3').setLabels(['MyLabel4', 'MyLabel5']).setLabel('MyLabel6')
  __nodesInstanceCRC__ test, node

  _node = db.queryOne "MATCH n WHERE id(n) = {id} RETURN n", {id: node.get().id}
  __nodeCRC__ test, node.get(), ["MyLabel", "MyLabel2", "MyLabel3", "MyLabel4", "MyLabel5", "MyLabel6"], {}
  __nodeCRC__ test, _node.n, ["MyLabel", "MyLabel2", "MyLabel3", "MyLabel4", "MyLabel5", "MyLabel6"], {}
  
  node.delete()

###
@test 
@description Check nodes fetching / setting label / deletion
db.nodes().setLabels(['label', 'label2']).setLabel('label').setLabels(['label', 'label2']).setLabel('label').delete()
###
Tinytest.add 'db.nodes create / setLabels / setLabel / delete [DUPLICATES]', (test) ->
  node = db.nodes().setLabels(['MyLabel', 'MyLabel2']).setLabel('MyLabel').setLabels(['MyLabel2', 'MyLabel5']).setLabel('MyLabel5')
  __nodesInstanceCRC__ test, node

  _node = db.queryOne "MATCH n WHERE id(n) = {id} RETURN n", {id: node.get().id}
  __nodeCRC__ test, node.get(), ["MyLabel", "MyLabel2", "MyLabel5"], {}
  __nodeCRC__ test, _node.n, ["MyLabel", "MyLabel2", "MyLabel5"], {}
  
  node.delete()

###
@test 
@description Check nodes fetching / setting label / deletion
db.nodes().setLabels(['label', 'label2']).setLabel('label').setLabels(['label', 'label2']).setLabel('label').delete()
###
Tinytest.add 'db.nodes create / setLabels / setLabel / delete [Invalid Names]', (test) ->
  node = db.nodes().setLabels(['My Label', '']).setLabel('').setLabel('Label').setLabels(['', ''])
  __nodesInstanceCRC__ test, node

  _node = db.queryOne "MATCH n WHERE id(n) = {id} RETURN n", {id: node.get().id}
  __nodeCRC__ test, node.get(), ["My Label", "Label"], {}
  __nodeCRC__ test, _node.n, ["My Label", "Label"], {}
  
  node.delete()

###
@test 
@description Check nodes fetching / replacing label / deletion
db.nodes().setLabels(['label', 'label2']).replaceLabels(['label']).delete()
###
Tinytest.add 'db.nodes create / replaceLabels / delete', (test) ->
  node = db.nodes().setLabels(['MyLabel1', 'MyLabel2'])
  __nodesInstanceCRC__ test, node

  _node = db.queryOne "MATCH n WHERE id(n) = {id} RETURN n", {id: node.get().id}
  __nodeCRC__ test, node.get(), ["MyLabel1", "MyLabel2"], {}
  __nodeCRC__ test, _node.n, ["MyLabel1", "MyLabel2"], {}

  node.replaceLabels(["MyLabel3"])
  
  _node = db.queryOne "MATCH n WHERE id(n) = {id} RETURN n", {id: node.get().id}
  __nodeCRC__ test, node.get(), ["MyLabel3"], {}
  __nodeCRC__ test, _node.n, ["MyLabel3"], {}

  node.delete()

###
@test 
@description Check nodes fetching / replacing label / deletion
db.nodes().setLabels(['label', 'label2']).replaceLabels(['label']).delete()
###
Tinytest.add 'db.nodes create / replaceLabels / delete [DUPLICATES]', (test) ->
  node = db.nodes().setLabels(['MyLabel1', 'MyLabel2', 'MyLabel1']).setLabel('MyLabel1')
  __nodesInstanceCRC__ test, node

  _node = db.queryOne "MATCH n WHERE id(n) = {id} RETURN n", {id: node.get().id}
  __nodeCRC__ test, node.get(), ["MyLabel1", "MyLabel2",], {}
  __nodeCRC__ test, _node.n, ["MyLabel1", "MyLabel2"], {}

  node.setLabel('MyLabel1').replaceLabels(["MyLabel3", "MyLabel3"]).setLabel("MyLabel3")
  
  _node = db.queryOne "MATCH n WHERE id(n) = {id} RETURN n", {id: node.get().id}
  __nodeCRC__ test, node.get(), ["MyLabel3"], {}
  __nodeCRC__ test, _node.n, ["MyLabel3"], {}

  node.delete()

###
@test 
@description Check nodes fetching / replacing label / deletion
db.nodes().setLabels(['label', 'label2']).replaceLabels(['label']).delete()
###
Tinytest.add 'db.nodes create / replaceLabels / delete [Invalid Names]', (test) ->
  node = db.nodes().setLabels(['MyLabel1', 'MyLabel2', '']).setLabel('').replaceLabels(["", ""])
  __nodesInstanceCRC__ test, node

  _node = db.queryOne "MATCH n WHERE id(n) = {id} RETURN n", {id: node.get().id}
  __nodeCRC__ test, node.get(), ["MyLabel1", "MyLabel2",], {}
  __nodeCRC__ test, _node.n, ["MyLabel1", "MyLabel2"], {}

  node.replaceLabels(["", "MyLabel3"])
  
  _node = db.queryOne "MATCH n WHERE id(n) = {id} RETURN n", {id: node.get().id}
  __nodeCRC__ test, node.get(), ["MyLabel3"], {}
  __nodeCRC__ test, _node.n, ["MyLabel3"], {}

  node.delete()

###
@test 
@description Check nodes fetching / deleting label / deletion
db.nodes().setLabels(['label', 'label2']).deleteLabel('label').delete()
###
Tinytest.add 'db.nodes create / deleteLabel / delete', (test) ->
  node = db.nodes().setLabels(['MyLabel1', 'MyLabel2'])
  __nodesInstanceCRC__ test, node

  _node = db.queryOne "MATCH n WHERE id(n) = {id} RETURN n", {id: node.get().id}
  __nodeCRC__ test, node.get(), ["MyLabel1", "MyLabel2",], {}
  __nodeCRC__ test, _node.n, ["MyLabel1", "MyLabel2"], {}

  node.deleteLabel('MyLabel1')
  
  _node = db.queryOne "MATCH n WHERE id(n) = {id} RETURN n", {id: node.get().id}
  __nodeCRC__ test, node.get(), ["MyLabel2"], {}
  __nodeCRC__ test, _node.n, ["MyLabel2"], {}

  node.delete()

###
@test 
@description Check nodes fetching / deleting label / deletion
db.nodes().setLabels(['label', 'label2']).deleteLabel('label').delete()
###
Tinytest.add 'db.nodes create / deleteLabel / delete [Non Existent]', (test) ->
  node = db.nodes().setLabels(['MyLabel1', 'MyLabel2'])
  __nodesInstanceCRC__ test, node

  _node = db.queryOne "MATCH n WHERE id(n) = {id} RETURN n", {id: node.get().id}
  __nodeCRC__ test, node.get(), ["MyLabel1", "MyLabel2"], {}
  __nodeCRC__ test, _node.n, ["MyLabel1", "MyLabel2"], {}

  node.deleteLabel('MyLabel5')
  
  _node = db.queryOne "MATCH n WHERE id(n) = {id} RETURN n", {id: node.get().id}
  __nodeCRC__ test, node.get(), ["MyLabel1", "MyLabel2"], {}
  __nodeCRC__ test, _node.n, ["MyLabel1", "MyLabel2"], {}

  node.delete()

###
@test 
@description Check nodes fetching / deleting labels / deletion
db.nodes().setLabels(['label', 'label2', 'label3']).deleteLabels(['label', 'label3']).delete()
###
Tinytest.add 'db.nodes create / deleteLabels / delete', (test) ->
  node = db.nodes().setLabels(['MyLabel1', 'MyLabel2', 'MyLabel3'])
  __nodesInstanceCRC__ test, node

  _node = db.queryOne "MATCH n WHERE id(n) = {id} RETURN n", {id: node.get().id}
  __nodeCRC__ test, node.get(), ["MyLabel1", "MyLabel2", "MyLabel3"], {}
  __nodeCRC__ test, _node.n, ["MyLabel1", "MyLabel2", "MyLabel3"], {}

  node.deleteLabels(['MyLabel1', 'MyLabel3'])
  
  _node = db.queryOne "MATCH n WHERE id(n) = {id} RETURN n", {id: node.get().id}
  __nodeCRC__ test, node.get(), ["MyLabel2"], {}
  __nodeCRC__ test, _node.n, ["MyLabel2"], {}

  node.delete()

###
@test 
@description Check nodes fetching / deleting labels / deletion
db.nodes().setLabels(['label', 'label2', 'label3']).deleteLabels(['label5', 'label6']).delete()
###
Tinytest.add 'db.nodes create / deleteLabels / delete [Non Existent]', (test) ->
  node = db.nodes().setLabels(['MyLabel1', 'MyLabel2', 'MyLabel3'])
  __nodesInstanceCRC__ test, node

  _node = db.queryOne "MATCH n WHERE id(n) = {id} RETURN n", {id: node.get().id}
  __nodeCRC__ test, node.get(), ["MyLabel1", "MyLabel2", "MyLabel3"], {}
  __nodeCRC__ test, _node.n, ["MyLabel1", "MyLabel2", "MyLabel3"], {}

  node.deleteLabels(['MyLabel5', 'MyLabel6'])
  
  _node = db.queryOne "MATCH n WHERE id(n) = {id} RETURN n", {id: node.get().id}
  __nodeCRC__ test, node.get(), ["MyLabel1", "MyLabel2", "MyLabel3"], {}
  __nodeCRC__ test, _node.n, ["MyLabel1", "MyLabel2", "MyLabel3"], {}

  node.delete()

###
@test 
@description Check nodes fetching / getting labels / deletion
db.nodes().labels().delete()
###
Tinytest.add 'db.nodes create / labels / delete [GET]', (test) ->
  node = db.nodes().setLabels(['MyLabel1', 'MyLabel2', 'MyLabel3'])
  test.equal node.labels(), ["MyLabel1", "MyLabel2", "MyLabel3"]
  node.delete()

###
@test 
@description Check nodes fetching / getting labels / deletion
db.nodes().labels(['label', 'label2']).labels().delete()
###
Tinytest.add 'db.nodes create / labels / delete [SET / GET]', (test) ->
  node = db.nodes().labels(['MyLabel1', 'MyLabel2', 'MyLabel3'])
  test.equal node.labels(), ["MyLabel1", "MyLabel2", "MyLabel3"]

  _node = db.queryOne "MATCH n WHERE id(n) = {id} RETURN n", {id: node.get().id}
  __nodeCRC__ test, node.get(), ["MyLabel1", "MyLabel2", "MyLabel3"], {}
  __nodeCRC__ test, _node.n, ["MyLabel1", "MyLabel2", "MyLabel3"], {}

  node.delete()

###
@test 
@description Check nodes fetching / getting labels / deletion
db.nodes().labels(['label', 'label2']).labels().delete()
###
Tinytest.add 'db.nodes create / labels / delete [SET / GET] [REACTIVE]', (test) ->
  node = db.nodes(null, true)
  test.equal node.labels(), []

  _node = db.queryOne "MATCH n WHERE id(n) = {id} SET n:MyLabel1 RETURN n", {id: node.get().id}
  test.equal node.labels(), ["MyLabel1"]
  __nodeCRC__ test, node.get(), ["MyLabel1"], {}
  __nodeCRC__ test, _node.n, ["MyLabel1"], {}

  node.delete()



