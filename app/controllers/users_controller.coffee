Guid = require 'guid'

client = compound.ggsClient

load 'application'

before 'load user', ->
	User.find params.id, (err, user) =>
		if err
			redirect path_to.users
		else
			@user = user
			next()
, only: ['show', 'edit', 'update', 'destroy']

action 'new', ->
	@user = new User
	@title = 'New user'
	render()

action 'create', ->
	error = null

	layout 'json'

	User.create body.User, (err, user) =>
		if err
			@user = user
			@title = 'New user'
			render 'new'
		else
			client.registerUser user.toObject(), (json) ->
				if json.server.status is 'fail'
					error = "Неверное поле #{json.server.$t}"

					render
						error: error
				else
					session = createLiveSession req, json.server.system.guidlink, user.login, user.password, json

					layout 'json'

					render
						execute: """
							closeActivePopup();
							reloadHeader();

							if (!inGame())
								reloadCurrentLocation();
						"""

action 'login', ->
	error = null

	if req.query.wrongLogin
		error = 'Неверный логин.'

	if req.query.wrongPassword
		error = 'Неверный пароль.'

	if req.query.wrongData
		error = 'Неверный логин или пароль.'

	render
		error: error
		form: new LoginForm

action 'loginResult', ->
	session = ggs.session.get req
	layout 'json'

	render
		execute: """
			closeActivePopup();
			reloadHeader();

			lastAction('Залогинились в системе под пользователем #{session.login}.');

			if (!inGame())
				reloadCurrentLocation()
		"""

action 'logout', ->
	session = ggs.session.get req

	session.write
		client:
			command: 'logout'
		(json) ->
			req.session.destroy()
			redirect path_to.root