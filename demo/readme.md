Demo app
======
__Links:__
 - __[Meteor hosted](http://neo4j-graph.meteor.com)__
 - __[Heroku hosted](http://neo4j-graph.herokuapp.com)__

__Functionality:__
 - Create / Change / Remove nodes
 - Create / Change / Remove relationships
 - Graph visualization (by [visjs](http://visjs.org/))
 - Latency compensation (on [visjs](http://visjs.org/) level, but we wait for server response)
 - Client synchronization with minimal delay
 - Exception-less conflicts UX-workflow
 - Both examples powered by [GrapheneDB](http://www.graphenedb.com)

Set up Neo4j
======
__Locally:__
 - [Download Neo4j](http://neo4j.com/download/)
 - In Terminal go to downloads folder and type `tar -xf <downloaded filename> -C ~/neo4j/`
 - Start Neo4j: `~/neo4j/bin/neo4j start`
 - Go to [localhost:7474](http://localhost:7474) and set up new credentials
 - Go to `server/main.coffee`, change credentials to your instance of Neo4j
 - [Further reading](http://neo4j.com/docs/stable/server-installation.html)

__GrapheneDB:__
 - Go to [GrapheneDB](http://www.graphenedb.com), create an account and free (or paid) plan DB
 - Get DB's credentials from "DATABASES" > "Connection" tab
 - Go to `server/main.coffee`, change credentials to your instance of Neo4j

__Heroku GrapheneDB Add-on:__
 - From dashboard go to your app
 - On "Resouces" tab type in "Add-ons" section: `graphenedb`
 - Select plan and proceed through further steps
 - Get DB's credentials
 - Go to `server/main.coffee`, change credentials to your instance of Neo4j

Deploy to Meteor
======
 - Set up Neo4j - *see sections above*
 - From Meteor's application directory run:
```shell
meteor deploy <your-app-name>.meteor.com
```

Deploy to Heroku
======
 - Go to [Heroku](https://signup.heroku.com/dc) create and confirm your new account
 - Go though [Node.js Tutorial](https://devcenter.heroku.com/articles/getting-started-with-nodejs)
 - Install [Heroku Toolbet](https://devcenter.heroku.com/articles/getting-started-with-nodejs#set-up)
 - Set up Neo4j - *see sections above*
 - Then go to Terminal into Meteor's project directory and run:
```shell
meteor build ../build-<your-app-name>
cd ../build-<your-app-name>
tar xvzf <name-of-archive> -C ./
cd bundle/
cp -Rf * ../
cd ../
rm -Rf bundle/
rm -Rf <name-of-archive>
git init 
git add .
nano Procfile
web: node main.js
# press ctrl + o
# press Enter (return)
# press ctrl + x
npm init
# go though all steps by pressing Enter (return)
npm install fibers@1.0.7 mailcomposer progress http-proxy sockjs keypress stream-buffers simplesmtp request useragent clean-css uglify-js mongodb handlebars semver mime nib stylus less coffee-script optimist gzippo connect
# Ignore all warnings (but not errors)
heroku create <your-app-name> --buildpack https://github.com/heroku/heroku-buildpack-nodejs
# This command will output something like: https://<your-app-name>.herokuapp.com/ | https://git.heroku.com/<your-app-name>.git
# Copy this: `http://<your-app-name>.herokuapp.com`, note use only `http://` protocol!
heroku config:set ROOT_URL=http://<your-app-name>.herokuapp.com
git commit -m "initial"
git push heroku master
```
 - Go to `http://<your-app-name>.herokuapp.com`
 - If you app has errors:
   * Check logs: `heroku logs --tail`
   * Try to run locally and debug: `heroku run node`