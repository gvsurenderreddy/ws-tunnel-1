Guid = require 'guid'
sha1 = require 'sha1'
GGSSocket = require '../app/classes/ggs_socket'
YAML = require 'js-yaml'
FS = require 'fs'

global.LiveSession = require '../app/classes/live_session'
global.Logger = require 'winston'

try
	config = require './params'
catch e
	config =
		facebook:
			url: 'http://localhost:3000/login/facebook'

Logger.cli()

ensureFlash = (req) ->
	req.session.flash ||= {}
	req.session.flash['error'] ||= []

#
module.exports = (compound) ->
	class Container
		constructor: () ->
			@data = []

		get: (req, def = null) ->
			subContainer = @data[req.sessionID]

			if subContainer is undefined
				subContainer = @data[req.sessionID] = def

			return subContainer

		set: (req, val) ->
			@data[req.sessionID] = val

		add: (req, val) ->
			container = @get req, []
			container.push val

			return container

	global.createLiveSession = (req, sid, login, password, json) ->
		console.log 'Creating live session...'

		session = new LiveSession sid,
			login: login
			password: password
			lastUser: json.server.user

		ggs.session.set req, session

		return session

	express = require 'express'
	passport = require 'passport'

	LocalStrategy = require('passport-local').Strategy
	FacebookStrategy = require('passport-facebook').Strategy

	app = compound.app

	app.configure ->
		app.use(compound.assetsCompiler.init());
		app.set 'view engine', 'jade'
		app.set 'view options', complexNames: true
		app.enable 'coffee'

		app.set 'cssEngine', 'less'

		app.use express.static(app.root + '/public', maxAge: 86400000)
		app.use express.bodyParser()
		app.use express.cookieParser 'secret'
		app.use express.session secret: 'secret'
		app.use express.methodOverride()

		app.use passport.initialize()
		app.use passport.session()

		app.set 'defaultLocale', 'ru'

		app.use app.router

		if process.env['NODE_ENV'] isnt undefined
			app.set 'env', process.env['NODE_ENV']

		exts = require '../node_modules/compound/lib/controller-extensions'
		origLayoutFn = exts.layout

		exts.layout = () ->
			console.log '### In proxy layout function'
			origLayoutFn.apply this, arguments

	passport.use new LocalStrategy
		usernameField: 'LoginForm[login]'
		passwordField: 'LoginForm[password]'
		passReqToCallback: yes

		(req, username, password, done) ->
			client = compound.ggsClient

			client.createSession (sid) ->
				guid = Guid.raw()
				eventName = "xml-#{guid}"

				client.once eventName, (json) ->
					if json.server.status is 'fail'
						ensureFlash req

						msg = "Неверный #{json.server.$t}"
						req.session.flash['error'].push msg

						done null, false, message: msg
					else
						createLiveSession req, sid, username, password, json

						done null, username

				client.write
					client:
						session: sid
						command: 'auth'
						user:
							login: username
							password: password

					guid

	passport.use new FacebookStrategy
		clientID: '313909895396540'
		clientSecret: '0cbad11c357286ac5673f9bd9978a027'
		callbackURL: config.facebook.url
		passReqToCallback: yes

		(req, accessToken, refreshToken, profile, done) ->
			console.dir profile

			id = profile.id
			gender = if profile.gender is 'male' then 'man' else 'woman'
			date = profile.user_birthday
			nick = profile.username
			login = "#{profile.id}_facebook"
			lang = if profile.locale is 'en_US' then 'en' else 'ru'
			[{value: email}] = profile.emails
			password = sha1 "#{id}_#{email}_a58ca39f637bff955f2c88ef737f02b1" # слабовато

			client = compound.ggsClient

			client.loginUser login, password, (json) ->
				if json.server.status isnt 'fail'
					done null, login
				else
					client.registerUser
						gender: gender
						date: date
						nick: nick
						login: login
						lang: lang
						email: email
						password: password

						(json) ->
							if json.server.status is 'fail'
								ensureFlash(req)

								msg = if json.server.$t then "Неверный #{json.server.$t}" else 'Неверные данные'
								req.session.flash['error'].push msg

								done null, false, message: msg
							else
								req.session.auth =
									login: login
									password: password

								req.session.save()

								done null, login


	passport.serializeUser (user, done) ->
		done null, user


	passport.deserializeUser (id, done) ->
		done null, id


	# тут
	compound.ggsClient ||= new GGSSocket 'socket://188.40.196.69:8777'

	global.ggs =
		session: new Container()
		gameSessions: new Container()
		client: compound.ggsClient
		games: {}
		gameSessionTimeout: 1000 * 60 * 10
		t: () ->
			compound.t.apply compound, arguments

	FS.readFile 'config/games.yml', 'utf-8', (error, data) ->
		allData = YAML.load data

		for category in allData
			for categoryName, gamesData of category
				ggs.games[categoryName] = []

				if gamesData
					categoryEnabled = true
					unknownIcon = false
					newContainer = false

					for gameData in gamesData
						switch gameData
							when 'disabled'
								categoryEnabled = false
								continue
							when 'unknown-icon'
								unknownIcon = true
								continue
							when 'new-container'
								newContainer = true
								continue

						game = gameData

						if typeof gameData is 'string'
							game =
								name: gameData

						if not game.id
							game.id = game.name.split(' ').join ''

						if not game.icon
							if unknownIcon is false
								game.icon = "#{(part.toLowerCase() for part in game.name.split ' ').join '-'}.png"
							else
								game.icon = 'unknown.png'

						if game.enabled is undefined
							if categoryEnabled is false
								game.enabled = false
							else
								game.enabled = true

						if newContainer
							game.container = '/gpsflash/'

						ggs.games[categoryName].push game

	if not compound.ggsClient.isConnected
		compound.ggsClient.connect()