Meteor.startup ->
  db = new Neo4jDB 'http://localhost:7474', {username: 'neo4j', password: '1234'}

  unless db.queryOne 'MATCH (n) RETURN n LIMIT 1'
    db.querySync 'WITH ["Andres","Wes","Rik","Mark","Peter","Kenny","Michael","Stefan","Max","Chris"] AS names FOREACH (r IN range(0,19) | CREATE (:Person {updatedAt: timestamp(), createdAt: timestamp(), name:names[r % size(names)]+" "+r}));'


  Meteor.methods
    graph: (timestamp = 0) -> 
      check timestamp, Number
      nodes = []
      edges = []

      visGraph = 
        nodes : []
        edges: []
      graph = db.graph('MATCH (a)-[r]-(b), (n) WHERE n.createdAt >= {timestamp} OR n.updatedAt >= {timestamp} RETURN DISTINCT n, r', {timestamp}).fetch()

      if graph.length is 0
        graph = db.graph('MATCH n WHERE n.createdAt >= {timestamp} OR n.updatedAt >= {timestamp} RETURN DISTINCT n', {timestamp}).fetch()

      for row in graph
        for n in row.nodes
          node = 
            id: n.id
            labels: n.labels
            label: n.properties.name
            group: n.labels[0]
          node = _.extend node, n.properties
          nodes[n.id] = node

        for r in row.relationships
          edge = 
            id: r.id
            from: r.startNode or r.start
            to: r.endNode or r.end
            type: r.type
            label: r.type
            arrows: 'to'
          edges[r.id] = _.extend edge, r.properties

      visGraph.edges = (value for key, value of edges)
      visGraph.nodes = (value for key, value of nodes)

      return visGraph

    createNode: (form) ->
      check form, Object
      n = db.nodes({description: form.description, name: form.name, createdAt: +new Date, updatedAt: +new Date}).replaceLabels([form.label]).get()
      n.label = n.name
      n.group = n.labels[0]
      n

    updateNode: (form) ->
      check form, Object
      form.id = parseInt form.id
      n = db.nodes(form.id).setProperties({description: form.description, name: form.name, updatedAt: +new Date}).replaceLabels([form.label]).get()
      n.label = n.name
      n.group = n.labels[0]
      n

    deleteNode: (id) ->
      check id, Match.OneOf String, Number
      id = parseInt id
      db.nodes(id).delete()
      true
      
    createRelationship: (form) ->
      check form, Object
      form.to = parseInt form.to
      form.from = parseInt form.from
      r = db.nodes(form.from).to(form.to, form.type, {description: form.description}).get()
      r.from    = r.start
      r.to      = r.end
      r.type    = r.type
      r.label   = r.type
      r.arrows  = 'to'
      r

    updateRelationship: (form) ->
      check form, Object
      form.to = parseInt form.to
      form.from = parseInt form.from
      form.id = parseInt form.id
      db.getRelation(form.id).delete()
      r = db.nodes(form.from).to(form.to, form.type, {description: form.description}).get()
      r.from    = r.start
      r.to      = r.end
      r.type    = r.type
      r.label   = r.type
      r.arrows  = 'to'
      r

    deleteRelationship: (id) ->
      check id, Match.OneOf String, Number
      id = parseInt id
      db.getRelation(id).delete()
      true

