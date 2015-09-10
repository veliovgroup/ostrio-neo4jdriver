###
@locus Server
@summary Represents Neo4j endpoints
         Usually not used directly, it is used internally.
@class Neo4jEndpoint
###
class Neo4jEndpoint
  constructor: (@key, @endpoint, @_db) ->
    check @key, String
    check @endpoint, String
  get: (method = 'GET', body = {}) -> 
    data = @_db.__batch
      method: method
      to: @endpoint
      body: body
    data = data.get() if _.isFunction data.get
    return data

  __getAndProceed: (funcName, method = 'GET', body = {}, callback) ->
    if callback
      callback = (error, responce) => callback error, @_db[funcName] responce

    res = @_db.__batch(
      method: method
      to: @endpoint
      body: body
    , callback, false, true)

    unless callback
      res = @_db[funcName] res
      return res
    return