MainTemplate = {}
VIS_OPTIONS =
  height: '500px'
  nodes:
    shape: 'circle'
    scaling:
      min: 30
      max: 30
  edges: font: align: 'middle'
  interaction:
    hover: true
    hoverConnectedEdges: false
    navigationButtons: false
    selectConnectedEdges: false
  physics: stabilization: false
  groups:
    Person:
      borderWidth: 2
      mass: 3
      color: 
        background: 'rgba(75, 159, 236, 0.95)'
        border: 'rgba(8, 93, 171, 0.777)'
        highlight:
          background: 'rgba(75, 159, 236, 0.75)'
          border: 'rgba(8, 93, 171, 0.577)'
        hover:
          background: 'rgba(75, 159, 236, 0.75)'
          border: 'rgba(8, 93, 171, 0.577)'
    Movie:
      borderWidth: 3
      mass: 2
      color: 
        background: 'rgba(241, 187, 12, 0.95)'
        border: 'rgba(212, 107, 12, 0.777)'
        highlight:
          background: 'rgba(241, 187, 12, 0.75)'
          border: 'rgba(212, 107, 12, 0.577)'
        hover:
          background: 'rgba(241, 187, 12, 0.75)'
          border: 'rgba(212, 107, 12, 0.577)'
    Place:
      borderWidth: 4
      mass: 1
      color: 
        background: 'rgba(230, 66, 66, 0.95)'
        border: 'rgba(107, 9, 9, 0.777)'
        highlight:
          background: 'rgba(230, 66, 66, 0.75)'
          border: 'rgba(107, 9, 9, 0.577)'
        hover:
          background: 'rgba(230, 66, 66, 0.75)'
          border: 'rgba(107, 9, 9, 0.577)'

VIS_PREVIEW_OPTIONS = 
  height: '75px'
  physics: false
  interaction:
    hover: false
    selectable: false


clearNetwork = (template) ->
  template.Network.destroy() if template.Network
  template.nodesDS.clear() if template.nodesDS
  template.edgesDS.clear() if template.edgesDS

makeFakeRelation = (template, from, to, container) ->
  ###
  As vis.js uses global DataSet, and we unable to add nodes with same id
  We set temp ids for preview nodes
  ###
  template.rid = Random.id()
  template.fromId = Random.id()
  _from = _.clone from
  _from.id = template.fromId
  _from.x = -150
  _from.y = 0

  template.toId = Random.id()
  _to = _.clone to
  _to.id = template.toId
  _to.x = 150
  _to.y = 0

  if template.relationship
    template.relationship.from = template.fromId
    template.relationship.to = template.toId
    template.relationship.id = template.rid
  else
    template.relationship = 
      from: template.fromId
      to: template.toId
      id: template.rid
      label: 'KNOWS'
      group: 'KNOWS'
      arrows: 'to'

  template.edgesDS = new vis.DataSet [template.relationship]
  template.nodesDS = new vis.DataSet [_from, _to]

  data = {nodes: template.nodesDS, edges: template.edgesDS}
  template.Network = new vis.Network container, data, _.extend VIS_OPTIONS, VIS_PREVIEW_OPTIONS

###
Create `nl2br` global helper on startup
###
Meteor.startup ->
  Template.registerHelper 'nl2br', (string) ->
    if string and not _.isEmpty string
      string.replace /(?:\r\n|\r|\n)/g, '<br />'
    else
      undefined

###
Template.main
###
Template.main.onCreated ->
  MainTemplate = @
  @_nodes = {}
  @nodesDS = []
  @_edges = {}
  @edgesDS = []
  @Network = null
  @nodeFrom = new ReactiveVar false
  @nodeTo = new ReactiveVar false
  @relationship = new ReactiveVar false
  @resetNodes = (type = false) =>
    switch type
      when false
        @nodesDS.update {id: @nodeFrom.get().id, font: { background: "rgba(255,255,255,.0)" }} if @nodeFrom.get() and @_nodes[@nodeFrom.get().id]
        @nodesDS.update {id: @nodeTo.get().id, font: { background: "rgba(255,255,255,.0)" }} if @nodeTo.get() and @_nodes[@nodeTo.get().id]
        @nodeFrom.set false
        @nodeTo.set false
      when 'to'
        @nodesDS.update {id:@nodeTo.get().id, font: { background: "rgba(255,255,255,.0)" }} if @nodeTo.get() and @_nodes[@nodeTo.get().id]
        @nodeTo.set false
      when 'from'
        @nodesDS.update {id:@nodeFrom.get().id, font: { background: "rgba(255,255,255,.0)" }} if @nodeFrom.get() and @_nodes[@nodeFrom.get().id]
        @nodeFrom.set false
      when 'edge'
        @edgesDS.update {id: @relationship.get().id, font: { background: "rgba(255,255,255,.0)" }} if @relationship.get() and @_edges[@relationship.get().id]
        @relationship.set false

