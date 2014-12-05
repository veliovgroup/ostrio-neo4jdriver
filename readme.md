Wrapper for [node-neo4j](https://github.com/thingdom/node-neo4j) by [The Thingdom](https://github.com/thingdom) to be used with Meteor apps

On [atmospherejs.com](https://atmospherejs.com/ostrio/neo4jdriver)

### Install to meteor
```
meteor add ostrio:neo4jdriver
```

### Usage
```
npm install neo4j
```

##### In your code:
Create file in ```./server/lib/Neo4jDriver.js```
```javascript
this.N4JDB = new Neo4j(); //From this point N4JDB variable available everywhere in your project
```

Next, just use it.

##### Examples:
```javascript
var node = N4JDB.createNode({hello: 'world'});     // instantaneous, but...
node.save(function (err, node) {    // ...this is what actually persists.
    if (err) {
        console.error('Error saving new node to database:', err);
    } else {
        console.log('Node saved to database with id:', node.id);
    }
});
```

```javascript
/*
 * Create user node with _id
 */
Accounts.onCreateUser(function(options, user) {

    N4JDB.query('CREATE (:User {_id:"' + user._id + '"})', null, function(err, res){
        if(error){
            //handle error here
        }
    });
});
```

```coffeescript
###
This example in coffee
Here we create some group and set our user as it's owner
Next, we add relation :owns from owner to newly created group in one query
###
groupId = GroupsCollection.insert title: 'Some Group Title', (error) ->
    error if error 
        #handle error here

N4JDB.query 'Match (o:User {_id:"' + Meteor.userId() + '"}) ' + 
            'CREATE (g:Group {_id:"' + groupId + '", owner: "' + Meteor.userId() + '", active: true}) ' + 
            'CREATE (o) -[:owns]-> (g)', null, (error, res) ->
    error if error
        #handle error here
```

```coffeescript
###
Register catch all callback
Note - you may register as meny callbacks as you need
@param query {string} - Cypher query
@param opts {object} - A map of parameters for the Cypher query 
###
N4JDB = new Neo4j()
N4JDB.listen (query, opts) ->
    console.log query, opts

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
