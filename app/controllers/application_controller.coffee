YAML = require('js-yaml')

#before 'protect from forgery', ->
#	protectFromForgery '9068e37dc8592098ee83eba23599651204b84f55'

before 'apply layout', ->
	if req.xhr or req.query.xhr
		if req.query.json
			layout 'json'
			res.set 'Content-Type', 'application/json'
		else
			layout('modal')

	next()


@title = 'WS'

action 'index', ->
	render
		gamesList: ggs.games
		session: ggs.session.get req

action 'register', ->
	console.dir User
	render
		user: new User()

action 'header', ->
	layout null
	render '../layouts/header'