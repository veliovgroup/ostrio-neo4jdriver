[![Join the chat at https://gitter.im/VeliovGroup/ostrio-neo4jdriver](https://badges.gitter.im/Join%20Chat.svg)](https://gitter.im/VeliovGroup/ostrio-neo4jdriver?utm_source=badge&utm_medium=badge&utm_campaign=pr-badge&utm_content=badge)

Most advanced, [well documented](https://github.com/VeliovGroup/neo4j-fiber/wiki) and efficient REST client for Neo4j database, with 100% tests coverage. Fibers and Meteor.js allows to give a new level experience to developers, no more callback-hell and blocking operations. Speed and low resources consumption is top priority of neo4j-fiber package.

![Neo4j Driver](https://raw.githubusercontent.com/VeliovGroup/ostrio-Neo4jdriver/master/logo.min.png)

About
=======
 - __100% tests coverage__
 - Meteor-less NPM version - https://www.npmjs.com/package/neo4j-fiber
 - __This is server-side only package, to retrieve data from the client use [call(s)](http://docs.meteor.com/#/full/meteor_call) and [methods](http://docs.meteor.com/#/full/meteor_methods)__
 - This package uses [batch operations](http://neo4j.com/docs/rest-docs/3.1/#rest-api-batch-ops) to perform queries. Batch operations lets you execute multiple API calls through a single HTTP call. This improves performance for large insert and update operations significantly
 - This package was tested and works like a charm with [GrapheneDB](http://www.graphenedb.com)
 - Please see demo hosted at [Heroku (GrapheneDB Add-on)](http://neo4j-graph.herokuapp.com)
 - To find more about how to use Cypher read [Neo4j cheat-sheet](https://neo4j.com/docs/cypher-refcard/3.1/)

Install to meteor
=======
```
meteor add ostrio:neo4jdriver
```

Import
=======
```js
import { Neo4jDB } from 'meteor/ostrio:neo4jdriver';
// Full list of available classes (for reference):
// import {Neo4jCursor, Neo4jRelationship, Neo4jNode, Neo4jData, Neo4jEndpoint, Neo4jTransaction, Neo4jDB} from 'meteor/ostrio:neo4jdriver';
```

Demo Apps
=======
 - Hosted at [Heroku (GrapheneDB Add-on)](http://neo4j-graph.herokuapp.com)
 - Check out it's [source code](https://github.com/VeliovGroup/neo4j-demo)

API
=======
Please see full API with examples in [neo4j-fiber wiki](https://github.com/VeliovGroup/neo4j-fiber/wiki)

Basic Usage
=======
```js
import { Neo4jDB } from 'meteor/ostrio:neo4jdriver';

const db = new Neo4jDB('http://localhost:7474', {
  username: 'neo4j',
  password: '1234'
});

// Create some data:
const cities = {};
cities['Zürich'] = db.nodes({
  title: 'Zürich',
  lat: 47.27,
  long: 8.31
}).label(['City']);

cities['Tokyo'] = db.nodes({
  title: 'Tokyo',
  lat: 35.40,
  long: 139.45
}).label(['City']);

cities['Athens'] = db.nodes({
  title: 'Athens',
  lat: 37.58,
  long: 23.43
}).label(['City']);

cities['Cape Town'] = db.nodes({
  title: 'Cape Town',
  lat: 33.55,
  long: 18.22
}).label(['City']);


// Add relationship between cities
// At this example we set distance
cities['Zürich'].to(cities['Tokyo'], "DISTANCE", {m: 9576670, km: 9576.67, mi: 5950.67});
cities['Tokyo'].to(cities['Zürich'], "DISTANCE", {m: 9576670, km: 9576.67, mi: 5950.67});

// Create route 1 (Zürich -> Athens -> Cape Town -> Tokyo)
cities['Zürich'].to(cities['Athens'], "ROUTE", {m: 1617270, km: 1617.27, mi: 1004.93, price: 50});
cities['Athens'].to(cities['Cape Town'], "ROUTE", {m: 8015080, km: 8015.08, mi: 4980.34, price: 500});
cities['Cape Town'].to(cities['Tokyo'], "ROUTE", {m: 9505550, km: 9505.55, mi: 5906.48, price: 850});

// Create route 2 (Zürich -> Cape Town -> Tokyo)
cities['Zürich'].to(cities['Cape Town'], "ROUTE", {m: 1617270, km: 1617.27, mi: 1004.93, price: 550});
cities['Cape Town'].to(cities['Tokyo'], "ROUTE", {m: 9576670, km: 9576.67, mi: 5950.67, price: 850});

// Create route 3 (Zürich -> Athens -> Tokyo)
cities['Zürich'].to(cities['Athens'], "ROUTE", {m: 1617270, km: 1617.27, mi: 1004.93, price: 50});
cities['Athens'].to(cities['Tokyo'], "ROUTE", {m: 9576670, km: 9576.67, mi: 5950.67, price: 850});

// Get Shortest Route (in km) between two Cities:
const shortest  = cities['Zürich'].path(cities['Tokyo'], "ROUTE", {cost_property: 'km', algorithm: 'dijkstra'})[0];
let shortestStr = 'Shortest from Zürich to Tokyo, via: ';
shortest.nodes.forEach((id) => {
  shortestStr += db.nodes(id).property('title') + ', ';
});

shortestStr += '| Distance: ' + shortest.weight + ' km';
console.info(shortestStr); // <-- Shortest from Zürich to Tokyo, via: Zürich, Cape Town, Tokyo, | Distance: 11122.82 km

// Get Cheapest Route (in notional currency) between two Cities:
const cheapest  = cities['Zürich'].path(cities['Tokyo'], "ROUTE", {cost_property: 'price', algorithm: 'dijkstra'})[0];
let cheapestStr = 'Cheapest from Zürich to Tokyo, via: ';
cheapest.nodes.forEach((id) => {
  cheapestStr += db.nodes(id).property('title') + ', ';
});

cheapestStr += '| Price: ' + cheapest.weight + ' nc';
console.info(cheapestStr); // <-- Cheapest from Zürich to Tokyo, via: Zürich, Athens, Tokyo, | Price: 900 nc


// Create data via cypher query (as alternative to examples above)
const cursor = db.query('CREATE (n:City {props}) RETURN n', {
  title: 'Ottawa',
  lat: 45.24,
  long: 75.43
});

console.log(cursor.fetch());
// Returns array of nodes:
// [{
//   n: {
//     long: 75.43,
//     lat: 45.24,
//     title: "Ottawa",
//     id: 8421,
//     labels": ["City"],
//     metadata: {
//       id: 8421,
//       labels": ["City"]
//     }
//   }
// }]

// Iterate through results as plain objects:
cursor.forEach((node) => {
  console.log(node)
  // Returns node as Object:
  // {
  //   n: {
  //     long: -75.683333,
  //     lat: 45.416667,
  //     title: "Ottawa",
  //     id: 8421,
  //     labels": ["City"],
  //     metadata: {
  //       id: 8421,
  //       labels": ["City"]
  //     }
  //   }
  // }
});

// Iterate through cursor as `Neo4jNode` instances:
cursor.each((node) => {
  console.log(node.n.get());
  // {
  //   long: -75.683333,
  //   lat: 45.416667,
  //   title: "Ottawa",
  //   id: 8421,
  //   labels": ["City"],
  //   metadata: {
  //     id: 8421,
  //     labels": ["City"]
  //   }
  // }
});
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

From now any changes in ostrio:neo4jdriver package folder will cause your project application to rebuild.


##### To run tests:
*Before running tests - __make sure it's blank Neo4j database with no records!__*
```shell
# Go to local package folder
$ cd packages/ostrio-neo4jdriver
# Edit line 10 of `tests.coffee` to set connection to your Neo4j database
# Default is: 'http://localhost:7474', {username: 'neo4j', password: '1234'}
# Do not forget to run Neo4j database
# Make sure database has no records
$ meteor test-packages ./
```
