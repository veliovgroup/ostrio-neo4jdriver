class Neo4jEndpoint
  constructor: (@key, @endpoint, @_db) ->
    check @key, String
    check @endpoint, String
  get: (method = 'GET', body = {}, callback) -> 
    @_db.__batch(
      method: method
      to: @endpoint
      body: body
    ,
      callback).get?()