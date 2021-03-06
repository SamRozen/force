#
# Common bootstrap code that needs to be run on the client-side.
#
# Don't go too wild here, we want to keep this minimal and light-weight because it could be
# included across most apps and any uncessary bloat should be avoided.
#

require 'jquery'
Backbone = require 'backbone'
Backbone.$ = $

_ = require 'underscore'
FastClick = require 'fastclick'
RavenClient = require 'raven-js'
sd = require('sharify').data
Cookies = require 'cookies-js'
{ parse } = require 'url'
HeaderView = require './client/header_view.coffee'
doc = window.document
sharify = require('sharify')
CurrentUser = require '../../models/current_user.coffee'
# The conditional check below is for tests not to fail.
# window.matchMedia is not recognized by specs
if (window && window.matchMedia)
  globalClientSetup = require '../../lib/global_client_setup.coffee'

module.exports = ->
  # Add the Gravity XAPP or access token to all ajax requests
  $.ajaxSettings.headers = {
    "X-XAPP-TOKEN": sd.ARTSY_XAPP_TOKEN
    "X-ACCESS-TOKEN": sd.CURRENT_USER?.accessToken
  }

  # Setup inquiry referrer tracking
  referrerIsArtsy = if sd.APP_URL then doc.referrer.match(parse(sd.APP_URL).host)? else false
  unless referrerIsArtsy
    Cookies.set 'inquiry-referrer', doc.referrer
    Cookies.set 'inquiry-session-start', location.href

  # removes 300ms delay
  if FastClick.attach
    FastClick.attach document.body

  setupErrorReporting()
  setupHeaderView()
  # TODO: Look into why this fails.
  # syncAuth()
  checkForAfterSignUpAction()
  if globalClientSetup
    globalClientSetup()

  # Setup jQuery plugins
  require 'jquery-on-infinite-scroll'

ensureFreshUser = (data) ->
  return unless sd.CURRENT_USER
  attrs = [
    'id',
    'type',
    'name',
    'email',
    'phone',
    'lab_features',
    'default_profile_id',
    'has_partner_access',
    'collector_level'
  ]
  for attr in attrs
    if (data[attr] or sd.CURRENT_USER[attr]) and not _.isEqual data[attr], sd.CURRENT_USER[attr]
      RavenClient.captureException("Forced to refresh user", { extra: { attr: attr, session: sd.CURRENT_USER[attr], current: data[attr] } } )
      $.ajax('/user/refresh').then ->
        setTimeout  (=> window.location.reload()), 500

syncAuth = module.exports.syncAuth = ->
  # Log out of Microgravity if you're not logged in to Gravity
  if sd.CURRENT_USER
    $.ajax
      url: "#{sd.API_URL}/api/v1/me"
      success: ensureFreshUser
      error: ->
        $.ajax
          method: 'DELETE'
          url: '/users/sign_out'
          complete: ->
            window.location.reload()

setupErrorReporting = ->
  RavenClient.config(sd.SENTRY_PUBLIC_DSN).install()

# Show search button on focusing the search bar
setupHeaderView = ->
  new HeaderView
    el: $('#main-header')

operations =
  save: (currentUser, objectId) ->
    currentUser.initializeDefaultArtworkCollection()
    currentUser.defaultArtworkCollection().saveArtwork objectId

  follow: (currentUser, objectId, kind) ->
    kind? and currentUser.follow(objectId, kind)

  editorialSignup: (currentUser) ->
    fetch "/signup/editorial",
      method: "POST"
      body: JSON.stringify email: currentUser.get("email")
      headers: new Headers 'Content-Type': 'application/json'
      credentials: 'same-origin'

checkForAfterSignUpAction = ->
  afterSignUpAction = Cookies.get 'afterSignUpAction'
  @currentUser = CurrentUser.orNull()
  if afterSignUpAction
    return unless @currentUser
    { action, objectId, kind } = JSON.parse(afterSignUpAction)

    ops = operations[action]
    ops and ops(@currentUser, objectId, kind)

    Cookies.expire 'afterSignUpAction'
