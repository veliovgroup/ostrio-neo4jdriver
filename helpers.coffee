console.success = (message) -> console.info '\x1b[1m', '\x1b[32m', message, '\x1b[39m', '\x1b[22m'
console.error = (message) -> console.info '\x1b[1m', '\x1b[31m', message, '\x1b[39m', '\x1b[22m'

@NTRU_def = process.env.NODE_TLS_REJECT_UNAUTHORIZED
@bound = Meteor.bindEnvironment (callback) -> return callback()

@events = Npm.require 'events'
@URL = Npm.require 'url'
@needle = Npm.require 'needle'
@Future = Npm.require 'fibers/future'