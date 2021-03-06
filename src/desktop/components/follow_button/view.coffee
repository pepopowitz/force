_ = require 'underscore'
Backbone = require 'backbone'
mediator = require '../../lib/mediator.coffee'
{ modelNameAndIdToLabel } = require '../../lib/analytics_helpers.coffee'
ArtistSuggestions = require './artist_suggestions.coffee'
{ ARTIST_PAGE_CTA_ENABLED } = require('sharify').data
{ openAuthModal } = require '../../lib/openAuthModal'
{ ModalType } = require "../../../v2/Components/Authentication/Types"
{ Intent } = require "@artsy/cohesion"

module.exports = class FollowButton extends Backbone.View

  events:
    'click': 'toggle'
    'touchstart': () -> @$el.removeClass "no-touch"

  initialize: (options) ->
    {
      @following,
      @notes,
      @modelName,
      @href,
      @context_page,
      @context_module,
      @hideSuggestions
    } = options

    @label = if options.label then options.label else "#{@modelName}s"

    return unless @following

    throw new Error('Requires @modelName') unless @modelName

    @listenTo @following, "add:#{@model.id}", @change
    @listenTo @following, "remove:#{@model.id}", @change
    @$el.addClass "no-touch"

    if @modelName is 'artist' and @following and not @hideSuggestions
      @artistSuggestionsView = new ArtistSuggestions
        model: @model
        el: @$el
        following: @following
        context_page: @context_page

    @change()

  change: ->
    state = if @following.isFollowing(@model.id) then 'following' else 'follow'
    @$el.attr 'data-state', state

  getIntent: ->
    switch @modelName
      when "artist" then Intent.followArtist
      when "profile" then Intent.followPartner
      when "partner" then Intent.followPartner
      when "gene" then Intent.followGene

  toggle: (e) ->
    @trigger 'click'

    unless @following
      mediator.trigger 'clickFollowButton'
      return if ARTIST_PAGE_CTA_ENABLED
      openAuthModal(ModalType.signup, {
        copy: "Sign up to follow #{@label}"
        contextModule: @context_module
        destination: @href
        afterSignUpAction: {
          kind: @modelName.toLowerCase()
          action: 'follow'
          objectId: @model.id
        }
        intent: @getIntent()
      })
      return false

    # remove null values
    analyticsOptions = _.pick
      entity_slug: @model.id
      entity_id: @model.get('_id')
      context_page: @context_page
      context_module: @context_module
    , _.identity

    if @following.isFollowing @model.id
      @following.unfollow @model.id
      mediator.trigger 'follow-button:unfollow', @$el, @model
      @trigger 'unfollowed'
      window.analytics.track("Unfollowed #{@modelName}", analyticsOptions)
    else
      @following.follow @model.id, notes: (@notes or @analyticsFollowMessage)
      $('.artist-suggestion-popover').remove()
      if @artistSuggestionsView?
        @artistSuggestionsView.renderSuggestedArtists()

      # Delay label change
      @$el.addClass 'is-clicked'
      setTimeout (=> @$el.removeClass 'is-clicked'), 1500
      mediator.trigger 'follow-button:follow', @$el, @model
      @trigger 'followed'
      window.analytics.track("Followed #{@modelName}", analyticsOptions)

    false
