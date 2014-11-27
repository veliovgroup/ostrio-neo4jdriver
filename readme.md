Wrapper for [node-neo4j](https://github.com/thingdom/node-neo4j) by [The Thingdom](https://github.com/thingdom) to be used with Meteor apps

### Usage
```
npm install neo4j
```

##### In your code:
```
N4JDB = new Neo4j();

var node = N4JDB.createNode({hello: 'world'});     // instantaneous, but...
node.save(function (err, node) {    // ...this is what actually persists.
    if (err) {
        console.error('Error saving new node to database:', err);
    } else {
        console.log('Node saved to database with id:', node.id);
    }
});
```

**For more info see: [node-neo4j](https://github.com/thingdom/node-neo4j)**
Code licensed under Apache v. 2.0: [node-neo4j License](https://github.com/thingdom/node-neo4j/blob/master/LICENSE) 

-----
#### Testing & Dev usage
##### Local usage

 - Download (or clone) to local dir
 - **Stop meteor if running**
 - Run ```mrt link-package [*full path to folder with package*]``` in a project dir
 - Then run ```meteor add ostrio:neo4jdriver```
 - Run ```meteor``` in a project dir
 - From now any changes in ostrio:neo4jdriver package folder will cause rebuilding of project app
