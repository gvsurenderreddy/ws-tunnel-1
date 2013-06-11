load 'application'

action 'play', ->
	name = req.params.name

	session = ggs.session.get req

	if session
		session.write
			client:
				command: if req.query.fun == '1' then 'tofun' else 'toreal'
			(json) ->
				render
					container: req.query.container
					game: name
	else
		render
			container: req.query.container
			game: name