load 'application'

action 'index', ->
	session = ggs.session.get req

	if not session
		flash 'error', t 'user.not_logged_in'

		redirect path_to.login_page
	else
		session.write
			client:
				command: 'userinfo'

			(json) =>
				console.dir json

				render
					ggs: ggs
					user: json.server.user

action 'update', ->
	session = ggs.session.get req
	layout 'json'

	if not session
		flash 'error', t 'user.not_logged_in'

		render
			redirect: path_to.root
	else
		session.write
			client:
				command: 'update'
				user: body
			(json) ->
				render
					execute: "
						closeActivePopup();
						alert('#{t 'editSuccess'}');
						reloadHeader();
					"