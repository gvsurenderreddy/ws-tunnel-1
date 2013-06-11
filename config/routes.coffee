passport = require 'passport'

exports.routes = (map) ->
	map.resources 'users'

	# Generic routes. Add all your routes below this line
	# feel free to remove generic routes

	map.get 'login', 'users#login'
	map.post 'login', 'users#loginResult', passport.authenticate('local',
		failureRedirect: '/login?wrongData=1'
	), as: 'login_page'

	map.get 'logout', 'users#logout'

	map.get 'login/facebook', 'users#loginResult', passport.authenticate('facebook', successRedirect: '/', failureRedirect: '/register', scope: ['email', 'user_birthday']), as: 'login_page_fb'

	map.get 'register', 'users#new'
	map.get 'profile', 'profile#index'
	map.post 'profile/update', 'profile#update', as: 'profile_update'

	map.post 'add_funds', 'funds#add'
	map.all 'withdraw_funds', 'funds#withdraw', as: 'withdraw_funds'
	map.all 'withdraw_submit', 'funds#withdrawSubmit', as: 'withdraw_submit'
	map.all 'fun', 'settings#fun'

	map.all 'funds', 'funds#index'

	map.all 'play/:name', 'game#play'

	map.all 's2p_callback', 'funds#s2pCallback'
	map.all 'payment_success', 'funds#paymentSuccess'
	map.all 'payment_failure', 'funds#paymentFailure'

	map.root 'application#index', as: 'root'
	map.all ':controller/:action'
	map.all ':controller/:action/:id'

	map.socket 'connectTo', 'connection#to'
	map.socket 'sendData', 'connection#data'