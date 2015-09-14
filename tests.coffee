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
  test.isTrue _.isFunction node.deleteProperties
  test.isTrue _.isFunction node.deleteProperty
  test.isTrue _.isFunction node.properties
  test.isTrue _.isFunction node.delete
  test.isTrue _.isFunction node.get
  test.isTrue _.isFunction node.__refresh
  test.isTrue _.isFunction node.update
  test.isTrue _.isFunction node.to
  test.isTrue _.isFunction node.from

__relationCRC__ = (test, r, from, to, type, props = {}) ->
  test.instanceOf r, Neo4jRelationship
  test.isTrue _.isFunction r.get
  test.isTrue _.isFunction r.delete
  test.isTrue _.isFunction r.update
  test.isTrue _.isFunction r.properties
  test.isTrue _.isFunction r.setProperty
  test.isTrue _.isFunction r.setProperties
  test.isTrue _.isFunction r.updateProperties
  test.isTrue _.isFunction r.property
  test.isTrue _.isFunction r.getProperty
  test.isTrue _.isFunction r.deleteProperty
  test.isTrue _.isFunction r.deleteProperties
  test.isTrue _.isFunction r.__refresh

  _r = r.get()
  test.isTrue _.has _r, 'id'
  test.isTrue _.has _r, 'metadata'
  test.isTrue _.has _r, 'type'
  test.isTrue _.has _r, 'start'
  test.isTrue _.has _r, 'end'

  test.isTrue _r.type is type if type

  if props
    for key, value of props
      test.isTrue _.has _r, key
      test.equal _r[key], value

  test.equal _r.start, from if from
  test.equal _r.end, to if to

Tinytest.add 'Neo4jDB - service endpoints - [BASICS]', (test) ->
  test.isTrue _.isArray db.propertyKeys()
  test.isTrue _.isArray db.labels()
  test.isTrue _.isArray db.relationshipTypes()
  test.isTrue _.isString db.version()

###
@test 
@description basics
query: (cypher, opts = {}) ->
###
Tinytest.add 'Neo4jDB - db.query - [BASICS]', (test) -> __BasicsTest__ test, 'query'

###
@test 
@description basics
cypher: (cypher, opts = {}) ->
###
Tinytest.add 'Neo4jDB - db.cypher - [BASICS]', (test) -> __BasicsTest__ test, 'cypher'

###
@test 
@description Test standard query, Synchronous, with replacements
query: (cypher, opts = {}) ->
###
Tinytest.add 'Neo4jDB - db.query - [SYNC]', (test) -> __SyncTest__ test, 'query'

###
@test 
@description Passing wrong Cypher query, returns empty cursor, and prints an error to console
query: (cypher, callback) ->
###
Tinytest.add 'Neo4jDB - db.query - [Wrong cypher] [SYNC] (You will see errors at server console)', (test) ->
  test.equal db.query("MATCh (n:) RETRN n").fetch(), []


###
@test 
@description Passing wrong Cypher query, returns error and prints an error to console
query: (cypher, callback) ->
###
Tinytest.addAsync 'Neo4jDB - db.query - [Wrong cypher] [ASYNC] (You will see errors at server console)', (test, completed) ->
  db.query "MATCh (n:) RETRN n", (error, data) ->
    test.isTrue _.isString error
    test.isTrue _.isEmpty data.fetch()
    completed()

###
@test 
@description Test standard async query
query: (cypher, opts = {}, callback) ->
###
Tinytest.add 'Neo4jDB - db.query - [ASYNC]', (test) ->
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
Tinytest.addAsync 'Neo4jDB - db.query - [ASYNC] [BASICS]', (test, completed) -> __AsyncBasicsTest__ test, completed, 'query'

###
@test 
@description Test cypher basics of async
cypher: (cypher, opts, callback) ->
###
Tinytest.addAsync 'Neo4jDB - db.cypher - [ASYNC] [BASICS]', (test, completed) -> __AsyncBasicsTest__ test, completed, 'cypher'

###
@test 
@description Test queryAsync
queryAsync: (cypher, opts, callback) ->
###
Tinytest.addAsync 'Neo4jDB - db.queryAsync - [with callback]', (test, completed) -> __AsyncBasicsTest__ test, completed, 'queryAsync'

###
@test 
@description Test queryOne
queryOne: (cypher, opts) ->
###
Tinytest.add 'Neo4jDB - db.queryOne - [BASICS]', (test) ->
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
Tinytest.add 'Neo4jDB - db.queryOne - [ForSureNonExists]', (test) ->
  test.equal db.queryOne("MATCH (n:ForSureNonExists) RETURN n"), undefined


###
@test 
@description Test queryAsync
queryAsync: (cypher, opts, callback) ->
###
Tinytest.addAsync 'Neo4jDB - db.queryAsync - [no callback]', (test, completed) ->
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
Tinytest.add 'Neo4jDB - db.querySync - [BASICS]', (test) -> __SyncTest__ test, 'querySync'

###
@test 
@description Test querySync
query: (settings.reactive: true, opts = {}) ->
###
Tinytest.add 'Neo4jDB - db.query - [SYNC] [REACTIVE]', (test) -> __SyncReactiveTest__ test, 'query'

###
@test 
@description Test cypher
cypher: (settings, opts = {}) ->
###
Tinytest.add 'Neo4jDB - db.cypher - [SYNC]', (test) -> __SyncTest__ test, 'cypher'

###
@test 
@description Test cypher reactive nodes
cypher: (settings.reactive: true, opts = {}) ->
###
Tinytest.add 'Neo4jDB - db.cypher - [SYNC] [REACTIVE]', (test) -> __SyncReactiveTest__ test, 'cypher'

###
@test 
@description Check `.transaction` method returns Neo4jTransaction instance, and it has all required methods
db.transaction()
###
Tinytest.add 'Neo4jDB - Neo4jTransaction - initiate (open) [BASICS]', (test) ->
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

Tinytest.add 'Neo4jTransaction - resetTimeout - () (waits for 1 sec to see difference)', (test) ->
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
Tinytest.add 'Neo4jTransaction - current - () [rollback]', (test) ->
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
Tinytest.add 'Neo4jTransaction - execute - (String) [rollback]', (test) ->
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
Tinytest.add 'Neo4jTransaction - execute - (String) [commit]', (test) ->
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
Tinytest.add 'Neo4jTransaction - execute - ([String]) [rollback]', (test) ->
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
Tinytest.add 'Neo4jTransaction - execute - ([String]) [commit]', (test) ->
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
Tinytest.add 'Neo4jTransaction - last - ()', (test) ->
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
Tinytest.addAsync 'Neo4jTransaction - commit - ({Object}) [ASYNC]', (test, completed) ->
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
Tinytest.addAsync 'Neo4jTransaction - commit - ({Callback}) [ASYNC] 2', (test, completed) ->
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
Tinytest.addAsync 'Neo4jTransaction - commit - ({Object}) [ASYNC] [REACTIVE]', (test, completed) ->
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
Tinytest.add 'Neo4jTransaction - rollback - () [EMPTY]', (test) ->
  test.equal db.transaction().rollback(), undefined

