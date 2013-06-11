module.exports = (compound, User) ->
	User.validatesFormatOf 'login', with: /^[a-zA-Z0-9_]{4,}$/i
	User.validatesFormatOf 'email', with: /^.*?@.+\..{2,}$/i
	User.validatesLengthOf 'password', min: 3