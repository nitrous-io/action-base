process.env.NODE_ENV = 'test'

global.context = global.describe
global.xcontext = global.xdescribe
global.specify = global.it
global.xspecify = global.xit
global.its = global.it
global.xits = global.xit

global.sinon = require 'sinon'
global.chai = require 'chai'
sinonChai = require 'sinon-chai'
global.should = global.chai.should()
global.expect = global.chai.expect
global.assert = global.chai.assert
global.chai.use sinonChai

process.env.SECRET_TOKEN = 'secret_token'

global.actionBase = require '..'

_ = require 'underscore'
pg = require('pg').native

_.extend pg.defaults,
  user:     process.env.TEST_PG_USER || 'action'
  password: process.env.TEST_PG_PASSWORD || 'password'
  host:     process.env.TEST_PG_HOST || 'localhost'
  port:     process.env.TEST_PG_PORT || 5432
  database: process.env.TEST_PG_DATABASE || 'action-base_test'