###
@test 
@description Check Neo4jTransaction check empty transaction
db.transaction().commit()
###
Tinytest.add 'Neo4jTransaction - commit - () [EMPTY]', (test) ->
  test.equal db.transaction().commit(), []

###
@test 
@description Check next tick batch
db.queryAsync(query)
###
Tinytest.addAsync 'Neo4jDB - core - Sending multiple async queries inside one Batch on next tick', (test, completed) ->
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
Tinytest.addAsync 'Neo4jDB - db.graph - (String) [BASICS]', (test, completed) ->
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
Tinytest.add 'Neo4jDB - db.batch - ([Object]) [With custom ID]', (test) ->
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
Tinytest.addAsync 'Neo4jDB - db.batch - ([Object]) [With custom ID] [ASYNC]', (test, completed) ->
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
Tinytest.add 'Neo4jDB - db.batch - ([Object]) [With custom ID] [no data transform (plain)]', (test) ->
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
Tinytest.add 'Neo4jDB - db.batch - ([Object]) [With custom ID] [REACTIVE]', (test) ->
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
Tinytest.add 'Neo4jNode - create - ()', (test) ->
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
Tinytest.add 'Neo4jNode - create - ({Object})', (test) ->
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
Tinytest.add 'Neo4jNode - setProperty - ()', (test) ->
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
Tinytest.add 'Neo4jNode - setProperty - ({Object})', (test) ->
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
Tinytest.add 'Neo4jNode - updateProperties - ({Object}) [Override]', (test) ->
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
Tinytest.add 'Neo4jNode - updateProperties - ({Object}) [Override and add new]', (test) ->
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
Tinytest.add 'Neo4jNode - setProperties - ({Object})', (test) ->
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
@description Check nodes creation / deleteProperty / deletion
db.nodes(props).deleteProperty(name)
###
Tinytest.add 'Neo4jNode - deleteProperty - (name)', (test) ->
  node = db.nodes({one: 1})
  _id = node.get().id
  
  __nodesInstanceCRC__ test, node
  __nodeCRC__ test, node.get(), [], {one: 1}

  node.deleteProperty 'one'
  test.isUndefined node.get().one

  _node = db.queryOne "MATCH n WHERE id(n) = {id} RETURN n", {id: _id}

  test.isUndefined _node.n.one

  test.equal node.delete(), undefined

###
@test 
@description Check nodes creation / deleteProperty / deletion
db.nodes(props).deleteProperty(name)
###
Tinytest.add 'Neo4jNode - deleteProperty - (name) [non-existent]', (test) ->
  node = db.nodes()
  _id = node.get().id
  
  __nodesInstanceCRC__ test, node
  __nodeCRC__ test, node.get(), [], {}

  node.deleteProperty 'one'
  test.isUndefined node.get().one

  _node = db.queryOne "MATCH n WHERE id(n) = {id} RETURN n", {id: _id}

  test.isUndefined _node.n.one

  test.equal node.delete(), undefined

###
@test 
@description Check nodes creation / deleteProperties / deletion
db.nodes(props).deleteProperties([name, name2])
###
Tinytest.add 'Neo4jNode - deleteProperties - ([String])', (test) ->
  node = db.nodes({one: 1, two: 2})
  _id = node.get().id
  
  __nodesInstanceCRC__ test, node
  __nodeCRC__ test, node.get(), [], {one: 1, two: 2}

  node.deleteProperties ['one', 'two']
  test.isUndefined node.get().one, '[one] removed from instance'
  test.isUndefined node.get().two, '[two] removed from instance'

  _node = db.queryOne "MATCH n WHERE id(n) = {id} RETURN n", {id: _id}

  test.isUndefined _node.n.one, '[one] removed from db'
  test.isUndefined _node.n.two, '[two] removed from db'

  test.equal node.delete(), undefined

###
@test 
@description Check nodes creation / deleteProperties / deletion
db.nodes(props).deleteProperties([name, name2])
###
Tinytest.add 'Neo4jNode - deleteProperties - ([String]) [non-existent]', (test) ->
  node = db.nodes({one: 1, two: 2})
  _id = node.get().id
  
  __nodesInstanceCRC__ test, node
  __nodeCRC__ test, node.get(), [], {one: 1, two: 2}

  node.deleteProperties ['three', 'four']
  test.equal node.get().one, 1
  test.equal node.get().two, 2
  test.isUndefined node.get().three
  test.isUndefined node.get().four

  _node = db.queryOne "MATCH n WHERE id(n) = {id} RETURN n", {id: _id}

  test.equal _node.n.one, 1
  test.equal _node.n.two, 2
  test.isUndefined _node.n.three
  test.isUndefined _node.n.four

  test.equal node.delete(), undefined

###
@test 
@description Check nodes creation / deleteProperties / deletion
db.nodes(props).deleteProperties()
###
Tinytest.add 'Neo4jNode - deleteProperties - () [remove all]', (test) ->
  node = db.nodes({one: 1, two: 2})
  _id = node.get().id
  
  __nodesInstanceCRC__ test, node
  __nodeCRC__ test, node.get(), [], {one: 1, two: 2}

  node.deleteProperties()
  test.isUndefined node.get().one, '[one] removed from instance'
  test.isUndefined node.get().two, '[two] removed from instance'

  _node = db.queryOne "MATCH n WHERE id(n) = {id} RETURN n", {id: _id}

  test.isUndefined _node.n.one, '[one] removed from db'
  test.isUndefined _node.n.two, '[two] removed from db'

  test.equal node.delete(), undefined

###
@test 
@description Check nodes creation / property / deletion
db.nodes(props).property(name)
###
Tinytest.add 'Neo4jNode - property - (name) [GET]', (test) ->
  node = db.nodes({one: 1, two: 2})
  test.equal node.property('two'), 2
  test.equal node.delete(), undefined
  test.equal node.get(), undefined

