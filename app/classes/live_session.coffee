{EventEmitter} = require 'events'
Parser = require 'xml2json'
Guid = require 'guid'


module.exports = class LiveSession extends EventEmitter
	constructor: (session, params = {}) ->
		@pingCommand =
			client:
				command: 'ping'

		if typeof session is 'string'
			@sid = session
		else
			@sid = session.server.session

		@login = params.login
		@password = params.password
		@lastUser = params.lastUser

		@on 'sessionlost', (json) =>
			Logger.info "Session lost for #{@sid}. Recreating..."

			@stop()

			@write
				client:
					lang: 'ru'
					verid: 'WIN 10,1,52,14'
					command: 'connect'
				, (json) =>
					@auth (json) =>
						Logger.info "Recreated session for #{@sid}. New SID: #{json.server.session}"

						@sid = json.server.session
						@lastUser = json.server.user

						@start()

		# не стартовать для игровых сессий
		if @login isnt null
			@start()

	auth: (callback) ->
		@write
			client:
				command: 'auth'
				user:
					login: @login
					password: @password
		, (json) =>
			callback json

	write: (json, callback, guid = Guid.raw()) ->
		if typeof json is 'string'
			json = Parser.toJson json

		client = ggs.client
		json.client.session = @sid

		client.once "xml-#{guid}", (json) =>
			if json.server.user and json.server.user.cash_real isnt undefined
				@lastUser = json.server.user

			callback json

		client.write json, guid

	start: () ->
		console.log "Starting the live session for #{@sid}..."

		@timer = setInterval () =>
			@write @pingCommand, (json) =>
				console.log "Live session ping reply for #{@sid}"
				console.dir json

				@emit json.server.status, json
		,
		15000

	stop: () ->
		clearInterval @timer
		@timer = null

	userinfo: (callback) ->
		@write
			client:
				command: 'userinfo'
		, callback