Template.main.helpers
  hasSelection: -> !!(Template.instance().nodeFrom.get() or Template.instance().nodeTo.get() or Template.instance().relationship.get())
  nodeFrom: -> Template.instance().nodeFrom.get()
  nodeTo: -> Template.instance().nodeTo.get()
  getNodeDegree: (node) -> 
    degree = 0
    for key, e of Template.instance()._edges
      if e.from is node.id or e.to is node.id
        ++degree
    degree
  isLabel: (label, node) -> !!~node.labels.indexOf label
  relationship: -> Template.instance().relationship.get()

Template.main.events
  'click button#deleteNode': (e, template) ->
    e.preventDefault()
    _n = template.nodeFrom.get()
    if _n
      e.currentTarget.textContent = 'Removing...'
      e.currentTarget.disabled = true
      Meteor.call 'deleteNode', _n.id, (error) ->
        if error
          throw new Meteor.Error error
        else
          template.nodesDS.remove _n.id
          delete template._nodes[_n.id]
          template.resetNodes()
          template.resetNodes('edge')
    false

  'submit form#createNode': (e, template) ->
    e.preventDefault()
    form = 
      name: "#{e.target.name.value}"
      label: "#{e.target.label.value}"
      description: "#{e.target.description.value}"

    if form.name.length > 0 and form.label.length > 0
      template.$(e.currentTarget).find(':submit').text('Creating...').prop('disabled', true)
      Meteor.call 'createNode', form, (error, node) ->
        if error
          throw new Meteor.Error error
        else
          template.nodesDS.add node
          template._nodes[node.id] = node
          template.$(e.currentTarget).find(':submit').text('Create Node').prop('disabled', false)
          $(e.currentTarget)[0].reset()
    false

  'submit form#editNode': (e, template) ->
    e.preventDefault()
    _n = template.nodeFrom.get()
    form = 
      name: "#{e.target.name.value}"
      label: "#{e.target.label.value}"
      description: "#{e.target.description.value}"
      id: _n.id
    if form.name.length > 0 and form.label.length > 0 and (_n.name isnt form.name or _n.description isnt form.description or _n.group isnt form.label)
      template.$(e.currentTarget).find(':submit').text('Saving...').prop('disabled', true)
      Meteor.call 'updateNode', form, (error, node) ->
        if error
          throw new Meteor.Error error
        else
          template.nodesDS.update node
          template._nodes[node.id] = node
          template.$(e.currentTarget).find(':submit').text('Update Node').prop('disabled', false)
          $(e.currentTarget)[0].reset()
          template.resetNodes()
          template.resetNodes('edge')
    false

Template.main.onRendered ->
  container = document.getElementById 'graph'
  @nodesDS = new vis.DataSet []
  @edgesDS = new vis.DataSet []
  data = {nodes: @nodesDS, edges: @edgesDS}

  @Network = new vis.Network container, data, VIS_OPTIONS

  @Network.addEventListener 'click', (data) =>
    if @relationship.get()
      @resetNodes 'edge'

    if data?.nodes?[0]
      data.nodes[0] = parseInt data.nodes[0]
      unless @nodeFrom.get()
        @nodesDS.update {id: data.nodes[0], font: { background: "#FBFD70" }}
        @nodeFrom.set @_nodes[data.nodes[0]]

      else if @nodeFrom.get() and not @nodeTo.get()
        unless @nodeFrom.get().id is data.nodes[0]
          @nodesDS.update {id: data.nodes[0], font: { background: "#FBFD70" }}
          @nodeTo.set @_nodes[data.nodes[0]]

      else if @nodeFrom.get() and @nodeTo.get()
        @resetNodes()

        @nodesDS.update {id: data.nodes[0], font: { background: "#FBFD70" }}
        @nodeFrom.set @_nodes[data.nodes[0]]

    else if data?.edges?[0]
      @resetNodes()

      @edgesDS.update {id: data.edges[0], font: { background: "#FBFD70" }}
      @relationship.set @_edges[data.edges[0]]

    else if not data?.nodes?[0] and not data?.edges?[0]
      @resetNodes()

  lastTimestamp = 0
  fetchData = =>
    Meteor.call 'graph', lastTimestamp, (error, result) =>
      data = result.data
      lastTimestamp = result.updatedAt
      if error
        throw new Meteor.Error error
      else
        for node in data.nodes
          if node.removed
            if @_nodes?[node.id]
              @nodesDS.remove node.id
              delete @_nodes[node.id]
          else
            if @_nodes?[node.id]
              unless EJSON.equals node, @_nodes[node.id]
                @nodesDS.update node 
                @nodeFrom.set node if @nodeFrom.get() and @nodeFrom.get().id is node.id
                @nodeTo.set node if @nodeTo.get() and @nodeTo.get().id is node.id
                ###
                If user currently inspecting / editing relationship, 
                which somehow includes one of updated nodes - we update inspector state
                ###
                r = @relationship.get()
                if r and (r.from is node.id or r.to is node.id)
                  _r = _.clone @relationship.get()
                  _r.updatedAt = lastTimestamp
                  @relationship.set _r
            else
              @nodesDS.add [node]
            @_nodes[node.id] = node

        for edge in data.edges
          if edge.removed
            if @_edges?[edge.id]
              @edgesDS.remove edge.id
              delete @_edges[edge.id]
              ###
              If user currently inspecting / editing relationship, which just was removed
              We close inspector
              ###
              @relationship.set null if @relationship.get() and @relationship.get().id is edge.id
          else
            if @_edges?[edge.id]
              unless EJSON.equals edge, @_edges[edge.id]
                @edgesDS.update edge 
                ###
                If user currently inspecting / editing relationship, which just was updated
                We update inspector
                ###
                @relationship.set edge if @relationship.get() and @relationship.get().id is edge.id
            else
              @edgesDS.add [edge]
            @_edges[edge.id] = edge

      ###
      Set up long-polling
      ###
      Meteor.setTimeout fetchData, 1500

  fetchData()


