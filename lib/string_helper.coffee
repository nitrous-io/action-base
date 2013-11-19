module.exports = stringHelper =
  escape: (string) ->
    if typeof string == 'string'
      return "'" + string.replace(/\'/g, "'\"'\"'") + "'"
    null


