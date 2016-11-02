dashdash      = require 'dashdash'
MeshbluConfig = require 'meshblu-config'
MeshbluHttp   = require 'meshblu-http'

packageJSON = require './package.json'

OPTIONS = [{
  names: ['help', 'h']
  type: 'bool'
  help: 'Print this help and exit.'
}, {
  names: ['version', 'v']
  type: 'bool'
  help: 'Print the version and exit.'
}]

class Command
  constructor: ->
    process.on 'uncaughtException', @die
    {} = @parseOptions()
    @config  = new MeshbluConfig()
    @meshblu = new MeshbluHttp @config.toJSON()

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
    callback()

  die: (error) =>
    return process.exit(0) unless error?
    console.error 'ERROR'
    console.error error.stack
    process.exit 1

module.exports = Command