###
@test 
@description Check nodes creation / property / deletion
db.nodes(props).property(name, value).property(name)
###
Tinytest.add 'Neo4jNode - property - (name, value) [SET]', (test) ->
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
Tinytest.add 'Neo4jNode - property - (name, value) [UPDATE]', (test) ->
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
Tinytest.add 'Neo4jNode - getProperty - (name)', (test) ->
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
Tinytest.add 'Neo4jNode - nodes - ({Object})', (test) ->
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
Tinytest.add 'Neo4jNode - nodes - (id)', (test) ->
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
Tinytest.add 'Neo4jNode - nodes - ({Object}) [REACTIVE]', (test) ->
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
Tinytest.add 'Neo4jNode - nodes - (id) [REACTIVE]', (test) ->
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
Tinytest.add 'Neo4jCursor - [BASICS]', (test) ->
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
@description
db.queryOne("...").nodeLink.delete()
###
Tinytest.add 'Neo4jNode - [BASICS]', (test) ->
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
Tinytest.add 'Neo4jNode - [REACTIVE]', (test) ->
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
Tinytest.add 'Neo4jNode - setLabel - (name)', (test) ->
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
Tinytest.add 'Neo4jNode - setLabels - ([name, name2]) ', (test) ->
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
Tinytest.add 'Neo4jNode - setLabels - ([name, name2]).setLabel(name3)', (test) ->
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
Tinytest.add 'Neo4jNode - setLabels - ([name, name]).setLabel(name) [DUPLICATES]', (test) ->
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
Tinytest.add 'Neo4jNode - setLabels - ([name, ""]).setLabel("") [Invalid Names]', (test) ->
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
Tinytest.add 'Neo4jNode - replaceLabels - ([String])', (test) ->
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
Tinytest.add 'Neo4jNode - replaceLabels - ([String]) [DUPLICATES]', (test) ->
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
Tinytest.add 'Neo4jNode - replaceLabels - ([String]) [Invalid Names]', (test) ->
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
Tinytest.add 'Neo4jNode - deleteLabel - (name)', (test) ->
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
Tinytest.add 'Neo4jNode - deleteLabel - (name) [Non Existent]', (test) ->
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
Tinytest.add 'Neo4jNode - deleteLabels - ([String])', (test) ->
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
Tinytest.add 'Neo4jNode - deleteLabels - ([String]) [Non Existent]', (test) ->
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
Tinytest.add 'Neo4jNode - labels - () [GET]', (test) ->
  node = db.nodes().setLabels(['MyLabel1', 'MyLabel2', 'MyLabel3'])
  test.equal node.labels(), ["MyLabel1", "MyLabel2", "MyLabel3"]
  node.delete()

###
@test 
@description Check nodes fetching / getting labels / deletion
db.nodes().labels(['label', 'label2']).labels().delete()
###
Tinytest.add 'Neo4jNode - labels - ([String]).labels() [SET / GET]', (test) ->
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
Tinytest.add 'Neo4jNode - labels - ([String]).labels() [SET / GET] [REACTIVE]', (test) ->
  node = db.nodes(null, true)
  test.equal node.labels(), []

  _node = db.queryOne "MATCH n WHERE id(n) = {id} SET n:MyLabel1 RETURN n", {id: node.get().id}
  test.equal node.labels(), ["MyLabel1"]
  __nodeCRC__ test, node.get(), ["MyLabel1"], {}
  __nodeCRC__ test, _node.n, ["MyLabel1"], {}

  node.delete()

###
@test 
@description 
db.getRelation(id).delete()
###
Tinytest.add 'Neo4jDB - getRelation - (id)', (test) ->
  r = db.queryOne("CREATE (a)-[r:KNOWS {test: true}]->(b) RETURN r").r
  _r = db.getRelation(r.id)
  __relationCRC__ test, _r, r.start, r.end, 'KNOWS', {test: true}

  test.equal _r.delete(), undefined
  test.equal db.nodes(r.start).delete(), undefined
  test.equal db.nodes(r.end).delete(), undefined

###
@test 
@description 
db.getRelation(id, true).delete()
###
Tinytest.add 'Neo4jDB - getRelation - (id, true) [REACTIVE]', (test) ->
  r = db.queryOne("CREATE (a)-[r:KNOWS {test: true}]->(b) RETURN r").r
  _r = db.getRelation(r.id, true)

  db.querySync "MATCH ()-[r]-() WHERE id(r) = {id} SET r.newProp = 'rrrreactive!'", {id: _r.get().id}

  __relationCRC__ test, _r, r.start, r.end, 'KNOWS', {test: true, newProp: 'rrrreactive!'}

  test.equal _r.delete(), undefined
  test.equal db.nodes(r.start).delete(), undefined
  test.equal db.nodes(r.end).delete(), undefined

###
@test 
@description 
db.createRelation(db.nodes(), db.nodes()).delete()
###
Tinytest.add 'Neo4jDB - createRelation - (from, to, type, {})', (test) ->
  n1 = db.nodes()
  n2 = db.nodes()
  r = db.createRelation n1, n2, 'KNOWS', {test: true}

  __relationCRC__ test, r, n1.get().id, n2.get().id, 'KNOWS', {test: true}
  test.equal r.delete(), undefined
  test.equal n1.delete(), undefined
  test.equal n2.delete(), undefined

###
@test 
@description 
db.createRelation(db.nodes(), db.nodes()).delete()
###
Tinytest.add 'Neo4jDB - createRelation - (from, to, type) [NoProps]', (test) ->
  n1 = db.nodes()
  n2 = db.nodes()
  r = db.createRelation n1, n2, 'KNOWS'

  __relationCRC__ test, r, n1.get().id, n2.get().id, 'KNOWS', {}
  test.equal r.delete(), undefined
  test.equal n1.delete(), undefined
  test.equal n2.delete(), undefined

###
@test 
@description 
db.createRelation(db.nodes(), db.nodes(), {_reactive: true}).delete()
###
Tinytest.add 'Neo4jDB - createRelation - (from, to, type, {_reactive: true}) [REACTIVE]', (test) ->
  n1 = db.nodes()
  n2 = db.nodes()
  r = db.createRelation n1, n2, 'KNOWS', _reactive: true

  test.equal n1.degree(), 1
  test.equal n2.degree(), 1
  db.querySync "MATCH ()-[r]-() WHERE id(r) = {id} SET r.newProp = 'rrrreactive!'", {id: r.get().id}

  __relationCRC__ test, r, n1.get().id, n2.get().id, 'KNOWS', {newProp: 'rrrreactive!'}
  test.equal r.delete(), undefined
  test.equal n1.degree(), 0
  test.equal n2.degree(), 0
  test.equal n1.delete(), undefined
  test.equal n2.delete(), undefined

