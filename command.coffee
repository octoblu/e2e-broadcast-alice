_             = require 'lodash'
fs            = require 'fs'
dashdash      = require 'dashdash'
MeshbluConfig = require 'meshblu-config'
MeshbluHttp   = require 'meshblu-http'

packageJSON = require './package.json'

OPTIONS = [
  {
  names: ['help', 'h']
  type: 'bool'
  help: 'Print this help and exit.'
  },
  {
    names: ['version', 'v']
    type: 'bool'
    help: 'Print the version and exit.'
  }
  {
    names: ['add', 'a']
    type: 'string'
    help: 'uuid to add to the encrypted broadcast system'
  }
]

class Command
  constructor: ->
    process.on 'uncaughtException', @die
    {@add} = @parseOptions()
    @config  = new MeshbluConfig()
    @meshblu = new MeshbluHttp @config.toJSON()
    {@uuid, @privateKey} = @config.toJSON()
  parseOptions: =>
    parser = dashdash.createParser({options: OPTIONS})
    options = parser.parse(process.argv)

    if options.help
      console.log "usage: e2e-broadcast-alice [OPTIONS]\noptions:\n#{parser.help({includeEnv: true})}"
      process.exit 0

    if options.version
      console.log packageJSON.version
      process.exit 0

    return options

  run: =>
    @setup (error) =>
      return @die error if error?

  setup: (callback) =>
    @_generateKeyPair (error) =>
      return callback error if error?
      @_addSubscriber @add, (error) =>
        return callback error if error?
        console.log "done."

  _generateKeyPair (callback) =>
    return callback null, @privateKey if @privateKey?

  _addSubscriber: (subscriber, callback) =>
    update =
      $set:
        'meshblu.version': '2.0.0'
      $addToSet:
        'meshblu.whitelists.broadcast.sent': uuid: subscriber
        'meshblu.whitelists.discover.view': uuid: subscriber

    @meshblu.updateDangerously @uuid, update, callback

  die: (error) =>
    return process.exit(0) unless error?
    console.error 'ERROR'
    console.error error.stack
    process.exit 1

module.exports = Command
