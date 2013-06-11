#external_connect_Init = ->
#	1
#
#getSwf = -> $('#swf').get(0)
#
#external_connect_Event = (currentState, targetState, code, data) ->
#	switch code
#		when 'state' then ->
#			getSwf().Event('state', 'show&game=AcesAndFaces&playerguid=TEST1000')

window.config = config =
	prefix: 'flash_box',
	baseUrl: 'http://188.40.196.69/ggs/',
	dictList: 'profiles/test_69/dict_ext.lst',
	dictionaries: 'profiles/test_69/connect.dic',
	swfWidth: 500
	swfHeight: 375,
	swfVer: '10.0.0',
	debug: true

config2 =
	prefix: 'flash_box_2',
	baseUrl: 'http://188.40.196.69/ggs/',
	dictList: 'profiles/test_69/dict_ext.lst',
	dictionaries: 'profiles/test_69/connect.dic',
	swfWidth: 500
	swfHeight: 375,
	swfVer: '10.0.0',
	debug: true

config3 =
	prefix: 'external_connect_3',
	baseUrl: 'http://public.ggsexternalgames.com/140_flash/',
	dictList: 'profiles/ggsaffiliates/dict_public_network.lst',
	dictionaries: 'http://ggsdemoplay.com/external_connect/connect.dic',
	swfWidth: 500
	swfHeight: 375,
	swfVer: '10.0.0',
	debug: true

config4 =
	prefix: 'external_connect_4',
	baseUrl: 'http://public.ggsexternalgames.com/140_flash/',
	dictList: 'profiles/ggsaffiliates/dict_public_network.lst',
	dictionaries: 'http://ggsdemoplay.com/external_connect/connect.dic',
	swfWidth: 500
	swfHeight: 375,
	swfVer: '10.0.0',
	debug: true

class Guid
	@prefix = new Date().geFtTime() % Math.pow(10, 8)
	@random1 = Math.round Math.random() * Math.pow(10, 6)
	@random2 = Math.round Math.random() * Math.pow(10, 4)
	@value = 0
	@next = ->
		"#{@prefix}-#{@random1}-#{@random2}-#{++@value}"

$ ->

	initV = (config, onReady, onLogout, onPercent) ->
		socket = io.connect window.location.hostname, 'force new connection': no
		guid = Guid.next()
		gameName = null

		originalOnReadyFn = onReady
		originalOnLogoutFn = onLogout

		onReady = () ->
			originalOnReadyFn.call this, gameName

		onLogout = (name, reason) ->
			originalOnLogoutFn.call this, gameName, reason

		config.onConnect = (url, mode, callback) ->
			if mode is 'sock'
				socket.emit 'connectTo',
					url: url
					guid: guid

				socket.on 'connectToComplete', (data) ->
					if data.guid is guid
						socket.removeListener 'connectToComplete', arguments.callee
						callback true, new Date().getTime()

		config.onData = (systemGuid, data, callback) ->
			socket.on 'newData', ({data: data, guid: responseGuid}) ->
				if responseGuid is guid
					socket.removeListener 'newData', arguments.callee
					callback true, data

			socket.emit 'sendData',
				data: data,
				guid: guid

		socket.on 'sessionTimeout', (data) ->
			socket.removeAllListeners()

			$('.close-game').data 'logging-off', true
			navigateTo '/'

		socket.on 'gameEvent', (data) ->
			lastAction "Игровое событие #{data.type}."

		viewer = new Viewer config, config.prefix, ->
			onReady()
		, (name, reason) ->
			socket.removeAllListeners()
			onLogout(name, reason)
		, (perc) ->
			onPercent(perc)

		originalStartFn = viewer.start

		viewer.start = (name) ->
			gameName = name
			originalStartFn.apply viewer, arguments

		return viewer

	window.reinitV = () ->
		window.v = v = initV config, (name) ->
			v.done()
			lastAction "Загружена игра #{name}."
		, (name, reason) ->
			$('.close-game').data 'logging-off', true
			v.doneLogout()

			if reason
				lastAction "Вышли из игры #{name} [ошибка загрузки или прерывание]."
			else
				lastAction "Вышли из игры #{name}."

			navigateTo '/'
		, (perc) ->
			bar = $('.bar')
			bar.width("#{perc}%")

			if perc is 100
				setTimeout ->
					$('.progress').hide()
					adjustGameSize()

					setTimeout ->
						$('.game object').removeClass 'do-not-show'
					, 400
				, 100

#	v2 = initV config2, ->
#		v2.done()
#
#	v2.start 'AcesAndFaces', 'TEST1002'

#	v = initV(config2)
#	v.start 'div_flash_box_2', 'DeucesWildUrartu', 'TEST1002'
#
#	v = initV(config3)
#	v.start 'div_flash_box_3', 'Alice', 'TEST1003'
#
#	v = initV(config4)
#	v.start 'div_flash_box_4', 'BananaSplash', 'TEST1004'