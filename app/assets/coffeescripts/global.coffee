$ ->
	$(document).on 'click', '.close-game', (evt) ->
		elem = $(this)

		if not elem.data 'logging-off'
			elem.data 'logging-off', true
			setBackdrop(true)

			v.stop()

		return false

	window.adjustGameSize = () ->
		$('object').height($(window).height() - $('.navbar').height() - 40)

	$(window).resize (evt) ->
		adjustGameSize()

	adjustGameSize()

	loadWindows = () ->
		if ($('.logged-in').length)
			$('#profile .modal-body').load '/profile'
			$('#funds .modal-body').load '/funds'
			$('#withdraw .modal-body').load '/withdraw_funds'
			$('#payments-history .modal-body').load '/funds/history'
		else
			$('#login .modal-body').load '/login'
			$('#register .modal-body').load '/register'

	loadWindows()

	window.closeActivePopup = ->
		$('.modal').modal('hide')

	window.reloadHeader = ->
		$('.navbar').load '/application/header', {}, () ->
			loadWindows()

	setFormBusy = (form, state) ->
		form.data 'busy', state
		form.find('input[type="submit"]').attr 'disabled', state

	window.setBackdrop = (state) ->
		backdrop = $('.modal-backdrop')

		if state and backdrop.length
			return backdrop
		else
			if not state
				backdrop.remove()
			else
				backdrop = $('<div class="modal-backdrop custom-backdrop"/>')
				backdrop.appendTo $('body')

				spinner = new Spinner
					color: '#fff'

				spinner.spin backdrop.get 0

	$(document).on 'submit', 'form', (evt) ->
		evt.preventDefault()

		form = $(this)

		if not form.data 'busy'
			setFormBusy form, true

			form.ajaxSubmit
				success: (response) ->
					#console.dir response

					if typeof response is 'object'
						html = response.html
					else if typeof response is 'string' and response[0] is '{'
						try
							response = $.parseJSON(response)
							html = response.html
						catch e
					else
						html = response

					if typeof response is 'object'
						if response.execute
							try
								eval response.execute
							catch e
								console.log e

						if response.redirect
							window.location.href = response.redirect

					html = if html.indexOf('<') is 0 then $(html) else $("<div>#{html}</div>")

					newForm = html.find '~ form'
					if newForm.length
						html = newForm

					prev = form.prev()
					parent = form.parent()

					form.remove()

					if prev.length
						html.insertAfter prev
					else
						html.appendTo parent

					setFormBusy form, false

	navigating = false

	window.navigateTo = (url, callback) ->
		closeGameButton = $('.close-game')

		if closeGameButton.length and not closeGameButton.data 'logging-off'
			closeGameButton.click()
			return

		if not navigating
			navigating = true
			setBackdrop true

			$.get url, (html) ->
				console.log "Navigate to #{url}..."

				$('.content >').remove()
				$('.content').append($(html).find('>'))
				$('.content').append($(html).filter('script'))

				reloadHeader()
				History.pushState({url: window.location.href}, document.title, url)
				navigating = false
				setBackdrop false

				if callback
					callback(url)

	typeof History isnt 'undefined' && History.Adapter.bind window, 'statechange', ->
		state = History.getState()

		if not navigating
			navigateTo state.url

	$(document).on 'click', 'a[href]', (evt) ->
		elem = $(this)
		url = elem.attr 'href'

		if url[0] isnt '#' and url isnt '/logout'
			navigateTo url

			return false
		# else if elem.data('toggle') is 'modal'
		#	closeActivePopup()

	withdrawValueTimer = null

	blockWithdrawWindow = (state = true) ->
		$('#withdraw-form input, #withdraw-form select').attr 'disabled', state

	clearWithdrawTimer = () ->
		clearTimeout withdrawValueTimer
		withdrawValueTimer = null

	postWithdrawData = () ->
		form = $('#withdraw-form')

		$.post form.data('refresh-url'),
			sum: parseInt $('#withdraw-value').val()
			payment_system: $('#withdraw-system').val()
			currency: $('#withdraw-system').find(':selected').data('currency')
			user_id: $('input[name="user_id"]').val()
		, (html) ->
			form.find('>').remove()
			form.append $(html).find '>'

	window.handleWithdrawSubmit = (evt) ->
		e = $.Event evt || event

		textarea = $('#withdraw-requisites')

		if textarea.val() is ''
			alert textarea.data 'error-empty'

			e.preventDefault()
			e.stopImmediatePropagation()

	$(document).on 'keyup', '#withdraw-value', (evt) ->
		clearWithdrawTimer()
		defValue = 50

		elem = $(this)
		form = elem.closest 'form'
		value = parseInt elem.val()
		maxValue = form.data 'max'

		$('#withdraw-desc').hide()
		$('#withdraw-system').parent().parent().hide()
		$('#withdraw-submit').hide()

		withdrawValueTimer = setTimeout () ->
			if isNaN(value) or value < defValue
				elem.val defValue

			if value > maxValue
				elem.val maxValue

			blockWithdrawWindow()

			postWithdrawData()
		, 1500

	$(document).on 'change', '#withdraw-system', (evt) ->
		clearWithdrawTimer()

		elem = $(this)
		form = elem.closest 'form'
		value = parseInt $('#withdraw-value').val()

		blockWithdrawWindow()
		$('#withdraw-desc').hide()
		$('#withdraw-submit').hide()

		postWithdrawData()

	lastActionTimers = []

	window.lastAction = (text, title) ->
		time = if lastActionTimers.length >= 1 then 2000 else 400
		timeMark = new Date()

		lastActionTimers.push setTimeout ->
			existing = $ '.popover'

			if existing.length
				html = existing
			else
				html = $ '<div class="popover popover-global fade bottom in"><div class="arrow"></div><h3 class="popover-title"></h3><div class="popover-content"></div></div>'

			html.click () ->
				html.remove()

			if (typeof text is 'boolean' and text is false) or not text
				html.remove()
			else
				html.css 'display', 'block'

				titleElem = html.find('.popover-title')

				if not title
					titleElem.hide()
				else
					titleElem.show()
					titleElem.html title

				html.find('.popover-content').html "<em>#{if timeMark.toLocaleTimeString then timeMark.toLocaleTimeString() else timeMark.toString()}</em> #{text}"

				html.appendTo $ 'body'

			lastActionTimers.shift()
		, time

	window.inGame = () ->
		return ~window.location.href.indexOf("/play")

	window.reloadCurrentLocation = (callback) ->
		navigateTo window.location.href, callback


	$(document).on 'change', '.lang-selector', (evt) ->
		setBackdrop true
		$(this).closest('form').submit()