load 'application'

action 'fun', ->
	client = compound.ggsClient

	req.session.fun = req.query.enable is 'true'
	req.session.save()

	callback = (sid) ->
		client.write
			client:
				command: 'tofun'
				session: sid

	if req.session.auth
		client.loginUser req.session.auth.login, req.session.auth.password, (json, sid) ->
			callback sid
	else
		client.createSession (sid) ->
			callback sid

	send req.query

action 'lang', ->
	layout 'json'
	req.session.lang = body.language

	req.session.save()

	render
		execute: 'window.location.reload()'