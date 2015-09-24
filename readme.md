[![Join the chat at https://gitter.im/VeliovGroup/ostrio-neo4jdriver](https://badges.gitter.im/Join%20Chat.svg)](https://gitter.im/VeliovGroup/ostrio-neo4jdriver?utm_source=badge&utm_medium=badge&utm_campaign=pr-badge&utm_content=badge)

![Neo4j Driver](https://raw.githubusercontent.com/VeliovGroup/ostrio-Neo4jdriver/dev/logo.png)

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
If you are expecting issue with `fibers` (`Error: Cannot find module 'fibers'`), install version with postfix `-fiber`, like: `ostrio:neo4jdriver@1.0.2-fiber`

Demo Apps
=======
 - Hosted on [Meteor (GrapheneDB)](http://neo4j-graph.meteor.com) and on [Heroku (GrapheneDB Add-on)](http://neo4j-graph.herokuapp.com)
 - Check out it's [source code](https://github.com/VeliovGroup/ostrio-neo4jdriver/tree/master/demo)

API
=======
Please see full API with examples in [neo4j-fiber wiki](https://github.com/VeliovGroup/neo4j-fiber/wiki)

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
