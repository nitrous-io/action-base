pg = require('pg').native

module.exports = class BaseModel
  constructor: (attributes) ->
    this[k] = v for own k, v of attributes

BaseModel.testConnection = (callback) ->
  pg.connect (err, client) ->
    return callback(err) if err
    client.query "SELECT 1", (err, res) ->
      return callback(err) if err
      callback null

BaseModel.findMany = (condition, values, columns, callback) ->
  if typeof columns == 'function'
    callback = columns
    columns = '*'
  unless this.tableName
    callback new Error('tableName not defined'), null
    return
  pg.connect (err, client) =>
    if err
      callback err, null
      return
    if columns instanceof Array
      columns.unshift('id') if columns.indexOf('id') == -1
      columns = columns.join ', '
    client.query "SELECT #{columns} FROM #{@tableName} WHERE #{condition}", values, (err, res) =>
      if err
        callback err, null
        return
      if res && res.rows.length > 0
        models = for row in res.rows
          model = new this
          for own k, v of row
            model[k] = v
          model
        callback null, models
      else
        callback null, []

BaseModel.findOne = (condition, values, columns, callback) ->
  if typeof columns == 'function'
    callback = columns
    columns = '*'
  this.findMany "#{condition} LIMIT 1", values, columns, (err, models) ->
    model = if models && models.length > 0
      models[0]
    else
      null
    callback err, model

BaseModel.findById = (id, columns, callback) ->
  if typeof columns == 'function'
    callback = columns
    this.findOne 'id = $1', [id], callback
  else
    this.findOne 'id = $1', [id], columns, callback

