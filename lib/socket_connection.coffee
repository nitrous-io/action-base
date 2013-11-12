_ = require 'underscore'

module.exports = class SocketConnection
  constructor: (@ws, @authTokenVerifier) ->
    @userId = null
    @socketClasses = {}
    @sockets = {}
    @ws.on 'data',  _.bind(@_onData, this)
    @ws.on 'close', _.bind(@_onClose, this)

  register: (socketClass) ->
    @socketClasses[socketClass::namespace] = socketClass

  close: ->
    @ws?.close()

  send: (payload) ->
    @ws?.write JSON.stringify(payload)

  isAuthenticated: ->
    @userId?

  _onData: (message) ->
    try
      message = JSON.parse(message)
    catch err
      return
    return unless message instanceof Array

    [namespace, event, args, callbackId] = message

    invokeCallback = (args=[]) =>
      if callbackId?
        @_invokeCallback callbackId, args

    if namespace == 'global' && event == 'auth'
      @userId = @authTokenVerifier.verify(args[0])
      if @userId?
        invokeCallback()
      else
        @close()
    else if @isAuthenticated()
      if event == 'init'
        if socketClass = @socketClasses[namespace]
          @sockets[namespace] = new socketClass this
          invokeCallback()
      else if socket = @sockets[namespace]
        args.unshift event
        args.push =>
          invokeCallback _.toArray(arguments)
        socket.emit args...

  _onClose: ->
    @socketClasses = null
    _.each @sockets, (socket) ->
      socket.destroy?()
    @sockets = null
    @ws = null

  _invokeCallback: (callbackId, args) ->
    @ws?.write JSON.stringify(['global', 'callback', [callbackId, args]])
