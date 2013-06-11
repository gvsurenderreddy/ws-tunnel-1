express = require 'express'
Start2Pay = require '../../app/classes/s2p_engine'
GGSPay = require '../../app/classes/ggspay_engine'

module.exports = (compound) ->
	app = compound.app

	app.configure 'development', ->
		app.enable 'log actions'
		app.enable 'env info'
		app.enable 'watch'
		app.use express.errorHandler dumpExceptions: true, showStack: true

		ggs.s2p = new Start2Pay 'gps', '14465114e2b5df9b35.39437087ucmvlyf', 'http://test.start2pay.com/api/', 'http://test.start2pay.com/pay'
		ggs.pay = new GGSPay 'http://188.40.196.69/cgi/user.cgi', 'http://188.40.196.69/cgi/pay/pay.cgi'