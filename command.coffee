async         = require 'async'
colors        = require 'colors'
dashdash      = require 'dashdash'
fs            = require 'fs'
_             = require 'lodash'
MeshbluConfig = require 'meshblu-config'
MeshbluHttp   = require 'meshblu-http'
NodeRSA       = require 'node-rsa'
crypto        = require 'crypto'
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
    {@bobUuid} = @parseOptions()
    @config  = new MeshbluConfig()
    @meshblu = new MeshbluHttp @config.toJSON()
    {@uuid} = @config.toJSON()
  parseOptions: =>
    parser = dashdash.createParser({options: OPTIONS})
    options = parser.parse(process.argv)
    bobUuid = _.first options._args

    if options.help
      console.log @usage parser.help({includeEnv: true})
      process.exit 0

    if options.version
      console.log packageJSON.version
      process.exit 0

    unless bobUuid?
      console.error @usage parser.help({includeEnv: true})
      console.error colors.red 'Missing required parameter <bob-uuid>'
      process.exit 1

    return {bobUuid}

  run: =>
    @setup (error) =>
      return @die error if error?
      console.log 'done'
      process.exit 0

  setup: (callback) =>
    async.series [
      @findOrCreateKeyPair
      @updatePublicKey
      @updateWhitelists
      @getBobPublicKey
      @addEncryptedBobKey
      @sendEncryptedMessage
    ], callback

  sendEncryptedMessage: (callback) =>
    @meshblu.whoami (error, device) =>
      return callback error if error?
      encryptedKey = _.get device, "keys.#{@uuid}.key"
      aesKey = @key.decrypt encryptedKey
      cipher = crypto.createCipher 'aes-256-ctr', aesKey
      encryptedMessage = cipher.update 'sup g', 'utf8', 'base64'
      encryptedMessage += cipher.final 'base64'
            
      @meshblu.message devices: ['*'], encrypted: encryptedMessage, callback

  findOrCreateKeyPair: (callback) =>
    try
      {privateKey, publicKey} = JSON.parse fs.readFileSync './keys.json'
      throw new Error unless privateKey? && publicKey?
      @keys = {privateKey, publicKey}
      @key = new NodeRSA privateKey
      return callback null
    catch
      console.warn 'no valid keys.json found, generating new pair'

    key = new NodeRSA()
    key.generateKeyPair()
    privateKey = key.exportKey 'private'
    publicKey  = key.exportKey 'public'
    fs.writeFileSync './keys.json', JSON.stringify({privateKey, publicKey}, null, 2)
    @keys = {privateKey, publicKey}
    callback null

  updateWhitelists: (callback) =>
    update =
      $set:
        'meshblu.version': '2.0.0'
      $addToSet:
        'meshblu.whitelists.broadcast.sent': uuid: @bobUuid
        'meshblu.whitelists.discover.view': uuid: @bobUuid

    @meshblu.updateDangerously @uuid, update, callback


  getBobPublicKey: (callback) =>
    @meshblu.publicKey @bobUuid, (error, {publicKey}={}) =>
      @bobPublicKey = new NodeRSA publicKey
      callback error

  addEncryptedBobKey: (callback) =>
    crypto.randomBytes 256, (error, random) =>
      return callback error if error?
      encryptedBobKey = @bobPublicKey.encrypt(random).toString 'base64'
      encryptedKey    = @key.encrypt(random).toString 'base64'

      update =
        $set:
          "keys.#{@bobUuid}.key": encryptedBobKey
          "keys.#{@uuid}.key": encryptedKey

      @meshblu.updateDangerously @uuid, update, callback



  updatePublicKey: (callback) =>
    @meshblu.update @uuid, {publicKey: @keys.publicKey}, callback

  die: (error) =>
    return process.exit(0) unless error?
    console.error 'ERROR'
    console.error error.stack
    process.exit 1

  usage: (optionsStr) =>
    """
    usage: e2e-broadcast-alice [OPTIONS] <bob-uuid>
    options:
    #{optionsStr}
    """


module.exports = Command
