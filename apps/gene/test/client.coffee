benv = require 'benv'
Backbone = require 'backbone'
sinon = require 'sinon'
Gene = require '../../../models/gene'
{ resolve } = require 'path'
{ fabricate } = require 'antigravity'

describe 'GeneView', ->

  before (done) ->
    benv.setup =>
      benv.expose { $: benv.require 'jquery' }
      benv.render resolve(__dirname, '../templates/index.jade'), {
        sd: {}
        gene: new Gene fabricate 'gene'
      }
      Backbone.$ = $
      done()

  after ->
    benv.teardown()

  beforeEach ->
    { GeneView } = mod = benv.require resolve __dirname, '../client/index.coffee'
    mod.__set__ 'mediator', @mediator = { trigger: sinon.stub() }
    mod.__set__ 'ArtistFillwidthList', class @ArtistFillwidthList
      fetchAndRender: sinon.stub()
    sinon.stub Backbone, 'sync'
    @view = new GeneView el: $('body'), model: new Gene fabricate 'gene'

  afterEach ->
    Backbone.sync.restore()

  describe '#initialize', ->

    it 'sets up a share view', ->
      @view.shareView.$el.attr('id').should.equal 'gene-share-buttons'

  describe '#setupArtistFillwidth', ->

    it 'inits a artist fillwidth view', ->
      @view.setupArtistFillwidth()
      Backbone.sync.args[0][2].success [fabricate 'artist', name: 'Andy Foobar']
      @ArtistFillwidthList::fetchAndRender.called.should.be.ok

  describe '#setupFollowButton', ->

    it 'inits a follow button view', ->
      @view.setupFollowButton().model.get('id').should.equal @view.model.get('id')