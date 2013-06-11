Request = require 'request'
QueryString = require 'qs'
Parser = require 'xml2json'


module.exports = class GGSPay
	constructor: (@userPoint, @payPoint) ->

	createPayment: (userId, sum, currency, paySystem, callback) ->
		query =
			cm: 'paycreate'
			system: if ~['webmoney', 'creditcard', 'wire', 'sms', 'moneta', 'yandex'].indexOf(paySystem) then paySystem else 'gate'
			userid: userId
			amount: sum
			currency: currency

		url = "#{@userPoint}?#{QueryString.stringify query}"

		Logger.debug 'GGS payment create url is:', url

		Request
			url: url
		, (error, response, body) ->
			Logger.debug 'GGS payment create response is:', body

			[status, id] = body.split ':'

			callback id

	markPayment: (id, status, sum, currency, callback) ->
		if status is 'success'
			status = 'OK'

		query =
			cm: 'result'
			status: status
			amount: sum
			currency: currency
			PAYGUID: id

		url = "#{@payPoint}?#{QueryString.stringify query}"

		Logger.debug 'GGS pay mark url is:', url

		Request
			url: url
		, (error, response, body) ->
			Logger.debug 'GGS pay mark response is:', body

			[status, id] = body.split ':'

			callback status, id

	getHistory: (userId, login, password, callback, type = 'real') ->
		query =
			cm: 'historycash'
			userid: userId
			login: login
			password: password
			type: type

		Logger.debug "Getting GGS payment history for #{userId}..."

		Request
			url: @userPoint
			qs: query
		, (error, response, body) ->
			json = Parser.toJson body,
				object: true
				coerce: false
				reversible: true

			Logger.debug "GGS payment history for #{userId} is", json

			callback json.server.cash