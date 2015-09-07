console.success = (message) -> console.info '\x1b[1m', '\x1b[32m', message, '\x1b[39m', '\x1b[22m'
console.error = (message) -> console.info '\x1b[1m', '\x1b[31m', message, '\x1b[39m', '\x1b[22m'

Function::define = (name, getSet) -> Object.defineProperty @prototype, name, getSet

getIds = (data, ids = []) ->
  _get = (row) ->
    if _.isObject row
      if row?.metadata
        ids.push row.metadata.id
      else
        getIds row, ids
  if _.isArray data
    _get row for row in data
  else if _.isObject data
    _get row for key, row of data
  return ids