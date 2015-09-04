class Neo4jNode
  constructor: (@_node, @isReactive) -> @newExpire()
  newExpire: -> @expire = (+new Date) + 2000
  get: -> @node
  update: ->
    if @_node?._service
      @node = @_node._service.self.get()
    return @
  @define 'node',
    get: -> 
      if @isReactive and @expire < +new Date
        @newExpire()
        @update()._node
      else
        @_node
    set: (newVal) -> 
      @_node = newVal unless EJSON.equals @_node, newVal