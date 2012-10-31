crypto = require 'crypto'

module.exports = actionCipher =
  encrypt: (key, data) ->
    key = crypto.createHash('sha256').update(key).digest 'binary'
    iv = crypto.randomBytes 16
    aes = crypto.createCipheriv 'AES-256-CBC', key, iv
    encrypted = aes.update(data, 'utf8', 'base64') + aes.final('base64')
    [iv.toString('base64'), encrypted]

  decrypt: (key, iv, encrypted) ->
    key = crypto.createHash('sha256').update(key).digest 'binary'
    iv = new Buffer iv, 'base64'
    aes = crypto.createDecipheriv 'AES-256-CBC', key, iv
    aes.update(encrypted, 'base64', 'utf8') + aes.final('utf8')

