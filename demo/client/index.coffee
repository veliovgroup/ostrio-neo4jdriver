Meteor.startup ->
  Template.registerHelper 'nl2br', (string) ->
    if string and not _.isEmpty string
      string.replace /(?:\r\n|\r|\n)/g, '<br />'
    else
      undefined

Template.main.onCreated ->
  @_nodes = {}
  @nodesDS = []
  @_edges = {}
  @edgesDS = []
  @Network = null
  @nodeFrom = new ReactiveVar false
  @nodeTo = new ReactiveVar false
  @relationship = new ReactiveVar false

Template.main.helpers
  nodeFrom: -> Template.instance().nodeFrom.get()
  nodeTo: -> Template.instance().nodeTo.get()
  relationship: -> Template.instance().relationship.get()
  getNodeDegree: (node) -> 
    degree = 0
    for key, e of Template.instance()._edges
      if e.from is node.id or e.to is node.id
        ++degree
    degree
  isLabel: (label, node) -> !!~node.labels.indexOf label

Template.main.events
  'click button#deleteNode': (e, template) ->
    e.preventDefault()
    if template.nodeFrom.get()
      e.currentTarget.textContent = 'Removing...'
      e.currentTarget.disabled = true
      id = template.nodeFrom.get().id
      Meteor.call 'deleteNode', id, (error) ->
        if error
          throw new Meteor.Error error
        else
          template.nodesDS.remove id
          delete template._nodes[id]
          template.nodeFrom.set false
          template.nodeTo.set false
          template.relationship.set false
    false

  'submit form#createNode': (e, template) ->
    e.preventDefault()
    template.$(e.currentTarget).find(':submit').text('Creating...').prop('disabled', true)
    form = 
      name: e.target.name.value
      label: e.target.label.value
      description: e.target.description.value
    if e.target.name.value.length > 0 and e.target.label.value.length > 0
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
    template.$(e.currentTarget).find(':submit').text('Saving...').prop('disabled', true)
    form = 
      name: e.target.name.value
      label: e.target.label.value
      description: e.target.description.value
      id: template.nodeFrom.get().id
    if e.target.name.value.length > 0 and e.target.label.value.length > 0
      Meteor.call 'updateNode', form, (error, node) ->
        if error
          throw new Meteor.Error error
        else
          template.nodesDS.update node
          template._nodes[node.id] = node
          template.$(e.currentTarget).find(':submit').text('Update Node').prop('disabled', false)
          $(e.currentTarget)[0].reset()
    false

  'submit form#createRelationship': (e, template) ->
    e.preventDefault()
    template.$(e.currentTarget).find(':submit').text('Creating...').prop('disabled', true)
    form = 
      type: e.target.type.value
      description: e.target.description.value
      from: template.nodeFrom.get().id
      to: template.nodeTo.get().id
    if e.target.type.value.length > 0
      Meteor.call 'createRelationship', form, (error, edge) ->
        if error
          throw new Meteor.Error error
        else
          template.edgesDS.add edge
          template._edges[edge.id] = edge
          template.$(e.currentTarget).find(':submit').text('Create Relationship').prop('disabled', false)
          $(e.currentTarget)[0].reset()
    false

  'submit form#updateRelationship': (e, template) ->
    e.preventDefault()
    template.$(e.currentTarget).find(':submit').text('Updating...').prop('disabled', true)
    id = template.relationship.get().id
    form = 
      id: id
      type: e.target.type.value
      description: e.target.description.value
      from: template.relationship.get().from
      to: template.relationship.get().to
    if e.target.type.value.length > 0
      Meteor.call 'updateRelationship', form, (error, edge) ->
        if error
          throw new Meteor.Error error
        else
          # As in Neo4j no way to change relationship `type`
          # We will create new one and replace it
          template.edgesDS.remove id
          delete template._edges[id]

          template.edgesDS.add edge
          template._edges[edge.id] = edge
          template.$(e.currentTarget).find(':submit').text('Update Relationship').prop('disabled', false)
          $(e.currentTarget)[0].reset()
          template.relationship.set false
    false

  'click button#deleteRelationship': (e, template) ->
    e.preventDefault()
    e.currentTarget.textContent = 'Removing...'
    e.currentTarget.disabled = true
    id = template.relationship.get().id
    Meteor.call 'deleteRelationship', id, (error, edge) ->
      if error
        throw new Meteor.Error error
      else
        template.edgesDS.remove id
        delete template._edges[id]
        template.relationship.set false
    false