###
Template.createRelationship
###
Template.createRelationship.onRendered ->
  @from = MainTemplate.nodeFrom.get()
  @to = MainTemplate.nodeTo.get()
  makeFakeRelation @, @from, @to, document.getElementById 'createRelPreview'

Template.createRelationship.onDestroyed -> clearNetwork @

Template.createRelationship.events
  'submit form#createRelationship': (e, template) ->
    e.preventDefault()
    template.$(e.currentTarget).find(':submit').text('Creating...').prop('disabled', true)
    form = 
      type: e.target.type.value
      description: e.target.description.value
      from: template.from.id
      to: template.to.id
    if e.target.type.value.length > 0
      Meteor.call 'createRelationship', form, (error, edge) ->
        if error
          throw new Meteor.Error error
        else
          MainTemplate.edgesDS.add edge
          MainTemplate._edges[edge.id] = edge
          template.$(e.currentTarget).find(':submit').text('Create Relationship').prop('disabled', false)
          $(e.currentTarget)[0].reset()
          MainTemplate.resetNodes()
          MainTemplate.resetNodes('edge')
    false

  'change select#type': (e, template) ->
    template.relationship.label = e.target.value
    template.relationship.group = e.target.value
    template.edgesDS.update template.relationship

###
Template.updateRelationship
###
Template.updateRelationship.onRendered ->
  @autorun =>
    clearNetwork @
    if MainTemplate.relationship.get()
      @relationship = _.clone MainTemplate.relationship.get()
      makeFakeRelation @, MainTemplate._nodes[@relationship.from], MainTemplate._nodes[@relationship.to], document.getElementById 'updateRelPreview'

Template.updateRelationship.onDestroyed -> clearNetwork @

Template.updateRelationship.helpers
  relationship: -> MainTemplate.relationship.get()

Template.updateRelationship.events
  'submit form#updateRelationship': (e, template) ->
    e.preventDefault()
    _r = MainTemplate.relationship.get()
    id = _r.id
    form = 
      id: id
      type: e.target.type.value
      description: e.target.description.value
      from: _r.from
      to: _r.to

    if form.type.length > 0 and (_r.type isnt form.type or _r.description isnt form.description)
      template.$(e.currentTarget).find(':submit').text('Updating...').prop('disabled', true)
      Meteor.call 'updateRelationship', form, (error, edge) ->
        if error
          throw new Meteor.Error error
        else if _.isObject edge
          if _r.type isnt form.type
            # As in Neo4j no way to change relationship `type`
            # We will create new one and replace it
            MainTemplate.edgesDS.remove id
            delete MainTemplate._edges[id]
            MainTemplate.edgesDS.add edge
          else
            MainTemplate.edgesDS.update edge
          MainTemplate._edges[edge.id] = edge

        template.$(e.currentTarget).find(':submit').text('Update Relationship').prop('disabled', false)
        $(e.currentTarget)[0].reset()
        MainTemplate.resetNodes()
        MainTemplate.resetNodes('edge')
    false

  'click button#deleteRelationship': (e, template) ->
    e.preventDefault()
    e.currentTarget.textContent = 'Removing...'
    e.currentTarget.disabled = true
    id = MainTemplate.relationship.get().id
    Meteor.call 'deleteRelationship', id, (error, edge) ->
      if error
        throw new Meteor.Error error
      else
        MainTemplate.edgesDS.remove id
        delete MainTemplate._edges[id]
        MainTemplate.resetNodes()
        MainTemplate.resetNodes('edge')
    false

  'change select#type': (e, template) ->
    template.relationship.label = e.target.value
    template.relationship.group = e.target.value
    template.edgesDS.update template.relationship