###
@test 
@description 
db.node().to(node2).delete()
###
Tinytest.add 'Neo4jNode - node.to - (node2, type)', (test) ->
  n1 = db.nodes()
  n2 = db.nodes()
  r = n1.to n2, 'KNOWS', foo: 'bar'

  test.equal n1.degree(), 1
  test.equal n2.degree(), 1

  __relationCRC__ test, r, n1.get().id, n2.get().id, 'KNOWS', {foo: 'bar'}
  test.equal r.delete(), undefined
  test.equal n1.degree(), 0
  test.equal n2.degree(), 0
  test.equal n1.delete(), undefined
  test.equal n2.delete(), undefined

###
@test 
@description 
db.node().from(node2).delete()
###
Tinytest.add 'Neo4jNode - node.from - (node2, type)', (test) ->
  n1 = db.nodes()
  n2 = db.nodes()
  r = n1.from n2, 'KNOWS', foo: 'bar'

  test.equal n1.degree(), 1
  test.equal n2.degree(), 1

  __relationCRC__ test, r, n2.get().id, n1.get().id, 'KNOWS', {foo: 'bar'}
  test.equal r.delete(), undefined
  test.equal n1.degree(), 0
  test.equal n2.degree(), 0
  test.equal n1.delete(), undefined
  test.equal n2.delete(), undefined

###
@test 
@description 
db.node().to(node2).delete()
###
Tinytest.add 'Neo4jNode - node.to - (node2, type, {_reactive: true}) [REACTIVE]', (test) ->
  n1 = db.nodes()
  n2 = db.nodes()
  r = n1.to n2, 'KNOWS', {foo: 'bar', _reactive: true}

  test.equal n1.degree(), 1
  test.equal n2.degree(), 1

  db.querySync "MATCH ()-[r]-() WHERE id(r) = {id} SET r.newProp = 'rrrreactive!'", {id: r.get().id}

  __relationCRC__ test, r, n1.get().id, n2.get().id, 'KNOWS', {foo: 'bar', newProp: 'rrrreactive!'}
  test.equal r.delete(), undefined
  test.equal n1.degree(), 0
  test.equal n2.degree(), 0
  test.equal n1.delete(), undefined
  test.equal n2.delete(), undefined

###
@test 
@description 
db.node().from(node2).delete()
###
Tinytest.add 'Neo4jNode - node.from - (node2, type, {_reactive: true}) [REACTIVE]', (test) ->
  n1 = db.nodes()
  n2 = db.nodes()
  r = n1.from n2, 'KNOWS', {foo: 'bar', _reactive: true}

  test.equal n1.degree(), 1
  test.equal n2.degree(), 1

  db.querySync "MATCH ()-[r]-() WHERE id(r) = {id} SET r.newProp = 'rrrreactive!'", {id: r.get().id}

  __relationCRC__ test, r, n2.get().id, n1.get().id, 'KNOWS', {foo: 'bar', newProp: 'rrrreactive!'}
  test.equal r.delete(), undefined
  test.equal n1.degree(), 0
  test.equal n2.degree(), 0
  test.equal n1.delete(), undefined
  test.equal n2.delete(), undefined

