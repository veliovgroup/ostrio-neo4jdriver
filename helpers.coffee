colorize = (args, color) ->
  messages = ['\x1b[1m', "\x1b[#{color}m"]
  for arg in args
    try
      messages.push if _.isObject arg then JSON.stringify arg else arg
    catch error
      messages.push arg.toString()
  messages.push '\x1b[39m', '\x1b[22m\x1b[0m'
  return messages
@__success = -> process.stdout.write colorize(arguments, '32').join('') + '\r\n'
@__error   = -> process.stdout.write colorize(arguments, '31').join('') + '\r\n'

Function::define = (name, getSet) -> Object.defineProperty @prototype, name, getSet

@NTRU_def = process.env.NODE_TLS_REJECT_UNAUTHORIZED
@bound = Meteor.bindEnvironment (callback) -> return callback()

@events   = Npm.require 'events'
@URL      = Npm.require 'url'
@needle   = Npm.require 'needle'
@Fiber    = Npm.require 'fibers'
@Future   = Npm.require 'fibers/future'
@__wait = (cb) -> 
  fut = new Future()
  cb fut
  return fut.wait()