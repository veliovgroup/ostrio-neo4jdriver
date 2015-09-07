console.success = -> console.info.apply null, colorizeForApply arguments, '32'
console.error = -> console.info.apply null, colorizeForApply arguments, '31'
colorizeForApply = (args, color) ->
  messages = ['\x1b[1m', "\x1b[#{color}m"]
  (messages.push arg for arg in args)
  messages.push '\x1b[39m', '\x1b[22m'
  return messages

Function::define = (name, getSet) -> Object.defineProperty @prototype, name, getSet

@NTRU_def = process.env.NODE_TLS_REJECT_UNAUTHORIZED
@bound = Meteor.bindEnvironment (callback) -> return callback()

@events = Npm.require 'events'
@URL = Npm.require 'url'
@needle = Npm.require 'needle'
@Future = Npm.require 'fibers/future'