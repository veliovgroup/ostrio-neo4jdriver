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

###
@test 
@description basics
query: (cypher, opts = {}) ->
###
Tinytest.add 'db.query [BASICS]', (test) ->
  test.isTrue _.isFunction(db.query), 'db.query Exists'
  cursors = []
  cursors.push db.query "CREATE (n:QueryTestBasics {data}) RETURN n", data: foo: 'bar'
  cursors.push db.query "MATCH (n:QueryTestBasics) RETURN n"
  cursors.push db.query 
    query: "MATCH (n:QueryTestBasics {foo: {data}}) RETURN n"
    params: data: 'bar'

  fut = new Future()
  db.query 
    cypher: "MATCH (n:QueryTestBasics {foo: {data}}) RETURN n"
    parameters: data: 'bar'
    cb: (error, cursor) -> fut.return cursor
  cursors.push fut.wait()

  fut = new Future()
  db.query 
    cypher: "MATCH (n:QueryTestBasics {foo: {data}}) RETURN n"
    opts: data: 'bar'
    callback: (error, cursor) -> fut.return cursor
  cursors.push fut.wait()

  for cursor in cursors
    test.isTrue _.isFunction(cursor.fetch), "[query] Returns Neo4jCollection"
    row = cursor.fetch()
    test.equal row.length, 1, "[CREATE | MATCH] [fetch()] Returns only one record"

    test.isTrue _.has row[0], 'n'
    node = row[0].n

    __nodeCRC__ test, node, ['QueryTestBasics'], {foo: 'bar'}

  cursors = []

  cursors.push db.query 
    cypher: "MATCH (n:QueryTestBasics) RETURN n"
    reactive: true
  cursors.push db.query 
    cypher: "MATCH (n:QueryTestBasics) RETURN n"
    reactiveNodes: true

  for cursor in cursors
    test.isTrue _.isFunction cursor._cursor[0].n.get
    test.isTrue _.isFunction cursor._cursor[0].n.update
    test.isTrue _.isFunction cursor._cursor[0].n.__refresh
    test.isTrue cursor._cursor[0].n._isReactive, "Reactive node"

  test.equal db.query("MATCH (n:QueryTestBasics) DELETE n").fetch().length, 0, "[DELETE] [fetch()] Returns empty array"
  row = db.query("MATCH (n:QueryTestBasics) RETURN n").fetch()
  test.equal row.length, 0, "[MATCH] [fetch] [after DELETE] Returns empty array"

###
@test 
@description Test standard query, Synchronous, with replacements
query: (cypher, opts = {}) ->
###
Tinytest.add 'db.query [SYNC]', (test) ->
  cursor = db.query "CREATE (n:QueryTest {data}) RETURN n", data: foo: 'bar'

  test.isTrue _.isFunction(cursor.fetch), "db.query Returns Neo4jCollection"
  row = cursor.fetch()
  test.equal row.length, 1, "[CREATE] [fetch()] Returns only one record"

  test.isTrue _.has row[0], 'n'
  node = row[0].n

  __nodeCRC__ test, node, ['QueryTest'], {foo: 'bar'}

  row = db.query("MATCH (n:QueryTest) RETURN n").fetch()
  test.equal row.length, 1, "[MATCH] [fetch()] Returns only one record"

  test.equal db.query("MATCH (n:QueryTest) DELETE n").fetch().length, 0, "[DELETE] [fetch()] Returns empty array"

  row = db.query("MATCH (n:QueryTest) RETURN n").fetch()
  test.equal row.length, 0, "[MATCH] [fetch] [after DELETE] Returns empty array"

###
@test 
@description Test standart async query
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