###
@test 
@description Check nodes fetching / getting degree / deletion
db.nodes(id).degree().delete()
###
Tinytest.add 'Neo4jNode - degree()', (test) ->
  n1 = db.nodes()
  n2 = db.nodes()
  n3 = db.nodes()

  r1 = n1.to n2, 'KNOWS'
  r2 = n1.to n3, 'FOLLOWS'
  r3 = n1.to n3, 'LIKES'
  r4 = n3.to n1, 'FOLLOWS'
  r5 = n3.to n1, 'HATES'
  r6 = n2.from n3, 'KNOWS'
  r7 = n2.from n3, 'MATES'
  r8 = n2.from n1, 'MATES'

  __relationCRC__ test, r1, n1.get().id, n2.get().id, 'KNOWS', {}
  __relationCRC__ test, r2, n1.get().id, n3.get().id, 'FOLLOWS', {}
  __relationCRC__ test, r3, n1.get().id, n3.get().id, 'LIKES', {}
  __relationCRC__ test, r4, n3.get().id, n1.get().id, 'FOLLOWS', {}
  __relationCRC__ test, r5, n3.get().id, n1.get().id, 'HATES', {}
  __relationCRC__ test, r6, n3.get().id, n2.get().id, 'KNOWS', {}
  __relationCRC__ test, r7, n3.get().id, n2.get().id, 'MATES', {}
  __relationCRC__ test, r8, n1.get().id, n2.get().id, 'MATES', {}

  test.equal n1.degree(), 6, "n1 [all]"
  test.equal n1.degree('all'), 6, "n1 [all]"
  test.equal n1.degree('out'), 4, "n1 [out]"
  test.equal n1.degree('in'), 2, "n1 [in]"

  test.equal n1.degree('all', ['NotExists']), 0, "n1 [all] [NotExists]"
  test.equal n1.degree('in', ['NotExists', 'NotExists2']), 0, "n1 [in] [NotExists, NotExists2]"
  test.equal n1.degree('out', ['NotExists', 'NotExists2']), 0, "n1 [out] [NotExists, NotExists2]"

  test.equal n1.degree('all', ['KNOWS']), 1, "n1 [all] [KNOWS]"
  test.equal n1.degree('in', ['KNOWS']), 0, "n1 [in] [KNOWS]"
  test.equal n1.degree('out', ['KNOWS']), 1, "n1 [out] [KNOWS]"

  test.equal n1.degree('all', ['KNOWS', 'FOLLOWS']), 3, "n1 [all] [KNOWS, FOLLOWS]"
  test.equal n1.degree('in', ['KNOWS', 'FOLLOWS']), 1, "n1 [in] [KNOWS, FOLLOWS]"
  test.equal n1.degree('out', ['KNOWS', 'FOLLOWS']), 2, "n1 [out] [KNOWS, FOLLOWS]"

  test.equal n1.degree('all', ['KNOWS', 'FOLLOWS', 'LIKES']), 4, "n1 [all] [KNOWS, FOLLOWS, LIKES]"
  test.equal n1.degree('in', ['KNOWS', 'FOLLOWS', 'LIKES']), 1, "n1 [in] [KNOWS, FOLLOWS, LIKES]"
  test.equal n1.degree('out', ['KNOWS', 'FOLLOWS', 'LIKES']), 3, "n1 [out] [KNOWS, FOLLOWS, LIKES]"

  test.equal n1.degree('all', ['KNOWS', 'FOLLOWS', 'LIKES', 'HATES']), 5, "n1 [all] [KNOWS, FOLLOWS, LIKES, HATES]"
  test.equal n1.degree('in', ['KNOWS', 'FOLLOWS', 'LIKES', 'HATES']), 2, "n1 [in] [KNOWS, FOLLOWS, LIKES, HATES]"
  test.equal n1.degree('out', ['KNOWS', 'FOLLOWS', 'LIKES', 'HATES']), 3, "n1 [out] [KNOWS, FOLLOWS, LIKES, HATES]"

  test.equal n1.degree('all', ['KNOWS', 'FOLLOWS', 'LIKES', 'HATES', 'MATES']), 6, "n1 [all] [KNOWS, FOLLOWS, LIKES, HATES, MATES]"
  test.equal n1.degree('in', ['KNOWS', 'FOLLOWS', 'LIKES', 'HATES', 'MATES']), 2, "n1 [in] [KNOWS, FOLLOWS, LIKES, HATES, MATES]"
  test.equal n1.degree('out', ['KNOWS', 'FOLLOWS', 'LIKES', 'HATES', 'MATES']), 4, "n1 [out] [KNOWS, FOLLOWS, LIKES, HATES, MATES]"




  test.equal n2.degree(), 4, "n2 [all]"
  test.equal n2.degree('all'), 4, "n2 [all]"
  test.equal n2.degree('out'), 0, "n2 [out]"
  test.equal n2.degree('in'), 4, "n2 [in]"

  test.equal n2.degree('all', ['NotExists']), 0, "n2 [all] [NotExists]"
  test.equal n2.degree('in', ['NotExists', 'NotExists2']), 0, "n2 [in] [NotExists, NotExists2]"
  test.equal n2.degree('out', ['NotExists', 'NotExists2']), 0, "n2 [out] [NotExists, NotExists2]"

  test.equal n2.degree('all', ['KNOWS']), 2, "n2 [all] [KNOWS]"
  test.equal n2.degree('in', ['KNOWS']), 2, "n2 [in] [KNOWS]"
  test.equal n2.degree('out', ['KNOWS']), 0, "n2 [out] [KNOWS]"

  test.equal n2.degree('all', ['KNOWS', 'FOLLOWS']), 2, "n2 [all] [KNOWS, FOLLOWS]"
  test.equal n2.degree('in', ['KNOWS', 'FOLLOWS']), 2, "n2 [in] [KNOWS, FOLLOWS]"
  test.equal n2.degree('out', ['KNOWS', 'FOLLOWS']), 0, "n2 [out] [KNOWS, FOLLOWS]"

  test.equal n2.degree('all', ['KNOWS', 'FOLLOWS', 'LIKES']), 2, "n2 [all] [KNOWS, FOLLOWS, LIKES]"
  test.equal n2.degree('in', ['KNOWS', 'FOLLOWS', 'LIKES']), 2, "n2 [in] [KNOWS, FOLLOWS, LIKES]"
  test.equal n2.degree('out', ['KNOWS', 'FOLLOWS', 'LIKES']), 0, "n2 [out] [KNOWS, FOLLOWS, LIKES]"

  test.equal n2.degree('all', ['KNOWS', 'FOLLOWS', 'LIKES', 'HATES']), 2, "n2 [all] [KNOWS, FOLLOWS, LIKES, HATES]"
  test.equal n2.degree('in', ['KNOWS', 'FOLLOWS', 'LIKES', 'HATES']), 2, "n2 [in] [KNOWS, FOLLOWS, LIKES, HATES]"
  test.equal n2.degree('out', ['KNOWS', 'FOLLOWS', 'LIKES', 'HATES']), 0, "n2 [out] [KNOWS, FOLLOWS, LIKES, HATES]"

  test.equal n2.degree('all', ['KNOWS', 'FOLLOWS', 'LIKES', 'HATES', 'MATES']), 4, "n2 [all] [KNOWS, FOLLOWS, LIKES, HATES, MATES]"
  test.equal n2.degree('in', ['KNOWS', 'FOLLOWS', 'LIKES', 'HATES', 'MATES']), 4, "n2 [in] [KNOWS, FOLLOWS, LIKES, HATES, MATES]"
  test.equal n2.degree('out', ['KNOWS', 'FOLLOWS', 'LIKES', 'HATES', 'MATES']), 0, "n2 [out] [KNOWS, FOLLOWS, LIKES, HATES, MATES]"





  test.equal n3.degree(), 6, "n3 all"
  test.equal n3.degree('all'), 6, "n3 all"
  test.equal n3.degree('out'), 4, "n3 out"
  test.equal n3.degree('in'), 2, "n3 in"

  test.equal n3.degree('all', ['NotExists']), 0, "n3 [all] [NotExists]"
  test.equal n3.degree('in', ['NotExists', 'NotExists2']), 0, "n3 [in] [NotExists, NotExists2]"
  test.equal n3.degree('out', ['NotExists', 'NotExists2']), 0, "n3 [out] [NotExists, NotExists2]"
  
  test.equal n3.degree('all', ['NotExists']), 0, "n3 [all] [NotExists]"
  test.equal n3.degree('in', ['NotExists', 'NotExists2']), 0, "n3 [in] [NotExists, NotExists2]"
  test.equal n3.degree('out', ['NotExists', 'NotExists2']), 0, "n3 [out] [NotExists, NotExists2]"

  test.equal n3.degree('all', ['KNOWS']), 1, "n3 [all] [KNOWS]"
  test.equal n3.degree('in', ['KNOWS']), 0, "n3 [in] [KNOWS]"
  test.equal n3.degree('out', ['KNOWS']), 1, "n3 [out] [KNOWS]"

  test.equal n3.degree('all', ['KNOWS', 'FOLLOWS']), 3, "n3 [all] [KNOWS, FOLLOWS]"
  test.equal n3.degree('in', ['KNOWS', 'FOLLOWS']), 1, "n3 [in] [KNOWS, FOLLOWS]"
  test.equal n3.degree('out', ['KNOWS', 'FOLLOWS']), 2, "n3 [out] [KNOWS, FOLLOWS]"

  test.equal n3.degree('all', ['KNOWS', 'FOLLOWS', 'LIKES']), 4, "n3 [all] [KNOWS, FOLLOWS, LIKES]"
  test.equal n3.degree('in', ['KNOWS', 'FOLLOWS', 'LIKES']), 2, "n3 [in] [KNOWS, FOLLOWS, LIKES]"
  test.equal n3.degree('out', ['KNOWS', 'FOLLOWS', 'LIKES']), 2, "n3 [out] [KNOWS, FOLLOWS, LIKES]"

  test.equal n3.degree('all', ['KNOWS', 'FOLLOWS', 'LIKES', 'HATES']), 5, "n3 [all] [KNOWS, FOLLOWS, LIKES, HATES]"
  test.equal n3.degree('in', ['KNOWS', 'FOLLOWS', 'LIKES', 'HATES']), 2, "n3 [in] [KNOWS, FOLLOWS, LIKES, HATES]"
  test.equal n3.degree('out', ['KNOWS', 'FOLLOWS', 'LIKES', 'HATES']), 3, "n3 [out] [KNOWS, FOLLOWS, LIKES, HATES]"

  test.equal n3.degree('all', ['KNOWS', 'FOLLOWS', 'LIKES', 'HATES', 'MATES']), 6, "n3 [all] [KNOWS, FOLLOWS, LIKES, HATES, MATES]"
  test.equal n3.degree('in', ['KNOWS', 'FOLLOWS', 'LIKES', 'HATES', 'MATES']), 2, "n3 [in] [KNOWS, FOLLOWS, LIKES, HATES, MATES]"
  test.equal n3.degree('out', ['KNOWS', 'FOLLOWS', 'LIKES', 'HATES', 'MATES']), 4, "n3 [out] [KNOWS, FOLLOWS, LIKES, HATES, MATES]"

  test.equal r1.delete(), undefined
  test.equal r2.delete(), undefined
  test.equal r3.delete(), undefined
  test.equal r4.delete(), undefined
  test.equal r5.delete(), undefined
  test.equal r6.delete(), undefined
  test.equal r7.delete(), undefined
  test.equal r8.delete(), undefined
  test.equal n1.delete(), undefined
  test.equal n2.delete(), undefined
  test.equal n3.delete(), undefined

