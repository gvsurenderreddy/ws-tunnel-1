# совершенно ебанутый способ включения встроенных локалей у MessageFormat

MessageFormat = require('messageformat')

localeName = compound.app.settings.defaultLocale
localeFile = "./node_modules/messageformat/locale/#{localeName}.js"
localeFileContent = (require 'fs').readFileSync localeFile, 'utf-8'
localeFileScript = (require 'vm').createScript localeFileContent

localeFileScript.runInNewContext
	MessageFormat: MessageFormat

MessageFormat = new MessageFormat localeName
MessageFormat.variants = {}

for mfKey, mfVal of t 'formats'
	console.dir mfVal
	MessageFormat.variants[mfKey] = MessageFormat.compile mfVal

calculatePaymentSum = (sum, max, rate) ->
	# max будет в запрашиваемой валюте а sum в конверченной
	max = max / rate

	paymentsCount = Math.floor sum / max
	paymentSum    = max.toFixed 2
	paymentReminder = (sum - paymentSum * paymentsCount).toFixed 2

	return {
		count: paymentsCount
		sum: paymentSum,
		reminder: paymentReminder
	}

load 'application'

action 'index', ->
	query = req.query
	isExternal = false

	if query.user_id
		isExternal = true
		layout 'external_payment'

	ggs.s2p.execute 'payinmethods/list', (data) ->
#		ggs.s2p.execute 'currencies/list', (currenciesData) ->
#			currencies = []

#			for currency, usdRate of currenciesData.currencies
#				currencies.push currency

			render (if isExternal then 'index-external' else 'index'),
				userId: query.user_id
				title: 'Пополнение баланса'
				systems: data.payinmethods
#				currencies: currencies

action 'history', ->
	session = ggs.session.get req

	if not session
		send
			html: 'Вы не залогинены.'
			redirect: '/'
	else
		user = session.lastUser

		ggs.pay.getHistory user.id, session.login, session.password, (payments) ->
			if not payments.length
				payments = []

			render
				payments: payments

action 'add', ->
	layout 'json'

	if not body.user_id
		session = ggs.session.get req

		if not session
			send
				html: 'Вы не залогинены.'
				redirect: '/'

		ggs.pay.createPayment session.lastUser.id, body.sum * 100, body.currency, body.payment_system, (invoiceId) ->
			render
				redirect: ggs.s2p.getPayUrl body.sum, body.currency, invoiceId, body.payment_system
	else
		port = 3000 # TODO

		ggs.pay.createPayment body.user_id, body.sum * 100, body.currency, body.payment_system, (invoiceId) ->
			url = ggs.s2p.getPayUrl body.sum, body.currency, invoiceId, body.payment_system, "http://#{req.host}:#{port}/payment_success?external=1", "http://#{req.host}:#{port}/payment_failure?external=1"

			render
				redirect: url
				title: 'Перенаправление...'



action 's2pCallback', ->
	query = req.query
	Logger.data 'S2P pushed a callback data:', query

	# TODO: тут валидация ответа, удостовериться, что это именно s2p

	if query.custom
		[invoiceId, type] = query.custom

		sign = if type is 'in' then 1 else -1

		ggs.pay.markPayment invoiceId, query.status, sign * query.sum * 100, query.currency, (status, details) ->
			Logger.info "GGS payment #{query.invoice} was marked as:", arguments
	else
		Logger.error "Wrong s2p data! There must be custom fields"

	send 'OK'

action 'paymentFailure', ->
	if req.query.external isnt '1'
		flash 'error', 'Не получилось провести платёж.'
		redirect path_to.root
	else
		render
			title: 'Не получилось провести платёж'

action 'paymentSuccess', ->
	if req.query.external isnt '1'
		flash 'info', 'Платёж проведён успешно!'

		session = ggs.session.get req

		if session
			session.userinfo (json) ->
				redirect path_to.root
		else
			redirect path_to.root
	else
		layout 'external_payment'

		render
			title: 'Платёж проведён успешно'

action 'withdraw', ->
	LANG = req.session.lang || 'ru'
	session = ggs.session.get req

	if not session
		layout 'external_payment'

		user_id = req.query.user_id || body.user_id

		if user_id
			session =
				lastUser:
					cash_real: req.query.max
					id: user_id
		else
			redirect path_to.root

	sum = body.sum || req.query.sum || 50
	system = body.payment_system || req.query.payment_system
	currency = body.currency || req.query.currency

	ggs.s2p.execute 'payoutmethods/list',
		sum: sum
		currency: 'RUB'
		, (data) ->
			description = ''
			methods = data.payoutmethods

			methods.forEach (elem, index) ->
				if elem.code is system and elem.currency is currency
					selectedSystem = elem

					if selectedSystem
						rate = sum / selectedSystem.sum

						if selectedSystem.max_sum > 0
							details = calculatePaymentSum selectedSystem.sum, selectedSystem.max_sum, rate

							description = MessageFormat.variants.payout
								paymentsCount: details.count
								paymentSum: details.sum
								paymentCurrency: currency

							if details.reminder > 0
								description = "#{description} + #{ggs.t('payoutReminder', LANG).replace '%', details.reminder} #{selectedSystem.currency}"
						else
							details = calculatePaymentSum selectedSystem.sum, selectedSystem.sum * rate, rate

							description = "#{ggs.t('payoutReminder', LANG).replace '%', details.sum} #{selectedSystem.currency}"

			render
				title: 'Заявка на вывод денег'
				session: session
				methods: methods
				description: description
				sum: sum
				selectedCurrency: currency
				selectedSystem: system

action 'withdrawSubmit', ->
	layout 'json'
	session = ggs.session.get req
	{currency, sum, payment_system, requisite} = body
	isExternal = false

	if not session
		if body.user_id
			isExternal = true

			session =
				lastUser:
					id: body.user_id
		else
			redirect path_to.root

	ggs.s2p.execute 'payoutmethods/list',
		sum: sum
		currency: 'RUB'
	, (data) ->
		data.payoutmethods.forEach (system) ->
			if system.code is payment_system and system.currency is currency
				payouts = []
				rate = sum / system.sum

				if system.max_sum > 0
					count = Math.floor sum / system.max_sum

					for i in [1..count]
						payouts.push system.max_sum

					reminder = (sum - count * system.max_sum).toFixed 2

					if reminder > 0
						payouts.push parseFloat reminder
				else
					payouts.push parseFloat sum

				payoutsCounter = 0

				for payout in payouts
					ggs.pay.createPayment session.lastUser.id, -sum * 100, currency, payment_system, (invoiceId) ->
						ggs.s2p.execute 'payouts/add',
							signed:
								payment_system: system.code
								sum: payout
								currency: 'RUB'
								out_currency: currency
								invoice: ggs.s2p.generateUniqueInvoiceID()
								requisite: requisite
							free:
								custom: [invoiceId, 'out']
						, (data) -> # присылает пустой ответ либо ошибку (?)
							payoutsCounter++

							# ждать всех остальных
							if payoutsCounter == payouts.length
								text = t 'payout.requestAccepted'

								if not isExternal
									render
										execute: """
											closeActivePopup();
											alert('#{text}');
									"""
								else
									layout 'external_payment'

									send 'Заявка на вывод принята'