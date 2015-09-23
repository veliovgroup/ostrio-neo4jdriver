let colorize = (args, color) => {
  let arg, i, len, messages;
  messages = ['\x1b[1m', "\x1b[" + color + "m"]
  for (i = 0, len = args.length; i < len; i++) {
    arg = args[i]
    try {
      messages.push(_.isObject(arg) ? arg.toString() : arg);
    } catch (error) {
      messages.push(JSON.stringify(arg, null, 2));
    }
  }
  messages.push('\x1b[39m', '\x1b[22m\x1b[0m');
  return messages;
};

__success = function() {
  return process.stdout.write(colorize(arguments, '32').join('') + '\r\n');
};

__error = function() {
  return process.stdout.write(colorize(arguments, '31').join('') + '\r\n');
};

Function.prototype.define = function(name, getSet) {
  return Object.defineProperty(this.prototype, name, getSet);
};

NTRU_def = process.env.NODE_TLS_REJECT_UNAUTHORIZED;

bound = Meteor.bindEnvironment((callback) => {
  return callback();
});

events = Npm.require('events');
URL    = Npm.require('url');
needle = Npm.require('needle');
Fiber  = Npm.require('fibers');
Future = Npm.require('fibers/future');

__wait = (cb) => {
  let fut;
  fut = new Future();
  cb(fut);
  return fut.wait();
};