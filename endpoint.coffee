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

  get: (method = 'GET', options = {}, directly) -> 
    if directly
      @_db.__call(@endpoint, options, method).data
    else
      data = @_db.__batch
        method: method
        to: @endpoint
        body: options.body
      data = data.get() if _.isFunction data.get

  __getAndProceed: (funcName) ->
    @_db[funcName] @_db.__batch
      method: 'GET'
      to: @endpoint
    , undefined, false, true