###
@test 
@description 
db.node().relationships()
###
Tinytest.add 'Neo4jNode - relationships - ()', (test) ->
  n1 = db.nodes()
  n2 = db.nodes()
  r1 = n1.to n2, 'LIKES', tests: 'yes'
  r2 = n2.to n1, 'KNOWS'

  __relationCRC__ test, r1, n1.get().id, n2.get().id, 'LIKES', {tests: 'yes'}
  __relationCRC__ test, r2, n2.get().id, n1.get().id, 'KNOWS', {}

  cursor1 = n1.relationships()
  cursor2 = n2.relationships()

  test.instanceOf cursor1, Neo4jCursor
  test.instanceOf cursor2, Neo4jCursor

  cursor1.each (relation) -> __relationCRC__ test, relation
  cursor2.each (relation) -> __relationCRC__ test, relation

  r1.delete()
  r2.delete()
  n1.delete()
  n2.delete()

###
@test 
@description 
db.node().relationships("in|out|all", [types])
###
Tinytest.add 'Neo4jNode - relationships - ("in|out|all", [types])', (test) ->
  n1 = db.nodes()
  n2 = db.nodes()
  r1 = n1.to n2, 'LIKES', tests: 'yes'
  r2 = n2.to n1, 'KNOWS'
  
  __relationCRC__ test, r1, n1.get().id, n2.get().id, 'LIKES', {tests: 'yes'}
  __relationCRC__ test, r2, n2.get().id, n1.get().id, 'KNOWS', {}

  cursor1 = n1.relationships('out')
  cursor2 = n2.relationships('in')

  test.instanceOf cursor1, Neo4jCursor
  test.instanceOf cursor2, Neo4jCursor

  cursor1.each (relation) -> __relationCRC__ test, relation, n1.get().id, n2.get().id, 'LIKES', {tests: 'yes'}
  cursor2.each (relation) -> __relationCRC__ test, relation, n1.get().id, n2.get().id, 'LIKES', {tests: 'yes'}

  cursor1 = n1.relationships('in')
  cursor2 = n2.relationships('out')

  test.instanceOf cursor1, Neo4jCursor
  test.instanceOf cursor2, Neo4jCursor

  cursor1.each (relation) -> __relationCRC__ test, relation, n2.get().id, n1.get().id, 'KNOWS'
  cursor2.each (relation) -> __relationCRC__ test, relation, n2.get().id, n1.get().id, 'KNOWS'

  cursor1 = n1.relationships('all', ['KNOWS'])
  cursor2 = n2.relationships('all', ['LIKES'])

  test.instanceOf cursor1, Neo4jCursor
  test.instanceOf cursor2, Neo4jCursor

  cursor1.each (relation) -> __relationCRC__ test, relation, n2.get().id, n1.get().id, 'KNOWS'
  cursor2.each (relation) -> __relationCRC__ test, relation, n1.get().id, n2.get().id, 'LIKES', {tests: 'yes'}

  r1.delete()
  r2.delete()
  n1.delete()
  n2.delete()


###
@test 
@description 
db.node().relationships("in|out|all", [types], true)
###
Tinytest.add 'Neo4jNode - relationships - ("in|out|all", [types]) [REACTIVE]', (test) ->
  n1 = db.nodes()
  n2 = db.nodes()
  r1 = n1.to n2, 'LIKES', tests: 'yes'
  r2 = n2.to n1, 'KNOWS'
  
  __relationCRC__ test, r1, n1.get().id, n2.get().id, 'LIKES', {tests: 'yes'}
  __relationCRC__ test, r2, n2.get().id, n1.get().id, 'KNOWS', {}

  cursor1 = n1.relationships('out', [], true)
  cursor2 = n2.relationships('in', [], true)

  test.instanceOf cursor1, Neo4jCursor
  test.instanceOf cursor2, Neo4jCursor

  db.transaction([
    "MATCH ()-[r]-() WHERE id(r) = {id1} SET r.newProp1 = 'rrrreactive!'"
    "MATCH ()-[r]-() WHERE id(r) = {id2} SET r.newProp2 = 'rrrreactive!'"]
  , 
    id1: r1.get().id
    id2: r2.get().id
  ).commit()

  cursor1.each (relation) -> __relationCRC__ test, relation, n1.get().id, n2.get().id, 'LIKES', {
    tests: 'yes'
    newProp1: 'rrrreactive!'
  }
  cursor2.each (relation) -> __relationCRC__ test, relation, n1.get().id, n2.get().id, 'LIKES', {
    tests: 'yes'
    newProp1: 'rrrreactive!'
  }

  cursor1 = n1.relationships('in', [], true)
  cursor2 = n2.relationships('out', [], true)

  test.instanceOf cursor1, Neo4jCursor
  test.instanceOf cursor2, Neo4jCursor

  db.transaction([
    "MATCH ()-[r]-() WHERE id(r) = {id1} SET r.newProp3 = 'rrrreactive3!'"
    "MATCH ()-[r]-() WHERE id(r) = {id2} SET r.newProp4 = 'rrrreactive4!'"]
  , 
    id1: r1.get().id
    id2: r2.get().id
  ).commit()

  cursor1.each (relation) -> __relationCRC__ test, relation, n2.get().id, n1.get().id, 'KNOWS', {
    newProp2: 'rrrreactive!'
    newProp4: 'rrrreactive4!'
  }
  cursor2.each (relation) -> __relationCRC__ test, relation, n2.get().id, n1.get().id, 'KNOWS', {
    newProp2: 'rrrreactive!'
    newProp4: 'rrrreactive4!'
  }

  cursor1 = n1.relationships('all', ['KNOWS'], true)
  cursor2 = n2.relationships('all', ['LIKES'], true)

  test.instanceOf cursor1, Neo4jCursor
  test.instanceOf cursor2, Neo4jCursor

  db.transaction([
    "MATCH ()-[r]-() WHERE id(r) = {id1} SET r.newProp5 = 'rrrreactive5!'"
    "MATCH ()-[r]-() WHERE id(r) = {id2} SET r.newProp6 = 'rrrreactive6!'"]
  , 
    id1: r1.get().id
    id2: r2.get().id
  ).commit()

  cursor1.each (relation) -> __relationCRC__ test, relation, n2.get().id, n1.get().id, 'KNOWS', {
    newProp2: 'rrrreactive!'
    newProp4: 'rrrreactive4!'
    newProp6: 'rrrreactive6!'
  }
  cursor2.each (relation) -> __relationCRC__ test, relation, n1.get().id, n2.get().id, 'LIKES', {
    tests: 'yes'
    newProp1: 'rrrreactive!'
    newProp3: 'rrrreactive3!'
    newProp5: 'rrrreactive5!'
  }

  r1.delete()
  r2.delete()
  n1.delete()
  n2.delete()


