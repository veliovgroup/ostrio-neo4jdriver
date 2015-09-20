Meteor.startup ->
  db = new Neo4jDB 'http://localhost:7474', {username: 'neo4j', password: '1234'}

  unless db.queryOne 'MATCH (n) RETURN n LIMIT 1'
    db.querySync 'WITH ["Andres","Wes","Rik","Mark","Peter","Kenny","Michael","Stefan","Max","Chris"] AS names FOREACH (r IN range(0,19) | CREATE (:Person {removed: false, updatedAt: timestamp(), name:names[r % size(names)]+" "+r}));'


  Meteor.methods
    graph: (timestamp = 0) -> 
      check timestamp, Number
      nodes = {}
      edges = {}

      visGraph = 
        nodes : []
        edges: []
      graph = db.query('MATCH (n) WHERE n.updatedAt >= {timestamp} RETURN DISTINCT n UNION ALL MATCH ()-[n]-() WHERE n.updatedAt >= {timestamp} RETURN DISTINCT n', {timestamp}).fetch()

      if graph.length is 0
        updatedAt = timestamp
      else
        updatedAt = +new Date

        for row in graph
          if row?.n
            if row.n?.start or row.n?.end
              unless edges?[row.n.id]
                edge = 
                  id: row.n.id
                  from: row.n.start
                  to: row.n.end
                  type: row.n.type
                  label: row.n.type
                  arrows: 'to'
                  group: row.n.type
                edges[row.n.id] = _.extend edge, row.n
            else
              unless nodes?[row.n.id]
                node = 
                  id: row.n.id
                  labels: row.n.labels
                  label: row.n.name
                  group: row.n.labels[0]
                nodes[row.n.id] = _.extend node, row.n

        visGraph.edges = (value for key, value of edges)
        visGraph.nodes = (value for key, value of nodes)

      return {updatedAt, data: visGraph}

    createNode: (form) ->
      check form, Object
      updatedAt = +new Date
      n = db.nodes({description: form.description, name: form.name, updatedAt}).labels.replace([form.label]).get()
      n.label = n.name
      n.group = n.labels[0]
      n

    updateNode: (form) ->
      check form, Object
      form.id = parseInt form.id
      updatedAt = +new Date
      n = db.nodes(form.id).properties.set({description: form.description, name: form.name, updatedAt}).labels.replace([form.label]).get()
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
      n = db.nodes id
      unless n.property 'removed'
        n.properties.set 
          removed: true
          updatedAt: updatedAt

        Meteor.setTimeout ->
          n = db.nodes id
          n.delete() if n?.get?()
        , 30000
      true
      
    createRelationship: (form) ->
      check form, Object
      form.to = parseInt form.to
      form.from = parseInt form.from

      updatedAt = +new Date

      n1 = db.nodes form.from
      n2 = db.nodes form.to

      r = n1.to(n2, form.type, {description: form.description, updatedAt}).get()
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
      
      oldRel = db.relationship.get form.id
      ###
      If this relationship already marked as removed, then it changed by someone else
      We will just wait for long-polling updates on client
      ###
      updatedAt = +new Date
      if oldRel.get()
        unless oldRel.property 'removed'
          n1 = db.nodes form.from
          n2 = db.nodes form.to
          if form.type isnt oldRel.get().type
            oldRel.properties.set
              removed: true
              updatedAt: updatedAt

            Meteor.setTimeout ->
              r = db.relationship.get form.id
              r.delete() if r?.get?()
            , 15000

            r = n1.to(n2, form.type, {description: form.description, updatedAt}).get()
          else
            r = oldRel.properties.set({description: form.description, updatedAt}).get()

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
      r = db.relationship.get id
      
      if r.get() and not r.property 'removed'
        r.properties.set
          removed: true
          updatedAt: updatedAt

        Meteor.setTimeout ->
          r = db.relationship.get id
          r.delete() if r?.get?()
        , 15000
      true

