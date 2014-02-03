rewire        = require 'rewire'
benv          = require 'benv'
Backbone      = require 'backbone'
sinon         = require 'sinon'
AuctionLots   = require '../../../../collections/auction_lots'
Artist        = require '../../../../models/artist'
_             = require 'underscore'
{ resolve }   = require 'path'
{ fabricate } = require 'antigravity'

describe 'ArtistView', ->

  before (done) ->
    sinon.stub _, 'defer'
    benv.setup =>
      benv.expose { $: benv.require 'jquery' }
      Backbone.$ = $
      done()

  after ->
    _.defer.restore()
    benv.teardown()

  beforeEach (done) ->
    sinon.stub Backbone, 'sync'
    benv.render resolve(__dirname, '../../templates/index.jade'), {
      sd     : {}
      artist : new Artist(fabricate('artist'))
      sortBy : '-published_at'
    }, =>
      { ArtistView, @init } = mod = benv.requireWithJadeify(
        (resolve __dirname, '../../client/index'), ['artistSort']
      )
      @FillwidthView = sinon.stub()
      @FillwidthView.nextPage = sinon.stub()
      @FillwidthView.render = sinon.stub()
      @FillwidthView.returns @FillwidthView
      mod.__set__ 'FillwidthView', @FillwidthView
      mod.__set__ 'BlurbView', @blurbStub = sinon.stub()
      mod.__set__ 'RelatedPostsView', @relatedPostStub = sinon.stub()
      mod.__set__ 'RelatedGenesView', @genesStub = sinon.stub()
      mod.__set__ 'ArtistFillwidthList', @artistFillwidthView = sinon.stub()
      @view = new ArtistView
        el     : $ 'body'
        model  : new Artist fabricate 'artist'
        sortBy : '-published_at'
      done()

  afterEach ->
    Backbone.sync.restore()

  describe '#initialize', ->

    it 'sets up fillwidth views with collections pointing to for sale and not for sale works', ->
      view1Opts = @FillwidthView.args[0][0]
      view2Opts = @FillwidthView.args[1][0]
      view1Opts.fetchOptions['filter[]'].should.equal 'for_sale'
      view2Opts.fetchOptions['filter[]'].should.equal 'not_for_sale'
      view1Opts.collection.url.should.include '/artworks'
      view2Opts.collection.url.should.include '/artworks'

    it 'sets up the blurb view if there is one', ->
      fixture = """
        <div class='artist-info-section'>
          <div class='artist-blurb'>
            <div class='blurb'></div>
          </div>
        </div>
      """
      @view.$el.html fixture
      @view.setupBlurb()
      viewBlurbOpts = @blurbStub.args[0][0]
      viewBlurbOpts.updateOnResize.should.equal true
      viewBlurbOpts.lineCount.should.equal 6

    it 'sets up the related genes view properly', ->
      viewGeneOpts = @genesStub.args[0][0]
      viewGeneOpts.model.should.equal @view.model

    it 'sets up related artists', ->
      @view.relatedArtistsPage.should.equal 2
      @view.relatedContemporaryPage.should.equal 2

    it 'sets up related posts', ->
      viewRelatedPostOpts = @relatedPostStub.args[0][0]
      viewRelatedPostOpts.numToShow.should.equal 2
      viewRelatedPostOpts.model.should.equal @view.model

  describe 'sorting', ->

    it 'passes the correct sort option into setupArtworks when sorting by Recently Added, and updates the picker', ->
      $fixture = $ """
        <div class="bordered-pulldown-options">
          <a data-sort="-published_at">Recently Added<a>
        </div>
      """
      @view.onSortChange({ currentTarget: $fixture.find('a')})
      @view.sortBy.should.equal '-published_at'
      @view.$el.find('a.bordered-pulldown-toggle').html().should.include 'Recently Added'

    it 'passes the correct sort option into setupArtworks when sorting by Relevancy', ->
      $fixture = $ """
        <div class="bordered-pulldown-options">
          <a data-sort>Relevancy<a>
        </div>
      """
      @view.onSortChange({ currentTarget: $fixture.find('a')})
      @view.sortBy.should.equal ''
      @view.$el.find('a.bordered-pulldown-toggle').html().should.include 'Relevancy'

  describe '#setupRelatedArtists', ->

    it 'renders related artists on sync', ->
      @view.renderRelatedArtists = sinon.stub()
      @view.setupRelatedArtists()
      @view.model.relatedArtists.trigger 'sync'
      @view.renderRelatedArtists.args[0][0].should.equal 'Artists'