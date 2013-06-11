var Viewer = function (new_conf, pref, on_ready, on_logout, on_percent) {
	var conf = new_conf;
	var swf, swfId, gameName, playerGuid, state = '', guid;

	var goal_state = '';
	var wait_swith_state_confirm = false;
	var ta_log = $('#log_' + pref);
	var log = function (row) {
		console.log(row);
	};
	var start = function (new_gameName, new_playerGuid) {
		goal_state = 'load';
		if (state !== '') {
			removeSwf();
			state = '';
		}
		gameName = new_gameName;
		playerGuid = new_playerGuid;
		var flashvars = {
			"lang": "ru_RU",
			"base_url": conf.baseUrl,
			"dictionaries_list": conf.dictList,
			"js_external_interface_prefix": pref
		};
		var params = {
			allownetworking: "all",
			allowscriptaccess: "always",
			allowfullscreen: true,
			wmode: 'transparent'
		};

		var orig_div = $('#div_' + pref);

		swfobject.embedSWF(
			conf.baseUrl + 'viewer_.swf',
			'div_' + pref,
			conf.swfWidth, conf.swfHeight, conf.swfVer,
			null,
			flashvars, params, {},
			function () {
				swf = document.getElementById('div_' + pref);

				if (orig_div.hasClass('do-not-show'))
					swf.className += (swf.className.length ? ' ' : '') + 'do-not-show'
			}
		);
	};

	var stop = function () {
		goal_state = 'unload';
		if (wait_swith_state_confirm) {
			wait_swith_state_confirm = false;
			sendToFlash('state', 'hide');
		}
		sendToFlash('do', 'logout');
	};

	var parseUrlQuery = function (query) {
		var res = {};
		var vars = query.split("&");
		for (var i = 0; i < vars.length; i++) {
			var pair = vars[i].split("=");
			res[pair[0]] = decodeURIComponent(pair[1] || '');
		}
		return res;
	};

	var _Init = function () {
		return 1;
	};

	var _Event = function (current_state, target_state, code, data) {
		log(current_state + ' ' + target_state + ' ' + code + ' ' + data);
		if (code == 'state') {
			log('Swith from: ' + current_state + ' to: ' + target_state);
			if (target_state == 'start') {
				var params = '&game=' + gameName + '&playerguid=' + playerGuid;
				sendToFlash('state', 'hide' + params);
				wait_swith_state_confirm = false;

			} else if (target_state === '') {
				on_logout('', true);
				removeSwf();
			} else if (target_state === 'ready') {

				if (goal_state == 'load') {
					wait_swith_state_confirm = true;
					on_ready();
				} else {
					sendToFlash('state', 'hide');
				}

			} else if (target_state === 'logout') {
				if (goal_state == 'unload') {
					wait_swith_state_confirm = true;
					on_logout();
				} else {
					sendToFlash('state', 'hide');
				}

			} else {
				sendToFlash('state', 'hide');
				wait_swith_state_confirm = false;
			}
			state = target_state;

		} else {

			if (code == 'do') {

				var amp_pos = data.indexOf('&'),
					sub_code = '', attrs = {};
				if (amp_pos === -1) {
					sub_code = data;
				} else {
					sub_code = data.substr(0, amp_pos);
					attrs = parseUrlQuery(data.substr(amp_pos + 1));
				}

				if (sub_code == 'ConnectCreate' && conf.onConnect) {
					var callback = function (success, guid_or_error) {
						if (success) {
							sendToFlash('do', 'ConnectCreateOk&sign=' + attrs.sign + '&GUID=' + guid_or_error);
						} else {
							sendToFlash('do', 'ConnectCreateError&sign=' + attrs.sign + '&error=' + guid_or_error);
						}
					};
					conf.onConnect(attrs.url, attrs.mode, callback);

				} else if (sub_code == 'ConnectRequest' && conf.onData) {
					var callback = function (success, data) {
						if (success) {
							data = encodeURIComponent(data);
							sendToFlash('do', 'ConnectRequest&GUID=' + attrs.guid + '&sign=' + attrs.sign + '&data=' + data);
						} else {
							sendToFlash('do', 'ConnectClose&GUID=' + attrs.guid);
						}
					};
					conf.onData(attrs.guid, attrs.data, callback);

				} else if (sub_code == 'ConnectClose' && conf.onClose) {
					conf.onClose(attrs.guid);

				}
			} else if (code == 'loadpercent') {
				on_percent(Math.round(data * 100))
			}

		}

	};

	var sendToFlash = function (code, data) {
		window.setTimeout(
			function () {
				log('>> to flash: ' + code + ' ' + data);

				if (swf && swf.Event) {
					try {
						swf.Event(code, data);
					}
					catch (e) {
					}
				}
			},
			30
		);
	};

	var done = function () {
		sendToFlash('state', 'show');
		wait_swith_state_confirm = false;
	};

	var doneLogout = function () {
		sendToFlash('state', 'logout');
		wait_swith_state_confirm = false;
	};

	var removeSwf = function () {
		if (swf) {
			var parent = swf.parentElement;
			swf.parentElement.removeChild(swf);
		}
		swf = null;
	};

	window[pref + "Init"] = _Init;
	window[pref + "Event"] = _Event;

	return {
		start: start,
		stop: stop,
		done: done,
		doneLogout: doneLogout
	};

};