###
@test 
@description
r.setProperty(name, val)
###
Tinytest.add 'Neo4jRelationship - setProperty - ("name", "value")', (test) ->
  n1 = db.nodes()
  n2 = db.nodes()
  r = n1.to n2, "KNOWS", {testRels: true}
  _id = r.get().id

  r.setProperty 'newProp', 'newPropValue'

  __relationCRC__ test, r, n1.get().id, n2.get().id, "KNOWS", {testRels: true, newProp: 'newPropValue'}

  cursor = db.query "MATCH ()-[r]-() WHERE id(r) = {id} RETURN DISTINCT r", {id: _id}
  cursor.each (relation) -> 
    __relationCRC__ test, relation.r, n1.get().id, n2.get().id, "KNOWS", {testRels: true, newProp: 'newPropValue'}

  test.equal r.delete(), undefined
  test.equal n1.delete(), undefined
  test.equal n2.delete(), undefined

###
@test 
@description
r.setProperty({name: val})
###
Tinytest.add 'Neo4jRelationship - setProperty - ({Object})', (test) ->
  n1 = db.nodes()
  n2 = db.nodes()
  r = n1.to n2, "KNOWS", {testRels: true}
  _id = r.get().id

  r.setProperty {newProp2: 'newPropValue2'}

  __relationCRC__ test, r, n1.get().id, n2.get().id, "KNOWS", {testRels: true, newProp2: 'newPropValue2'}

  cursor = db.query "MATCH ()-[r]-() WHERE id(r) = {id} RETURN DISTINCT r", {id: _id}
  cursor.each (relation) -> 
    __relationCRC__ test, relation.r, n1.get().id, n2.get().id, "KNOWS", {testRels: true, newProp2: 'newPropValue2'}

  test.equal r.delete(), undefined
  test.equal n1.delete(), undefined
  test.equal n2.delete(), undefined

###
@test 
@description Expect to delete or override old props, and create new
r.updateProperties({name: val})
###
Tinytest.add 'Neo4jRelationship - updateProperties - ({Object})', (test) ->
  n1 = db.nodes()
  n2 = db.nodes()
  r = n1.to n2, "KNOWS", {testRels: true}
  _id = r.get().id

  r.updateProperties {newProp1: 'newPropValue1', newProp2: 'newPropValue2'}

  __relationCRC__ test, r, n1.get().id, n2.get().id, "KNOWS", {newProp1: 'newPropValue1', newProp2: 'newPropValue2'}

  cursor = db.query "MATCH ()-[r]-() WHERE id(r) = {id} RETURN DISTINCT r", {id: _id}
  cursor.each (relation) -> 
    __relationCRC__ test, relation.r, n1.get().id, n2.get().id, "KNOWS", {newProp1: 'newPropValue1', newProp2: 'newPropValue2'}

  test.equal r.delete(), undefined
  test.equal n1.delete(), undefined
  test.equal n2.delete(), undefined

###
@test 
@description
r.setProperties({name: val})
###
Tinytest.add 'Neo4jRelationship - setProperties - ({Object})', (test) ->
  n1 = db.nodes()
  n2 = db.nodes()
  r = n1.to n2, "KNOWS", {testRels: true}
  _id = r.get().id

  r.updateProperties {testRels: true, newProp1: 'newPropValue1', newProp2: 'newPropValue2'}

  __relationCRC__ test, r, n1.get().id, n2.get().id, "KNOWS", {testRels: true, newProp1: 'newPropValue1', newProp2: 'newPropValue2'}

  cursor = db.query "MATCH ()-[r]-() WHERE id(r) = {id} RETURN DISTINCT r", {id: _id}
  cursor.each (relation) -> 
    __relationCRC__ test, relation.r, n1.get().id, n2.get().id, "KNOWS", {testRels: true, newProp1: 'newPropValue1', newProp2: 'newPropValue2'}

  test.equal r.delete(), undefined
  test.equal n1.delete(), undefined
  test.equal n2.delete(), undefined

###
@test 
@description
r.property(name)
###
Tinytest.add 'Neo4jRelationship - property - (name) [GET]', (test) ->
  n1 = db.nodes()
  n2 = db.nodes()
  r = n1.to n2, "KNOWS", {testRels: true}

  test.equal r.property('testRels'), true

  test.equal r.delete(), undefined
  test.equal n1.delete(), undefined
  test.equal n2.delete(), undefined

###
@test 
@description
r.property(name)
###
Tinytest.add 'Neo4jRelationship - property - (name, value) [SET]', (test) ->
  n1 = db.nodes()
  n2 = db.nodes()
  r = n1.to n2, "KNOWS", {testRels: true}
  _id = r.get().id

  r.property 'newProp', 'newPropValue'

  __relationCRC__ test, r, n1.get().id, n2.get().id, "KNOWS", {testRels: true, newProp: 'newPropValue'}

  cursor = db.query "MATCH ()-[r]-() WHERE id(r) = {id} RETURN DISTINCT r", {id: _id}
  cursor.each (relation) -> 
    __relationCRC__ test, relation.r, n1.get().id, n2.get().id, "KNOWS", {testRels: true, newProp: 'newPropValue'}

  test.equal r.delete(), undefined
  test.equal n1.delete(), undefined
  test.equal n2.delete(), undefined

