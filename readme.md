[![Join the chat at https://gitter.im/VeliovGroup/ostrio-neo4jdriver](https://badges.gitter.im/Join%20Chat.svg)](https://gitter.im/VeliovGroup/ostrio-neo4jdriver?utm_source=badge&utm_medium=badge&utm_campaign=pr-badge&utm_content=badge)

 - __This is server-side only package, to retrieve data from the client use [call(s)](http://docs.meteor.com/#/full/meteor_call) and [methods](http://docs.meteor.com/#/full/meteor_methods)__
 - This package uses [batch operations](http://neo4j.com/docs/2.2.5/rest-api-batch-ops.html) to perform queries, than means if you sending multiple queries to Neo4j in current event loop, all of them will be sent in closest (next) event loop inside of the one batch
 - This package was tested and works like a charm with [GrapheneDB]()
 - Please see demo hosted on [Meteor (Powered by GrapheneDB)]() and on [Heroku]()

See also [Isomorphic Reactive Driver](https://github.com/VeliovGroup/ostrio-Neo4jreactivity).

Install to meteor
=======
```
meteor add ostrio:neo4jdriver
```

API
=======
#### `Neo4jDB([url], [auth])`
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

#### `db.query(cypher, [opts], [callback])`
 - `cypher` {*String*} - Cypher query string
 - `opts` {*Object*} - JSON-able map of cypher query parameters
 - `callback` {*Function*} - Callback with `error` and `result` arguments
If `callback` is passed, the method runs asynchronously, instead of synchronously, and calls asyncCallback.
```coffeescript
db.query "CREATE (n {userData}) RETURN n", userData: username: 'John Black'
```

-----
#### Testing & Dev usage
##### Local usage

 - Download (or clone) to local dir
 - **Stop meteor if running**
 - Run ```mrt link-package [*full path to folder with package*]``` in a project dir
 - Then run ```meteor add ostrio:neo4jdriver```
 - Run ```meteor``` in a project dir
 - From now any changes in ostrio:neo4jdriver package folder will cause rebuilding of project app
