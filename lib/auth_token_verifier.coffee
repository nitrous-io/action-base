util = require './util'

module.exports = class AuthTokenVerifier
  constructor: (@name, @messageVerifier) ->

  verify: (token) ->
    return null unless token
    if verifiedToken = @messageVerifier.verify util.decodeURLSafeBase64(token)
      [userId, name, expiresAt] = verifiedToken
      now = Math.floor(+new Date / 1000)
      if (name == @name) && (expiresAt > now)
        return userId
    null
