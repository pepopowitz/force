Backbone = require 'backbone'
_ = require 'underscore'
sd = require('sharify').data
Q = require 'bluebird-q'
markdown = require '../../components/util/markdown.coffee'
httpProxy = require 'http-proxy'
Curation = require '../../models/curation.coffee'
Article = require '../../models/article.coffee'
Channel = require '../../models/channel.coffee'
Articles = require '../../collections/articles.coffee'
{ stringifyJSONForWeb } = require '../../components/util/json.coffee'
{ WHITELISTED_VANITY_ASSETS, VANITY_BUCKET, SAILTHRU_KEY, SAILTHRU_SECRET } = require '../../config.coffee'
sailthru = require('sailthru-client').createSailthruClient(SAILTHRU_KEY,SAILTHRU_SECRET)
proxy = httpProxy.createProxyServer(changeOrigin: true, ignorePath: true)

@eoy = (req, res, next) ->
  @curation = new Curation(id: sd.EOY_2016)
  @article = new Article(id: sd.EOY_2016_ARTICLE)
  Q.all([
    @curation.fetch(cache: true)
    @article.fetch(
      cache:  true
      headers: 'X-Access-Token': req.user?.get('accessToken') or ''
    )
  ]).then (result) =>
    @superSubArticles = new Articles

    Q.all(@article.fetchSuperSubArticles(@superSubArticles, req.user?.get('accessToken')))
    .then =>
      res.locals.sd.SUPER_ARTICLE = @article.toJSON()
      res.locals.sd.CURATION = @curation.toJSON()
      @article.set 'channel', new Channel name: 'Artsy Editorial'
      res.locals.jsonLD = stringifyJSONForWeb(@article.toJSONLD())
      res.locals.sd.INCLUDE_SAILTHRU = true
      res.render 'components/eoy/templates/index',
        curation: @curation,
        article: @article,
        superSubArticles: @superSubArticles,
        markdown: markdown

@venice = (req, res, next) ->
  @curation = new Curation(id: sd.EF_VENICE)
  @veniceSubArticles = new Articles
  @videoGuide = new Article(id: sd.EF_VIDEO_GUIDE)
  user = res.locals.sd.CURRENT_USER
  @curation.fetch
    success: (curation) =>
      promises = [
        subscribedToEditorial user.email
        @videoGuide.fetch(
          headers: 'X-Access-Token': req.user?.get('accessToken') or ''
        )
      ]
      if @curation.get('sub_articles').length
        promises.push( @veniceSubArticles.fetch(data: 'ids[]': @curation.get('sub_articles')) )
      Q.all(promises)
      .then =>
        videoIndex = setVideoIndex(curation, req.params.slug)
        if isNaN videoIndex
          return res.redirect 301, '/venice-biennale/toward-venice'
        res.locals.sd.CURATION = curation.toJSON()
        res.locals.sd.VIDEO_GUIDE = @videoGuide.toJSON()
        res.locals.sd.VIDEO_INDEX = videoIndex
        res.render 'components/venice_2017/templates/index',
          videoIndex: videoIndex
          curation: curation
          isSubscribed: @isSubscribed
          sub_articles: @veniceSubArticles?.toJSON()
          videoGuide: @videoGuide
    error: next

@vanity = (req, res, next) ->
  whitelistedAssets = WHITELISTED_VANITY_ASSETS
  return next() unless req.params[0].match whitelistedAssets
  req.headers['host'] = VANITY_BUCKET
  target = 'https://' + VANITY_BUCKET + '.s3.amazonaws.com' + '/' + req.params[0]
  proxy.web req, res, target: target, (err) ->
    res.redirect 301, '/articles' if err

setVideoIndex = (curation, slug) ->
  for section, i in curation.get 'sections'
    if section.slug is slug
      return i

subscribedToEditorial = (email) ->
  Q.Promise (resolve, reject) =>
    sailthru.apiGet 'user', { id: email }, (err, response) ->
      if response.vars?.receive_editorial_email
        @isSubscribed = true
      resolve()
