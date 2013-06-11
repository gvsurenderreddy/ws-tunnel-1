Crypto = require 'crypto'
Request = require 'request'
QueryString = require 'qs'

module.exports = class Start2Pay
	constructor: (@projectName, @apiKey, @apiPoint, @browserUrl) ->

	hash: (data, algo) ->
		if not (data instanceof Buffer)
			data = new Buffer data

		hash = Crypto.createHash algo
		hash.update data

		return hash.digest 'hex'

	sha512: (data) ->
		return @hash data, 'sha512'

	md5: (data) ->
		return @hash data, 'md5'

	sign: (params) ->
		nounce = Math.round Math.random() * Math.pow(10, 6)

		result =
			p: @projectName
			nounce: nounce

		parts = [
			@projectName,
			nounce
		]

		for key, val of params
			parts.push val

		for key, val of params
			result[key] = val

		result['sig'] = @sha512 @md5(@apiKey) + parts.join ':'

		return result

	execute: (api, paramsAll, callback) ->
		if typeof paramsAll is 'function' and not callback
			callback = paramsAll

		if not paramsAll.signed and not paramsAll.free
			paramsSigned = paramsAll
			paramsFree = {}
		else
			paramsSigned = paramsAll.signed
			paramsFree   = paramsAll.free

		params = @sign paramsSigned

		for key, val of paramsFree
			params[key] = val

		if api[0] is '/'
			api = api.substr 1

		resultUrl = @apiPoint + api
		qs = QueryString.stringify params
		fullUrl = "#{resultUrl}?#{qs}"

		Logger.info "Starting request to S2P for #{api}..."
		Logger.debug 'URL is', resultUrl
		Logger.debug 'Data is', params
		Logger.debug 'Query string is', qs
		Logger.debug 'Full URL is', fullUrl

		Request
			url: fullUrl
		, (error, response, body) ->
			json = null
			Logger.data 'Request to S2P finished: ', body

			try
				json = JSON.parse body

				if json.server_time
					json.server_time = new Date json.server_time
			catch e
				Logger.debug 'S2P has returned invalid JSON'

			if json isnt null
				callback json

	getPayUrl: (sum, currency, invoice, system, success, fail) ->
		params = @sign
			sum: sum
			currency: currency
			invoice: @generateUniqueInvoiceID()
			payment_system: system

		params.custom = [invoice, 'in']

		if success
			params.success_url = success

		if fail
			params.fail_url = fail

		return "#{@browserUrl}?#{QueryString.stringify params}"

	generateUniqueInvoiceID: () ->
		# 1 / 10^5 вероятность попасть в одну и ту же миллисекунду (!) в одну и ту же точку
		# размер bigint'а на стороне s2p
		return "#{new Date().getTime()}#{Math.round Math.random() * Math.pow 10, 5}"