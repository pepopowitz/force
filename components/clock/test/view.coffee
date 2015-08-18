sd = require('sharify').data
benv = require 'benv'
Backbone = require 'backbone'
moment = require 'moment'
sinon = require 'sinon'
path = require 'path'
ClockView = require '../view.coffee'
Sale = require '../../../models/sale'
{ fabricate } = require 'antigravity'

describe 'ClockView', ->

  before (done) ->
    benv.setup =>
      sd.API_URL = 'localhost:3003'

      sd.CURRENT_PATH = ""
      benv.expose { $: benv.require 'jquery' }
      sinon.stub Backbone, 'sync'
      Backbone.$ = $
      @view = new ClockView
        model: new Sale(fabricate('sale'))
        el: $("<div></div>")
      done()

  after ->
    benv.teardown()
    Backbone.sync.restore()

  beforeEach ->
    @clock = sinon.useFakeTimers()

  afterEach ->
    @clock.restore()

  describe '#render', ->

    it 'sets renderClock to call in 1 second intervals', ->
      stub = sinon.stub global, 'setInterval'
      @view.render()
      stub.args[0][0].should.equal @view.renderClock
      stub.args[0][1].should.equal 1000
      stub.restore()

    it 'renders correct time until the sale starts', ->
      @view.model.set
        is_auction: true
        start_at: moment().subtract(1, 'minutes').format()
        end_at: moment().add(3, 'minutes').add(1, 'months').add(1, 'hours').add(1, 'seconds').add(1, 'days').format()

      @view.model.calculateOffsetTimes()
      Backbone.sync.args[0][2].success { time: moment().format() }

      @view.$el.html '<div class="clock-value"></div>'
      @view.render()
      @view.$el.html().should.containEql 'days'
      @view.$el.html().should.containEql 'mos'
      @view.$el.html().should.not.containEql '00'

    it 'excludes months sectoin if sale starts 0 months from now', ->
      @view.model.set
        is_auction: true
        start_at: moment().subtract(1, 'minutes').format()
        end_at: moment().add(3, 'minutes').add(1, 'hours').format()

      @view.model.calculateOffsetTimes()
      Backbone.sync.args[0][2].success { time: moment().format() }

      @view.$el.html '<div class="clock-value"></div>'
      @view.render()
      @view.$el.html().should.containEql 'days'
      @view.$el.html().should.not.containEql 'months'
      @view.$el.html().should.containEql '00'

    it 'removes the register button at the top for open auctions', ->
      @view.model.set
        start_at: new Date(2000, 10, 10).toString()
        end_at: new Date(2015, 10, 10).toString()
      @view.render()
      @view.$el.html().should.not.containEql 'Register to Bid'
