url           = require 'url'
request       = require 'request'
shmock        = require 'shmock'
enableDestroy = require 'server-destroy'
EtcdManager   = require '../../src/services/etcd-manager-service'
Server        = require '../../src/server'

describe 'Deployment Updated', ->
  beforeEach (done) ->
    @logFn = sinon.spy()

    @deployState = shmock()
    enableDestroy @deployState

    @etcd = shmock()
    enableDestroy @etcd

    deployStateUri = url.format {
      protocol: 'http',
      hostname: 'localhost',
      port: @deployState.address().port
    }

    etcdUri = url.format {
      protocol: 'http',
      hostname: 'localhost',
      port: @etcd.address().port
    }

    @etcdClient = {
      set: sinon.stub().yields null
    }

    serverOptions =
      port            : undefined,
      disableLogging  : true
      logFn           : @logFn
      deployStateKey  : 'deploy-state-key'
      deployStateUri  : deployStateUri
      deployClientKey : 'deploy-client-key'
      etcdUri         : etcdUri
      etcdClient      : @etcdClient

    @server = new Server serverOptions

    @server.run =>
      @serverPort = @server.address().port
      done()

  afterEach ->
    @server.destroy()
    @deployState.destroy()
    @etcd.destroy()

  describe 'on PUT /deployments', ->
    describe 'when called with a non-passing build', ->
      beforeEach (done) ->
        options =
          uri: '/deployments'
          baseUrl: "http://localhost:#{@serverPort}"
          headers:
            Authorization: 'token deploy-client-key'
          json:
            tag   : 'v1.0.0'
            repo  : 'the-service'
            owner : 'the-owner'
            build : {
              passing: false
              dockerUrl: 'quay.io/the-owner/the-service:v1.0.0'
            }

        request.put options, (error, @response, @body) =>
          done error

      it 'should return a 204', ->
        expect(@response.statusCode).to.equal 204

      it 'should NOT call etcd set', ->
        expect(@etcdClient.set).to.not.have.been.called

    describe 'when called with a passing build and no dockerUrl', ->
      beforeEach (done) ->
        options =
          uri: '/deployments'
          baseUrl: "http://localhost:#{@serverPort}"
          headers:
            Authorization: 'token deploy-client-key'
          json:
            tag   : 'v1.0.0'
            repo  : 'the-service'
            owner : 'the-owner'
            build : {
              passing: true
            }

        request.put options, (error, @response, @body) =>
          done error

      it 'should return a 204', ->
        expect(@response.statusCode).to.equal 204

      it 'should NOT call etcd set', ->
        expect(@etcdClient.set).to.not.have.been.called

    describe 'when called with a passing build', ->
      beforeEach (done) ->
        options =
          uri: '/deployments'
          baseUrl: "http://localhost:#{@serverPort}"
          headers:
            Authorization: 'token deploy-client-key'
          json:
            tag   : 'v1.0.0'
            repo  : 'the-service'
            owner : 'the-owner'
            build : {
              passing: true
              dockerUrl: 'quay.io/the-owner/the-service:v1.0.0'
            }

        request.put options, (error, @response, @body) =>
          done error

      it 'should return a 204', ->
        expect(@response.statusCode).to.equal 204

      it 'should call etcd set', ->
        expect(@etcdClient.set).to.have.been.calledWith 'the-owner/the-service', 'quay.io/the-owner/the-service:v1.0.0'