Template.main.onRendered ->

  container = document.getElementById 'graph'

  @nodesDS = new vis.DataSet []
  @edgesDS = new vis.DataSet []
  data = {nodes: @nodesDS, edges: @edgesDS}
  options =
    height: '400px'
    nodes:
      shape: 'dot'
      scaling:
        min: 10
        max: 30
        label:
          min: 8
          max: 30
          drawThreshold: 12
          maxVisible: 20
    interaction:
      hover: true
      navigationButtons: false
    physics: stabilization: false

  @Network = new vis.Network container, data, options

  resetNodes = (type = false) =>
    switch type
      when false
        @nodesDS.update {id:@nodeFrom.get().id, font: { background: "rgba(255,255,255,.0)" }} if @nodeFrom.get()
        @nodesDS.update {id:@nodeTo.get().id, font: { background: "rgba(255,255,255,.0)" }} if @nodeTo.get()
        @nodeFrom.set false
        @nodeTo.set false
      when 'to'
        @nodesDS.update {id:@nodeTo.get().id, font: { background: "rgba(255,255,255,.0)" }} if @nodeTo.get()
        @nodeTo.set false
      when 'from'
        @nodesDS.update {id:@nodeFrom.get().id, font: { background: "rgba(255,255,255,.0)" }} if @nodeFrom.get()
        @nodeFrom.set false
      when 'edge'
        @edgesDS.update {id: @relationship.get().id, font: { background: "rgba(255,255,255,.0)" }}
        @relationship.set false


  @Network.addEventListener 'click', (data) =>
    if @relationship.get()
      resetNodes 'edge'

    if data?.nodes?[0]
      unless @nodeFrom.get()
        @nodesDS.update {id: data.nodes[0], font: { background: "#FBFD70" }}
        @nodeFrom.set @_nodes[data.nodes[0]]

      else if @nodeFrom.get() and not @nodeTo.get()
        unless @nodeFrom.get().id is data.nodes[0]
          @nodesDS.update {id: data.nodes[0], font: { background: "#FBFD70" }}
          @nodeTo.set @_nodes[data.nodes[0]]

      else if @nodeFrom.get() and @nodeTo.get()
        resetNodes()

        @nodesDS.update {id: data.nodes[0], font: { background: "#FBFD70" }}
        @nodeFrom.set @_nodes[data.nodes[0]]

    else if data?.edges?[0]
      resetNodes()

      @edgesDS.update {id: data.edges[0], font: { background: "#FBFD70" }}
      @relationship.set @_edges[data.edges[0]]

    else if not data?.nodes?[0] and not data?.edges?[0]
      resetNodes()

  lastTimestamp = 0
  fetchData = =>
    Meteor.call 'graph', lastTimestamp, (error, data) =>
      if error
        throw new Meteor.Error error
      else
        lastTimestamp = +new Date
        for node in data.nodes
          if @_nodes?[node.id]
            @nodesDS.update node
          else
            @nodesDS.add [node]
          @_nodes[node.id] = node

        for edge in data.edges
          if @_edges?[edge.id]
            @edgesDS.update edge
          else
            @edgesDS.add [edge]
          @_edges[edge.id] = edge

      ###
      Set up long-polling
      ###
      Meteor.setTimeout fetchData, 1500

  fetchData()
