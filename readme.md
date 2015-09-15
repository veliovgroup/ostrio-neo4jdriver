[![Join the chat at https://gitter.im/VeliovGroup/ostrio-neo4jdriver](https://badges.gitter.im/Join%20Chat.svg)](https://gitter.im/VeliovGroup/ostrio-neo4jdriver?utm_source=badge&utm_medium=badge&utm_campaign=pr-badge&utm_content=badge)

 - __This is server-side only package, to retrieve data from the client use [call(s)](http://docs.meteor.com/#/full/meteor_call) and [methods](http://docs.meteor.com/#/full/meteor_methods)__
 - This package uses [batch operations](http://neo4j.com/docs/2.2.5/rest-api-batch-ops.html) to perform queries, than means if you sending multiple queries to Neo4j in current event loop, all of them will be sent in closest (next) event loop inside of the one batch
 - This package was tested and works like a charm with [GrapheneDB](http://www.graphenedb.com)
 - Please see demo hosted on [Meteor (GrapheneDB)](http://neo4j-graph.meteor.com) and on [Heroku (GrapheneDB Add-on)](http://neo4j-graph.herokuapp.com)
 - To find more about how to use Cypher read [Neo4j cheat sheet](http://neo4j.com/docs/2.2.5/cypher-refcard)

See also [Isomorphic Reactive Driver](https://github.com/VeliovGroup/ostrio-Neo4jreactivity).

Install to meteor
=======
```
meteor add ostrio:neo4jdriver
```

Demo Apps
=======
 - [__Graph, nodes and relationships__](http://neo4j-graph.meteor.com)

API
=======
##### `Neo4jDB([url], [auth])`
 - `url` {*String*} - Absolute URL to Neo4j server, support both `http://` and `https://` protocols
 - `auth` {*Object*} - User credentials
 - `auth.password` {*String*}
 - `auth.username` {*String*}
Create `Neo4jDB` instance and connect to Neo4j
```coffeescript
db = new Neo4jDB 'http://localhost:7474'
, 
  username: 'neo4j'
  password: '1234'
```

##### `db.propertyKeys()`
List all property keys ever used in the database. [Read more](http://neo4j.com/docs/2.2.5/rest-api-property-values.html).

Returns an array of strings



##### `db.labels()`
List all labels ever used in the database. [Read more](http://neo4j.com/docs/2.2.5/rest-api-node-labels.html#rest-api-list-all-labels).

Returns an array of strings



##### `db.relationshipTypes()`
List all relationship types ever used in the database. [Read more](http://neo4j.com/docs/2.2.5/rest-api-relationship-types.html).

Returns an array of strings



##### `db.version()`
Return version of Neo4j server driver connected to.

Returns string, like `2.2.5`




##### `db.query(cypher, [opts], [callback])`
Send query to Neo4j via transactional endpoint. This Transaction will be immediately committed. This transaction will be sent inside batch, so if you call multiple async queries, all of them will be sent in one batch in closest (next) event loop. [Read more](http://neo4j.com/docs/2.2.5/rest-api-transactional.html#rest-api-begin-and-commit-a-transaction-in-one-request).
 - `cypher` {*String*} - Cypher query string
 - `opts` {*Object*} - JSON-able map of cypher query parameters
 - `callback` {*Function*} - Callback with `error` and `result` arguments
 - Returns {*Neo4jCursor*}

If `callback` is passed, the method runs asynchronously, instead of synchronously.
```coffeescript
db.query "CREATE (n {userData}) RETURN n", userData: username: 'John Black'
```




##### `db.queryOne(cypher, [opts])`
Returns first result received from Neo4j
 - `cypher` {*String*} - Cypher query string
 - `opts` {*Object*} - JSON-able map of cypher query parameters
 - Returns {*Object*}

```coffeescript
db.queryOne "CREATE (n {userData}) RETURN n", userData: username: 'John Black'
# Returns node as Object:
# {
#   n: {
#     id: 8421,
#     username: "John Black"
#     metadata: {
#       id: 8421,
#       labels": []
#     }
#   }
# }
```




##### `db.querySync(cypher, [opts])`
Runs alway synchronously
 - `cypher` {*String*} - Cypher query string
 - `opts` {*Object*} - JSON-able map of cypher query parameters
 - Returns {*Neo4jCursor*}

```coffeescript
cursor = db.querySync "CREATE (n {userData}) RETURN n", userData: username: 'John Black'
console.log cursor.fetch()
# Returns array of nodes:
# [{
#   n: {
#     id: 8421,
#     username: "John Black"
#     metadata: {
#       id: 8421,
#       labels": []
#     }
#   }
# }]
```




##### `db.queryAsync(cypher, [opts], [callback])`
Runs alway asynchronously, even if callback is not passed
 - `cypher` {*String*} - Cypher query string
 - `opts` {*Object*} - JSON-able map of cypher query parameters
 - `callback` {*Function*} - Callback with `error` and `result` arguments
 - Returns {*Neo4jCursor*}

```coffeescript
cursor = db.querySync "CREATE (n {userData}) RETURN n", userData: username: 'John Black'
console.log cursor.fetch()
# Returns array of nodes:
# [{
#   n: {
#     id: 8421,
#     username: "John Black"
#     metadata: {
#       id: 8421,
#       labels": []
#     }
#   }
# }]
```




##### `db.graph(cypher, [opts], [callback])`
Send query via to Transactional endpoint and return results as graph representation. [Read more](http://neo4j.com/docs/2.2.5/rest-api-transactional.html#rest-api-return-results-in-graph-format).
 - `cypher` {*String*} - Cypher query string
 - `opts` {*Object*} - JSON-able map of cypher query parameters
 - `callback` {*Function*} - Callback with `error` and `result` arguments
 - Returns {*Neo4jCursor*}

If `callback` is passed, the method runs asynchronously, instead of synchronously.

```coffeescript
cursor = db.graph "MATCH n RETURN n"
# Actually it is shortcut for:
# db.query
#   query: "MATCH n RETURN n"
#   resultDataContents: ["graph"]
console.log cursor.fetch()
# Returns array of arrays nodes and relationships:
# [{nodes: [{...}, {...}, {...}], relationships: [{...}, {...}, {...}]},
#  {nodes: [{...}, {...}, {...}], relationships: [{...}, {...}, {...}]},
#  {nodes: [{...}, {...}, {...}], relationships: [{...}, {...}, {...}]}]
```




##### `db.cypher(cypher, [opts], [callback])`
Send query to Neo4j via cypher endpoint. [Read more](http://neo4j.com/docs/2.2.5/rest-api-cypher.html).
 - `cypher` {*String*} - Cypher query string
 - `opts` {*Object*} - JSON-able map of cypher query parameters
 - `callback` {*Function*} - Callback with `error` and `result` arguments
 - Returns {*Neo4jCursor*}

```coffeescript
cursor = db.cypher "CREATE (n {userData}) RETURN n", userData: username: 'John Black'
console.log cursor.fetch()
# Returns array of nodes:
# [{
#   n: {
#     id: 8421,
#     username: "John Black"
#     metadata: {
#       id: 8421,
#       labels": []
#     }
#   }
# }]
```




##### `db.batch(tasks, [callback], [reactive], [plain])`
Sent tasks to batch endpoint, this method allows to work directly with Neo4j REST API. [Read more](http://neo4j.com/docs/2.2.5/rest-api-batch-ops.html).
  - `tasks` {*[Object]*} - Array of tasks
  - `tasks.$.method` {*String*} - HTTP(S) method used sending this task, one of: 'POST', 'GET', 'PUT', 'DELETE', 'HEAD'
  - `tasks.$.to` {*String*} - Endpoint (URL) for task
  - `tasks.$.id` {*Number*} - [Optional] Unique id to identify task. Should be always unique!
  - `tasks.$.body` {*Object*} - [Optional] JSONable object which will be sent as data to task
  - `callback` {*Function*} - callback function, if present `batch()` method will be called asynchronously
  - `reactive` {*Boolean*} - if `true` and if `plain` is true data of node(s) will be updated before returning
  - `plain` {*Boolean*} - if `true`, results will be returned as simple objects instead of `Neo4jCursor`
  - Returns array of {*[Neo4jCursor]*}s or array of Object id `plain` is `true`

```coffeescript
batch = db.batch [
  method: "POST"
  to: '/cypher'
  body: 
    query: "CREATE (n:MyNode {data})"
    params: data: foo: 'bar'
,
  method: "POST"
  to: '/cypher'
  body: query: "MATCH (n:MyNode) RETURN n"
  id: 999
,
  method: "POST"
  to: '/cypher'
  body: query: "MATCH (n:MyNode) DELETE n"]

for cursor in batch
  if res._batchId is 999
    cursor.fetch()
```




Basic Usage
=======
```coffeescript
db = new Neo4jDB 'http://localhost:7474', {
    username: 'neo4j'
    password: '1234'
  }
  
cursor = db.query 'CREATE (n:City {props}) RETURN n', 
  props: 
    title: 'Ottawa'
    lat: 45.416667
    long: -75.683333

console.log cursor.fetch()
# Returns array of nodes:
# [{
#   n: {
#     long: -75.683333,
#     lat: 45.416667,
#     title: "Ottawa",
#     id: 8421,
#     labels": ["City"],
#     metadata: {
#       id: 8421,
#       labels": ["City"]
#     }
#   }
# }]

# Iterate through results as plain objects:
cursor.forEach (node) ->
  console.log node
  # Returns node as Object:
  # {
  #   n: {
  #     long: -75.683333,
  #     lat: 45.416667,
  #     title: "Ottawa",
  #     id: 8421,
  #     labels": ["City"],
  #     metadata: {
  #       id: 8421,
  #       labels": ["City"]
  #     }
  #   }
  # }

# Iterate through cursor as `Neo4jNode` instances:
cursor.each (node) ->
  console.log node.n.get()
  # {
  #   long: -75.683333,
  #   lat: 45.416667,
  #   title: "Ottawa",
  #   id: 8421,
  #   labels": ["City"],
  #   metadata: {
  #     id: 8421,
  #     labels": ["City"]
  #   }
  # }
```

-----
#### Testing & Dev usage

##### Local usage

To use the ostrio-neo4jdriver in a project and benefit from updates to the driver as they are released, you can keep your project and the driver in separate directories, and create a symlink between them.

```shell
# Stop meteor if it is running
$ cd /directory/of/your/project
# If you don't have a Meteor project yet, create a new one:
$ meteor create MyProject
$ cd MyProject
# Create `packages` directory inside project's dir
$ mkdir packages
$ cd packages
# Clone this repository to a local `packages` directory
$ git clone --bare https://github.com/VeliovGroup/ostrio-neo4jdriver.git
# If you need dev branch, switch into it
$ git checkout dev
# Go back into project's directory
$ cd ../
$ meteor add ostrio:neo4jdriver
# Do not forget to run Neo4j database, before start work with package
```

From now any changes in ostrio:neo4jdriver package folder will cause your project app to rebuild.


##### To run tests:
```shell
# Go to local package folder
$ cd packages/ostrio-neo4jdriver
# Edit first line of `tests.coffee` to set connection to your Neo4j database
# Do not forget to run Neo4j database
$ meteor test-packages ./
```
