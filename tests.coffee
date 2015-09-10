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
db.batch(tasks, undefined, false, true)
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
      body: query: "MATCH (n:BatchTestPlain) DELETE n"], undefined, false, true

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
db.batch(tasks, undefined, true)
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
      id: 999], undefined, true

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



