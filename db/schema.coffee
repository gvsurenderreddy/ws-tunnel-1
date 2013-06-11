User = describe 'User', ->
	property 'email', String, index: true
	property 'password', String
	property 'login', String
	property 'nick', String
	property 'date', String
	property 'gender', String, default: 'man'
	property 'sex', String, default: 'man'
	property 'country', String, default: 'rus'
	property 'phone', String

LoginForm = describe 'LoginForm', ->
	property 'login'
	property 'password'