###
@test 
r.property(name)
###
Tinytest.add 'Neo4jRelationship - property - (name, value) [UPDATE]', (test) ->
  n1 = db.nodes()
  n2 = db.nodes()
  r = n1.to n2, "KNOWS", {testRels: true}
  _id = r.get().id

  r.property('newProp', 'newPropValue').property('testRels', 'false')

  __relationCRC__ test, r, n1.get().id, n2.get().id, "KNOWS", {testRels: 'false', newProp: 'newPropValue'}

  cursor = db.query "MATCH ()-[r]-() WHERE id(r) = {id} RETURN DISTINCT r", {id: _id}
  cursor.each (relation) -> 
    __relationCRC__ test, relation.r, n1.get().id, n2.get().id, "KNOWS", {testRels: 'false', newProp: 'newPropValue'}

  test.equal r.delete(), undefined
  test.equal n1.delete(), undefined
  test.equal n2.delete(), undefined

###
@test 
@description
r.getProperty(name)
###
Tinytest.add 'Neo4jRelationship - getProperty - (name)', (test) ->
  n1 = db.nodes()
  n2 = db.nodes()
  r = n1.to n2, "KNOWS", {testRels: true}

  test.equal r.getProperty('testRels'), true

  test.equal r.delete(), undefined
  test.equal n1.delete(), undefined
  test.equal n2.delete(), undefined


###
@test 
@description
r = n1.to(n2, type, {_reactive: true})
r.getProperty(name)
###
Tinytest.add 'Neo4jRelationship - getProperty - (name) [REACTIVE]', (test) ->
  n1 = db.nodes()
  n2 = db.nodes()
  r = n1.to n2, "KNOWS", {testRels: true, _reactive: true}
  id = r.get().id

  db.querySync "MATCH ()-[r]-() WHERE id(r) = {id} SET r.testRels = 'rrrreactive5!'", {id}

  test.equal r.getProperty('testRels'), 'rrrreactive5!'

  test.equal r.delete(), undefined
  test.equal n1.delete(), undefined
  test.equal n2.delete(), undefined



###
@test 
@description 
r..deleteProperty(name)
###
Tinytest.add 'Neo4jRelationship - deleteProperty - (name)', (test) ->
  n1 = db.nodes()
  n2 = db.nodes()
  r = n1.to n2, "KNOWS", {testRels: true, testRel2: 2}
  id = r.get().id

  r.deleteProperty 'testRels'

  test.equal r.get().testRels, undefined
  test.equal r.get().testRel2, 2

  _r = db.queryOne("MATCH ()-[r]-() WHERE id(r) = {id} RETURN r", {id}).r

  test.equal _r.testRels, undefined
  test.equal _r.testRel2, 2

  test.equal r.delete(), undefined
  test.equal n1.delete(), undefined
  test.equal n2.delete(), undefined

# ###
# @test 
# @description
# r..deleteProperty(name)
# ###
Tinytest.add 'Neo4jRelationship - deleteProperty - (name) [non-existent]', (test) ->
  n1 = db.nodes()
  n2 = db.nodes()
  r = n1.to n2, "KNOWS", {testRels: true, testRel2: 2}
  id = r.get().id

  r.deleteProperty 'testRel3'

  test.equal r.get().testRels, true
  test.equal r.get().testRel2, 2

  _r = db.queryOne("MATCH ()-[r]-() WHERE id(r) = {id} RETURN r", {id}).r

  test.equal _r.testRels, true
  test.equal _r.testRel2, 2

  test.equal r.delete(), undefined
  test.equal n1.delete(), undefined
  test.equal n2.delete(), undefined

# ###
# @test 
# @description
# r.deleteProperties([name, name2])
# ###
Tinytest.add 'Neo4jRelationship - deleteProperties - ([String])', (test) ->
  n1 = db.nodes()
  n2 = db.nodes()
  r = n1.to n2, "KNOWS", {testRels: true, testRel2: 2, testRel3: '3'}
  id = r.get().id

  r.deleteProperties(['testRel3', 'testRels'])

  test.equal r.get().testRels, undefined
  test.equal r.get().testRel2, 2
  test.equal r.get().testRel3, undefined

  _r = db.queryOne("MATCH ()-[r]-() WHERE id(r) = {id} RETURN r", {id}).r

  test.equal _r.testRels, undefined
  test.equal _r.testRel2, 2
  test.equal _r.testRel3, undefined

  test.equal r.delete(), undefined
  test.equal n1.delete(), undefined
  test.equal n2.delete(), undefined

# ###
# @test 
# @description
# r.deleteProperties([name, name2])
# ###
Tinytest.add 'Neo4jRelationship - deleteProperties - ([String]) [non-existent]', (test) ->
  n1 = db.nodes()
  n2 = db.nodes()
  r = n1.to n2, "KNOWS", {testRels: true, testRel2: 2, testRel3: '3'}
  id = r.get().id

  r.deleteProperties(['testRel5', 'testRel6'])

  test.equal r.get().testRels, true
  test.equal r.get().testRel2, 2
  test.equal r.get().testRel3, '3'

  _r = db.queryOne("MATCH ()-[r]-() WHERE id(r) = {id} RETURN r", {id}).r

  test.equal _r.testRels, true
  test.equal _r.testRel2, 2
  test.equal _r.testRel3, '3'

  test.equal r.delete(), undefined
  test.equal n1.delete(), undefined
  test.equal n2.delete(), undefined

# ###
# @test 
# @description
# r.deleteProperties()
# ###
Tinytest.add 'Neo4jRelationship - deleteProperties - () [remove all]', (test) ->
  n1 = db.nodes()
  n2 = db.nodes()
  r = n1.to n2, "KNOWS", {testRels: true, testRel2: 2, testRel3: '3'}
  id = r.get().id

  r.deleteProperties()

  test.equal r.get().testRels, undefined
  test.equal r.get().testRel2, undefined
  test.equal r.get().testRel3, undefined

  _r = db.queryOne("MATCH ()-[r]-() WHERE id(r) = {id} RETURN r", {id}).r

  test.equal _r.testRels, undefined
  test.equal _r.testRel2, undefined
  test.equal _r.testRel3, undefined

  test.equal r.delete(), undefined
  test.equal n1.delete(), undefined
  test.equal n2.delete(), undefined