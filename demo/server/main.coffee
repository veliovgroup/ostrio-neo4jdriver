Meteor.startup ->
  db = new Neo4jDB 'http://localhost:7474', {username: 'neo4j', password: '1234'}

  unless db.queryOne 'MATCH (n) RETURN n LIMIT 1'
    db.querySync 'WITH ["Andres","Wes","Rik","Mark","Peter","Kenny","Michael","Stefan","Max","Chris"] AS names FOREACH (r IN range(0,19) | CREATE (:Person {removed: false, updatedAt: timestamp(), createdAt: timestamp(), name:names[r % size(names)]+" "+r}));'


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
        if row.nodes.length > 0
          for n in row.nodes
            node = 
              id: n.id
              labels: n.labels
              label: n.properties.name
              group: n.labels[0]
            node = _.extend node, n.properties
            nodes[n.id] = node

        if row.relationships.length > 0
          for r in row.relationships
            edge = 
              id: r.id
              from: r.startNode or r.start
              to: r.endNode or r.end
              type: r.type
              label: r.type
              arrows: 'to'
              group: r.type
            edges[r.id] = _.extend edge, r.properties

      visGraph.edges = (value for key, value of edges)
      visGraph.nodes = (value for key, value of nodes)

      return {updatedAt: +new Date, data: visGraph}

    createNode: (form) ->
      check form, Object
      updatedAt = +new Date
      n = db.nodes({description: form.description, name: form.name, createdAt: updatedAt, updatedAt}).replaceLabels([form.label]).get()
      n.label = n.name
      n.group = n.labels[0]
      n

    updateNode: (form) ->
      check form, Object
      form.id = parseInt form.id
      updatedAt = +new Date
      n = db.nodes(form.id).setProperties({description: form.description, name: form.name, updatedAt}).replaceLabels([form.label]).get()
      n.label = n.name
      n.group = n.labels[0]
      n

    deleteNode: (id) ->
      check id, Match.OneOf String, Number
      id = parseInt id

      ###
      First we set node to removed state, so all other clients will remove that node on long-polling
      After 30 seconds we will get rid of the node from Neo4j, if it still exists
      ###
      updatedAt = +new Date
      n = db.nodes(id)
      unless n.property 'removed'
        n.setProperties 
          removed: true
          updatedAt: updatedAt

        Meteor.setTimeout ->
          n = db.nodes(id)
          n.delete() if n?.get?()
        , 30000
      true
      
    createRelationship: (form) ->
      check form, Object
      form.to = parseInt form.to
      form.from = parseInt form.from

      updatedAt = +new Date

      n1 = db.nodes(form.from)
      n2 = db.nodes(form.to)
      n1.setProperty {updatedAt}
      n2.setProperty {updatedAt}

      r = n1.to(n2, form.type, {description: form.description}).get()
      r.from    = r.start
      r.to      = r.end
      r.label   = r.type
      r.group   = r.type
      r.arrows  = 'to'
      r

    updateRelationship: (form) ->
      check form, Object
      form.to = parseInt form.to
      form.from = parseInt form.from
      form.id = parseInt form.id
      
      oldRel = db.getRelation(form.id)
      ###
      If this relationship already marked as removed, then it changed by someone else
      We will just wait for long-polling updates on client
      ###
      updatedAt = +new Date
      unless oldRel.property 'removed'
        oldRel.setProperties
          removed: true
          updatedAt: updatedAt

        Meteor.setTimeout ->
          r = db.getRelation(form.id)
          r.delete() if r?.get?()
        , 30000

        n1 = db.nodes(form.from)
        n2 = db.nodes(form.to)
        n1.setProperty {updatedAt}
        n2.setProperty {updatedAt}

        r = n1.to(n2, form.type, {description: form.description}).get()
        r.from    = r.start
        r.to      = r.end
        r.label   = r.type
        r.group   = r.type
        r.arrows  = 'to'
        r
      else
        true

    deleteRelationship: (id) ->
      check id, Match.OneOf String, Number
      id = parseInt id

      ###
      First we set relationship to removed state, so all other clients will remove that relationship on long-polling
      After 15 seconds we will get rid of the relationship from Neo4j, if it still exists
      ###
      updatedAt = +new Date
      r = db.getRelation(id)
      _r = r.get()
      n1 = db.nodes(_r.start)
      n2 = db.nodes(_r.end)
      n1.setProperty {updatedAt}
      n2.setProperty {updatedAt}

      unless r.property 'removed'
        r.setProperties
          removed: true
          updatedAt: updatedAt

        Meteor.setTimeout ->
          r = db.getRelation(id)
          r.delete() if r?.get?()
        , 15000
      true

