BaseModel = actionBase.BaseModel
pg = require('pg').native
async = require 'async'

describe 'BaseModel', ->
  describe 'constructor', ->
    it 'assigns key-value pairs given', ->
      model = new BaseModel foo: 'F00', bar: 'B@R', baz: 123
      expect(model.foo).to.equal 'F00'
      expect(model.bar).to.equal 'B@R'
      expect(model.baz).to.equal 123

  describe '.testConnection', ->
    context 'when pg.connect fails', ->
      error = null

      beforeEach ->
        error = new Error
        sinon.stub pg, 'connect', (cb) ->
          cb error, null

      afterEach ->
        pg.connect.restore()

      it 'calls callback with error', (done) ->
        BaseModel.testConnection (err) ->
          expect(err).to.equal error
          done()

    context 'when pg.connect is successful', ->
      context 'when query fails with error', ->
        fakeClient = error = null

        beforeEach ->
          error = new Error
          fakeClient = { query: -> }
          sinon.stub fakeClient, 'query', (q, cb) ->
            cb error, null
          sinon.stub pg, 'connect', (cb) ->
            cb null, fakeClient

        afterEach ->
          pg.connect.restore()

        it 'calls callback with error', (done) ->
          BaseModel.testConnection (err) ->
            expect(err).to.equal error
            done()

      context 'when query succeeds', ->
        it 'calls callback with null', (done) ->
          BaseModel.testConnection (err) ->
            expect(err).to.be.null
            done()

  describe '.findMany', ->
    context 'when tableName property is defined', ->
      before (done) ->
        pg.connect (err, client) ->
          throw err if err
          client.query 'DROP TABLE "test_table"', (err, res) ->
            client.query "CREATE TABLE \"test_table\" (
              id integer PRIMARY KEY,
              foo varchar(255),
              bar integer
            )", (err, res) ->
              throw err if err
              done()

      after (done) ->
        pg.connect (err, client) ->
          throw err if err
          client.query 'DROP TABLE "test_table"', (err, res) ->
            throw err if err
            done()

      beforeEach ->
        BaseModel.tableName = 'test_table'

      context 'when pg.connect fails', ->
        error = null

        beforeEach ->
          error = new Error
          sinon.stub pg, 'connect', (cb) ->
            cb error, null

        afterEach ->
          pg.connect.restore()

        it 'calls callback with error', (done) ->
          BaseModel.findMany 'id = $1', [123], (err, models) ->
            expect(err).to.equal error
            expect(models).to.be.null
            done()

      context 'when pg.connect is successful', ->
        context 'when query fails with error', ->
          fakeClient = error = null

          beforeEach ->
            error = new Error
            fakeClient = { query: -> }
            sinon.stub fakeClient, 'query', (q, v, cb) ->
              cb error, null
            sinon.stub pg, 'connect', (cb) ->
              cb null, fakeClient

          afterEach ->
            pg.connect.restore()

          it 'calls callback with error', (done) ->
            BaseModel.findMany 'id = $1', [123], (err, models) ->
              expect(err).to.equal error
              expect(models).to.be.null
              done()

        context 'when a row that matches a given condition does not exist', ->
          it 'returns an empty array', (done) ->
            BaseModel.findMany 'id = $1', [123], (err, models) ->
              expect(err).to.be.null
              expect(models).to.deep.equal []
              done()

        context 'when rows that matches a given condition exists', ->
          before (done) ->
            pg.connect (err, client) ->
              throw err if err
              async.series [
                (cb) -> client.query 'INSERT INTO "test_table" (id, foo, bar) VALUES ($1, $2, $3)', [1, 'test1', 42], cb
                (cb) -> client.query 'INSERT INTO "test_table" (id, foo, bar) VALUES ($1, $2, $3)', [2, 'test2', 999], cb
                (cb) -> client.query 'INSERT INTO "test_table" (id, foo, bar) VALUES ($1, $2, $3)', [3, 'test3', 42], cb
              ], -> done()

          after (done) ->
            pg.connect (err, client) ->
              throw err if err
              client.query 'DELETE FROM "test_table"', (err, res) ->
                throw err if err
                done()

          context 'when columns are not specified', ->
            it 'fetches a row with given id and returns a model object with all attributes', (done) ->
              BaseModel.findMany 'bar = $1', [42], (err, models) ->
                expect(models).to.have.length 2
                expect(models[0]).to.be.an.instanceof BaseModel
                expect(models[0].id).to.equal 1
                expect(models[0].foo).to.equal 'test1'
                expect(models[0].bar).to.equal 42
                expect(models[1]).to.be.an.instanceof BaseModel
                expect(models[1].id).to.equal 3
                expect(models[1].foo).to.equal 'test3'
                expect(models[1].bar).to.equal 42
                done()

          context 'when columns are specified', ->
            it 'fetches a row with given id and returns a model object with specified attributes + id', (done) ->
              BaseModel.findMany 'bar = $1', [42], ['foo'], (err, models) ->
                expect(models).to.have.length 2
                expect(models[0]).to.be.an.instanceof BaseModel
                expect(models[0].id).to.equal 1
                expect(models[0].foo).to.equal 'test1'
                expect(models[0]).not.to.have.property 'bar'
                expect(models[1]).to.be.an.instanceof BaseModel
                expect(models[1].id).to.equal 3
                expect(models[1].foo).to.equal 'test3'
                expect(models[1]).not.to.have.property 'bar'
                done()

    context 'when tableName property is not defined', ->
      beforeEach ->
        delete BaseModel.tableName

      it 'calls callback with error', (done) ->
        BaseModel.findMany 'id = $1', [123], (err, model) ->
          expect(err).to.be.an.instanceof Error
          expect(err.message).to.match /tableName/
          expect(model).to.be.null
          done()

  describe '.findByOne', ->
    cbSpy = null

    beforeEach ->
      sinon.stub BaseModel, 'findMany'
      cbSpy = sinon.spy()

    afterEach ->
      BaseModel.findMany.restore()

    it 'calls findMany with LIMIT 1 appended to condition', ->
      BaseModel.findOne 'id = $1', [123], ['foo', 'bar'], cbSpy
      expect(BaseModel.findMany).to.have.been.calledWith 'id = $1 LIMIT 1', [123], ['foo', 'bar']

    context 'when given only 3 arguments', ->
      it 'calls findMany with LIMIT 1 appended to condition and * as columns argument', ->
        BaseModel.findOne 'id = $1', [123], cbSpy
        expect(BaseModel.findMany).to.have.been.calledWith 'id = $1 LIMIT 1', [123], '*'

    context 'when findMany invokes callback with an error', ->
      error = null

      beforeEach ->
        error = new Error 'some-error'
        BaseModel.findMany.yields error

      it 'also invokes callback with error', ->
        BaseModel.findOne 'id = $1', [123], ['foo', 'bar'], cbSpy
        expect(cbSpy).to.have.been.calledWith error

    context 'when findMany invokes callback with a result', ->
      res = null

      beforeEach ->
        res = new BaseModel
        BaseModel.findMany.yields null, [res]

      it 'invokes callback with the the first item in the result', ->
        BaseModel.findOne 'id = $1', [123], ['foo', 'bar'], cbSpy
        expect(cbSpy).to.have.been.calledWith null, res

  describe '.findById', ->
    cbSpy = null

    beforeEach ->
      sinon.stub BaseModel, 'findOne'
      cbSpy = sinon.spy()

    afterEach ->
      BaseModel.findOne.restore()

    context 'when columns option is given', ->
      it 'selects selected columns only', ->
        BaseModel.findById 123, ['foo', 'bar'], cbSpy
        expect(BaseModel.findOne).to.have.been.calledWith 'id = $1', [123], ['foo', 'bar'], cbSpy

    context 'when columns option is not given', ->
      it 'selects all columns (*)', ->
        BaseModel.findById 123, cbSpy
        expect(BaseModel.findOne).to.have.been.calledWith 'id = $1', [123], cbSpy

