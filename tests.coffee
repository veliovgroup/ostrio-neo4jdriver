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

Tinytest.add 'db.query [SYNC]', (test) -> __SyncTest__ test, 'query'

###
@test 
@description Test standart async query
query: (cypher, opts = {}, callback) ->
###
Tinytest.addAsync 'db.query [Wrong cypher] [ASYNC] (You will see errors at server console)', (test, completed) ->
  db.query "MATCh (n:) RETRN n", (error, data) ->
    test.isTrue _.isString error
    test.isTrue _.isEmpty data.fetch()
    completed()


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

Tinytest.add 'db.transaction [current / rollback]', (test) ->
  t = db.transaction "CREATE (n:TransactionsTesting {data})", data: transaction: true
  current = t.current()
  test.isTrue _.isFunction current[0].fetch
  test.isTrue _.isEmpty current[0].fetch()
  t.rollback()
  test.equal db.queryOne("MATCH (n:TransactionsTesting) RETURN n"), undefined

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

Tinytest.add 'db.transaction [execute multiple / rollback]', (test) ->
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

Tinytest.add 'db.transaction [last]', (test) ->
  t = db.transaction().execute(
    ["CREATE (n:TransactionsTesting {data1})", "CREATE (n:TransactionsTesting2 {data2}) RETURN n"]
  , 
    data1: transaction: true
    data2: transaction2: 'true'
  )

  __nodeCRC__ test, t.last().fetch()[0].n, ['TransactionsTesting2'], {transaction2: 'true'}
  t.rollback()



