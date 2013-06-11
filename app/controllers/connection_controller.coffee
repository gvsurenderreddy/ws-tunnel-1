Parser = require 'xml2json'

###
###
action 'to', ->
	{url, guid} = params
	sock = req.socket

	client = compound.ggsClient ||= new GGSSocket(url)

	connectCallback = ->
		sock.emit 'connectToComplete', guid: guid

	if not client.isConnected
		console.log 'Starting new GGS connection...'

		client.once 'connect', ->
			connectCallback()

		if not client.isConnecting
			client.connect()
	else
		console.log 'Reusing existing GGS connection...'
		connectCallback()

	client.on 'error', ->
		sock.emit 'error'

###
###
action 'data', () ->
	{data, guid} = params
	sock = req.socket
	eventName = "xml-#{guid}"
	session = ggs.session.get req

	try
		client = compound.ggsClient

		subscribeToData = () ->
			# основная точка пересылки входящих данных
			client.on eventName, (json) ->
				sid = json.server?.session || json.server?.system?.guidlink

				findSession = (req, sid) ->
					gameSessions = ggs.gameSessions.get req, []

					for gameSession in gameSessions
						if gameSession.sid is sid
							return gameSession

					return null

				unassociateSession = (req, sid) ->
					gameSessions = ggs.gameSessions.get req, []

					for gameSession, i in gameSessions
						if gameSession.sid is sid
							Logger.debug "Unassociating GGS session #{sid} from game session #{req.sessionID}"

							gameSessions.splice i, 1
							break

				clearCommandTimeout = (req, sid) ->
					gameSession = findSession req, sid

					if gameSession and gameSession.lastCommandTimer
						clearTimeout gameSession.lastCommandTimer
						gameSession.lastCommandTimer = null

				switch json.server.command
					when 'connect' # завершён коннект игры

						Logger.debug "GGS session #{sid} is now associated with game session #{req.sessionID}"
						ggs.gameSessions.add req, new LiveSession sid

					when 'leave'
						clearCommandTimeout req, sid
						unassociateSession req, sid

					when 'bet', 'chance'
						sock.emit 'gameEvent',
							type: json.server.command

					else # если идут любые другие данные, то мы должны отложить разрушение сессии
						if sid
							clearCommandTimeout req, sid

				# запустить отсчёт до разрушения
				if sid
					gameSession = findSession req, sid

					if gameSession
						gameSession.lastCommandTimer = setTimeout () ->
							unassociateSession req, sid

							gameSession.write
								client:
									command: 'leave'
									session: sid
							, (json) ->
								# ответ обрабатывается только здесь ибо идёт через LiveSession::write()
								# пересылаем его флешке
								sock.emit 'sessionTimeout',
									sid: sid
									guid: guid
						, ggs.gameSessionTimeout

				sock.emit 'newData',
					data: Parser.toXml(json),
					guid: guid

		client.once "beforeSend-#{guid}", (json) ->
			if json.client.command is 'connect'
				console.log "Performing XML changes in #{guid}"

				# насильно новая сессия
				json.client.proxy = 'sessioncreate'

				if session
					client.once eventName, (json) ->
						# тут уже будем после command="connect"
						#
						# <server rnd="78216903-590346-2147-1" command="connect" session="135997882122083177028130"  status="ok">
						# 	<system guidcreate="135997882122083177028130" />
						# 	<system guidlink="135997882122083177028130" />
						# 	<user id="-1" cash="1000" type="fun" currency-rate="1.000000" currency-id="" currency-name="" PlayerIndex="5" PlayerGUID="TEST000000000008" Nick="TEST8" Login="TEST000000000008" Date_reg="2013-02-04 11:53:41" Status="player" Lang="ru" denominator="100"  />
						# </server>
						console.log "In after connect / before authorization for #{json.server.rnd}"

						client.once eventName, (funJson) ->
							client.once eventName, (jsonAuth) ->
								# здесь будем после отсылки авторизации
								json.server.user = jsonAuth.server.user

								sock.emit 'newData',
									data: Parser.toXml(json),
									guid: guid

								subscribeToData()

							console.log "Sending authorization params for #{json.server.rnd}..."

							client.write
								client:
									session: json.server.session
									command: 'auth'
									user:
										login: session.login
										password: session.password

								guid

						client.emit eventName, json
				else
					subscribeToData()

		client.write data, guid
	catch error
		sock.emit 'error'