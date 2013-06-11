Guid = require 'guid'
Url = require 'url'
Parser = require 'xml2json'

{Socket} = require 'net'
{EventEmitter} = require 'events'


###
###
module.exports = class extends EventEmitter
	constructor: (@host, @port) ->
		@isConnected = no
		@isConnecting = no

		if @host and not @port
			parsed = Url.parse (if not ~@host.indexOf '//' then 'socket://') + @host

			@host = parsed.hostname
			@port = parsed.port

	parseXML: (text, callback) ->
		Logger.verbose 'Parsing XML...'

		process.nextTick =>
			json = Parser.toJson text,
				object: true
				coerce: false
				reversible: true

			Logger.debug "XML has been parsed into JSON: #{JSON.stringify json}"

			callback json

	connect: ->
		@isConnecting = yes

		@socket?.end()

		@socket = new Socket()
		@socket.setKeepAlive true

		@buffer = new Buffer 0

		@socket.on 'connect', =>
			Logger.info 'Connected to GGS'

			@isConnected = yes
			@isConnecting = no
			@emit 'connect'

		@socket.on 'error', (error) =>
			Logger.error error

		@socket.on 'data', (data) =>
			pos = 0

			@buffer = Buffer.concat [@buffer, data]

			for value, i in @buffer
				# разделяем по \0 из XMLSocket
				if value is 0
					portion = @buffer.slice pos, i
					pos = i + 1

					if i is @buffer.length - 1
						@buffer = new Buffer 0  # пришло ровно нужное количество данных в одном буфере

					# делаем что-то с нужными данными
					decoded = portion.toString 'utf8'
					Logger.data "Data received from GGS: #{decoded}"

					process.nextTick =>
						@emit 'data', decoded

				else if i is @buffer.length - 1 and pos is not 0 # чтобы не резать уже готовый буфер
					@buffer = @buffer.slice pos # накапливаем незавершённые данные

		@socket.on 'close', =>
			@isConnected = no
			@isConnecting = no

			Logger.info 'Disconnected from GGS. Reconnecting...'

			@emit 'close'

			setTimeout () =>
				@socket.connect @port, @host
			, 1000

		@on 'data', (data) =>
			@parseXML data, (json) =>
				guid = json.server.rnd

				@emit 'xml', json, guid

		@on 'xml', (xml, guid) =>
			@emit 'xml-' + guid, xml

		Logger.info "Connecting to GGS #{@host}:#{@port}..."

		# Коннектим.
		@socket.connect @port, @host

	write: (data, guid) ->
		if data isnt null
			if typeof data is 'string'
				Logger.verbose "String data for GGS: #{data}"

				@parseXML data, (json) =>
					if not json.error
						# каждый может подписаться и изменить данные, которые мы отсылаем
						@emit "beforeSend-#{guid}", json

						json.client.rnd = guid # заменяем GUID на наш собственный (от клиента)

						# указание работы именно внутри отдельных сессий вне зависимости от контекста коннекта
						if not json.client.proxy
							if json.client.command is 'connect'
								json.client.proxy = 'sessioncreate'
							else
								json.client.proxy = 'session'

						string = Parser.toXml json # сериализуем обратно

						Logger.data "Data is being sent to GGS: #{string}"

						@socket.write string
						@socket.write '\0'
					else
						@emit 'ggsError', json.error?.throw

			else if data instanceof Array
				for piece in data
					@write piece, guid

			else # сериализуем JSON в XML
				Logger.debug "JSON data for GGS: #{JSON.stringify data}"

				@write Parser.toXml(data), guid

	createSession: (callback) ->
		guid = Guid.raw()
		eventName = "xml-#{guid}"

		@once eventName, (json) ->
			callback json.server.session, guid, eventName

		@write
			client:
				lang: 'ru'
				verid: 'WIN 10,1,52,14'
				command: 'connect'
				proxy: 'sessioncreate'

			guid

	registerUser: (user, callback) ->
		@createSession (sid, guid, eventName) =>
			@once eventName, (json) ->
				callback json, guid, eventName

			for prop, val of user
				if not val
					delete user[prop]

			@write
				client:
					session: sid
					command: 'register'
					user: user

				guid

	loginUser: (login, password, callback) ->
		@createSession (sid, guid, eventName) =>
			@once eventName, (json) ->
				callback json, guid, eventName

			@write
				client:
					session: sid
					command: 'auth'
					user:
						login: login
						password: password

				guid