SocketConnection = actionBase.SocketConnection
BaseSocket = actionBase.BaseSocket

class TestSocket extends BaseSocket
  namespace: 'test'

describe 'SocketConnection', ->
  connection = ws = authTokenVerifier = null

  beforeEach ->
    ws = sinon.stub on: (->), write: (->), close: (->)
    authTokenVerifier = sinon.stub verify: (->)
    connection = new SocketConnection ws, authTokenVerifier

  describe 'constructor', ->
    it 'sets @ws and @authTokenVerifier', ->
      expect(connection.ws).to.equal ws
      expect(connection.authTokenVerifier).to.equal authTokenVerifier

  describe '#register', ->
    it 'registers the socket and corresponding socket class', ->
      expect(connection.socketClasses.test).not.to.exist
      connection.register TestSocket
      expect(connection.socketClasses.test).to.equal TestSocket

  describe '#registerMany', ->
    it 'registers the socket primary namespace', ->
      expect(connection.socketClasses.primary).not.to.exist
      connection.registerMany TestSocket, 'primary', 'ns1', 'ns2'
      expect(connection.socketClasses.primary).to.equal TestSocket

    it 'registers secondary namespaces', ->
      expect(connection.socketClasses.ns1).not.to.exist
      expect(connection.socketClasses.ns2).not.to.exist
      connection.registerMany TestSocket, 'primary', 'ns1', 'ns2'
      expect(connection.socketClasses.ns1).to.equal TestSocket
      expect(connection.socketClasses.ns2).to.equal TestSocket

  describe '#close', ->
    it 'closes sockjs connection', ->
      connection.close()
      expect(ws.close).to.have.been.called

  describe '#isAuthenticated', ->
    context 'when @userId is null', ->
      beforeEach ->
        connection.userId = null

      it 'returns false', ->
        expect(connection.isAuthenticated()).to.be.false

    context 'when @userId is set', ->
      beforeEach ->
        connection.userId = 123

      it 'returns true', ->
        expect(connection.isAuthenticated()).to.be.true

  describe '#send', ->
    it 'sends an object via sockjs connection in json representation', ->
      payload = ['foo', 'bar', { 'baz': 'qux' }]
      connection.send payload
      expect(ws.write).to.have.been.calledWith JSON.stringify(payload)

  describe '#_invokeCallback', ->
    beforeEach ->
      connection._invokeCallback 123, ['foo', 'bar']

    it 'sends a callback message', ->
      expect(ws.write).to.have.been.calledWith JSON.stringify(['global', 'callback', [123, ['foo', 'bar']]])

  describe '#_onData', ->
    context 'when message is not a valid json', ->
      it 'does nothing', ->
        expect(->
          connection._onData '{{invalid'
        ).not.to.throw Error
        expect(ws.write).not.to.have.been.called

    context 'when message is a valid json', ->
      context 'when json is not an array', ->
        it 'does nothing', ->
          expect(->
            connection._onData JSON.stringify({"foo":"bar"})
          ).not.to.throw Error
          expect(ws.write).not.to.have.been.called

      context 'when json is an array in the form of [namespace, event, args, callbackId]', ->
        beforeEach ->
          sinon.stub connection, '_invokeCallback'

        context 'when the namespace is "global" and action is "auth"', ->
          context 'when auth token is valid', ->
            beforeEach ->
              authTokenVerifier.verify.withArgs('50m370k3n').returns 123
              connection._onData JSON.stringify(["global", "auth", ["50m370k3n"], 86])

            it 'sets @userId', ->
              expect(connection.userId).to.equal 123

            it 'invokes callback', ->
              expect(connection._invokeCallback).to.have.been.calledWith 86, []

          context 'when auth token fails verification', ->
            beforeEach ->
              sinon.stub connection, 'close'
              authTokenVerifier.verify.withArgs('50m370k3n').returns null
              connection._onData JSON.stringify(["global", "auth", ["50m370k3n"], 86])

            it 'sets @userId to be null', ->
              expect(connection.userId).to.be.null

            it 'closes connection', ->
              expect(connection.close).to.have.been.called

        context 'with a registered socket class', ->
          context 'when the action is "init"', ->
            beforeEach ->
              connection.register TestSocket

            context 'when authenticated', ->
              beforeEach ->
                sinon.stub(connection, 'isAuthenticated').returns true
                connection._onData JSON.stringify(["test", "init", null, 42])

              it 'initializes a test socket class', ->
                expect(connection.sockets.test).to.be.an.instanceof TestSocket
                expect(connection.sockets.test.connection).to.equal connection

              it 'invokes callback', ->
                expect(connection._invokeCallback).to.have.been.calledWith 42, []

            context 'when not authenticated', ->
              beforeEach ->
                sinon.stub(connection, 'isAuthenticated').returns false
                connection._onData JSON.stringify(["test", "init", null, 42])

              it 'does nothing', ->
                expect(connection.sockets.test).not.to.exist
                expect(connection._invokeCallback).not.to.have.been.called

          context 'given custom events', ->
            socket = null

            beforeEach ->
              socket = sinon.stub new TestSocket
              connection.sockets.test = socket

            context 'when authenticated', ->
              beforeEach ->
                sinon.stub(connection, 'isAuthenticated').returns true

              context 'when callback id is not given', ->
                beforeEach ->
                  connection._onData JSON.stringify(["test", "doSomething", ["foo", "bar"]])

                it 'emits the event to the socket with given arguments', ->
                  expect(socket.emit).to.have.been.calledWith 'doSomething', 'foo', 'bar'

              context 'when callback id is given', ->
                beforeEach ->
                  socket.emit.yields 'hello', 123
                  connection._onData JSON.stringify(["test", "doSomething", ["foo", "bar"], 69])

                it 'emits the event to the socket with given arguments and a function', ->
                  expect(socket.emit).to.have.been.calledWith 'doSomething', 'foo', 'bar', sinon.match.func
                  expect(connection._invokeCallback).to.have.been.calledWith 69, ['hello', 123]

            context 'when not authenticated', ->
              beforeEach ->
                sinon.stub(connection, 'isAuthenticated').returns false
                socket.emit.yields 'hello', 123
                connection._onData JSON.stringify(["ssh", "doSomething", ["foo", "bar"], 69])

              it 'does nothing', ->
                expect(socket.emit).not.to.have.been.called
                expect(connection._invokeCallback).not.to.have.been.called

        context 'with multiple socket classes', ->
          context 'when the action is "init"', ->
            beforeEach ->
              connection.registerMany TestSocket, 'primary', 'ns1'

            context 'when authenticated', ->
              beforeEach ->
                sinon.stub(connection, 'isAuthenticated').returns true

              context 'when receiving on primary namespace', ->
                beforeEach ->
                  connection._onData JSON.stringify(["primary", "init", null, 42])

                it 'initializes a socket class', ->
                  expect(connection.sockets.primary).to.be.an.instanceof TestSocket
                  expect(connection.sockets.primary.connection).to.equal connection

                it 'invokes callback', ->
                  expect(connection._invokeCallback).to.have.been.calledWith 42, []

              context 'when receiving on secondary namespace', ->
                context 'when primary namespace inited', ->
                  beforeEach ->
                    connection._onData JSON.stringify(["primary", "init", null, 42])
                    connection._onData JSON.stringify(["ns1", "init", null, 42])

                  it 'initializes a socket class', ->
                    expect(connection.sockets.ns1).to.be.an.instanceof TestSocket
                    expect(connection.sockets.ns1.connection).to.equal connection

                  it 'invokes callback', ->
                    expect(connection._invokeCallback).to.have.been.calledWith 42, []

                context 'when primary namespace not inited', ->
                  beforeEach ->
                    connection._onData JSON.stringify(["ns1", "init", null, 42])

                  it 'initializes a socket class', ->
                    expect(connection.sockets.ns1).to.be.an.instanceof TestSocket
                    expect(connection.sockets.ns1.connection).to.equal connection

                  it 'invokes callback', ->
                    expect(connection._invokeCallback).to.have.been.calledWith 42, []

            context 'when not authenticated', ->
              beforeEach ->
                sinon.stub(connection, 'isAuthenticated').returns false
                connection._onData JSON.stringify(["test", "init", null, 42])

              it 'does nothing', ->
                expect(connection.sockets.test).not.to.exist
                expect(connection._invokeCallback).not.to.have.been.called

        context 'with a non-registered socket class', ->
          context 'when the action is "init"', ->
            it 'does nothing', ->
              expect(->
                connection._onData JSON.stringify(["ssh", "init", null, 42])
              ).not.to.throw Error
              expect(connection.sockets.ssh).not.to.exist
              expect(connection._invokeCallback).not.to.have.been.called

          context 'when the action is not "init"', ->
            it 'does nothing', ->
              expect(->
                connection._onData JSON.stringify(["ssh", "doSomething", ["foo", "bar"], 69])
              ).not.to.throw Error
              expect(connection._invokeCallback).not.to.have.been.called

  describe '#_onClose', ->
    testSocket = testSocket2 = null

    beforeEach ->
      connection.socketClasses.test = TestSocket
      connection.socketClasses.test2 = TestSocket
      testSocket = connection.sockets.test = { destroy: sinon.spy() }
      testSocket2 = connection.sockets.test2 = { destroy: sinon.spy() }
      connection._onClose()

    it 'resets registered socket classes and initialized socket class instances', ->
      expect(connection.socketClasses).not.to.exist
      expect(connection.sockets).not.to.exist
      expect(testSocket.destroy).to.have.been.called
      expect(testSocket2.destroy).to.have.been.called
