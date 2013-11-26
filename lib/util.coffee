module.exports =
  encodeURLSafeBase64: (string) ->
    b64 = new Buffer(string, 'utf8').toString('base64')
    b64.replace(/\+/g, '-').replace(/\//g, '_')

  decodeURLSafeBase64: (string) ->
    string = string.replace(/-/g,'+').replace(/_/g, '/')
    new Buffer(string, 'base64').toString('utf8')
