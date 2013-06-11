(function() {
  var Guid, config, config2, config3, config4;

  window.config = config = {
    prefix: 'flash_box',
    baseUrl: 'http://188.40.196.69/ggs/',
    dictList: 'profiles/test_69/dict_ext.lst',
    dictionaries: 'profiles/test_69/connect.dic',
    swfWidth: 500,
    swfHeight: 375,
    swfVer: '10.0.0',
    debug: true
  };

  config2 = {
    prefix: 'flash_box_2',
    baseUrl: 'http://188.40.196.69/ggs/',
    dictList: 'profiles/test_69/dict_ext.lst',
    dictionaries: 'profiles/test_69/connect.dic',
    swfWidth: 500,
    swfHeight: 375,
    swfVer: '10.0.0',
    debug: true
  };

  config3 = {
    prefix: 'external_connect_3',
    baseUrl: 'http://public.ggsexternalgames.com/140_flash/',
    dictList: 'profiles/ggsaffiliates/dict_public_network.lst',
    dictionaries: 'http://ggsdemoplay.com/external_connect/connect.dic',
    swfWidth: 500,
    swfHeight: 375,
    swfVer: '10.0.0',
    debug: true
  };

  config4 = {
    prefix: 'external_connect_4',
    baseUrl: 'http://public.ggsexternalgames.com/140_flash/',
    dictList: 'profiles/ggsaffiliates/dict_public_network.lst',
    dictionaries: 'http://ggsdemoplay.com/external_connect/connect.dic',
    swfWidth: 500,
    swfHeight: 375,
    swfVer: '10.0.0',
    debug: true
  };

  Guid = (function() {

    function Guid() {}

    Guid.prefix = new Date().getTime() % Math.pow(10, 8);

    Guid.random1 = Math.round(Math.random() * Math.pow(10, 6));

    Guid.random2 = Math.round(Math.random() * Math.pow(10, 4));

    Guid.value = 0;

    Guid.next = function() {
      return "" + this.prefix + "-" + this.random1 + "-" + this.random2 + "-" + (++this.value);
    };

    return Guid;

  })();

  $(function() {
    var initV;
    initV = function(config, onReady, onLogout, onPercent) {
      var gameName, guid, originalOnLogoutFn, originalOnReadyFn, originalStartFn, socket, viewer;
      socket = io.connect(window.location.hostname, {
        'force new connection': false
      });
      guid = Guid.next();
      gameName = null;
      originalOnReadyFn = onReady;
      originalOnLogoutFn = onLogout;
      onReady = function() {
        return originalOnReadyFn.call(this, gameName);
      };
      onLogout = function(name, reason) {
        return originalOnLogoutFn.call(this, gameName, reason);
      };
      config.onConnect = function(url, mode, callback) {
        if (mode === 'sock') {
          socket.emit('connectTo', {
            url: url,
            guid: guid
          });
          return socket.on('connectToComplete', function(data) {
            if (data.guid === guid) {
              socket.removeListener('connectToComplete', arguments.callee);
              return callback(true, new Date().getTime());
            }
          });
        }
      };
      config.onData = function(systemGuid, data, callback) {
        socket.on('newData', function(_arg) {
          var data, responseGuid;
          data = _arg.data, responseGuid = _arg.guid;
          if (responseGuid === guid) {
            socket.removeListener('newData', arguments.callee);
            return callback(true, data);
          }
        });
        return socket.emit('sendData', {
          data: data,
          guid: guid
        });
      };
      socket.on('sessionTimeout', function(data) {
        socket.removeAllListeners();
        $('.close-game').data('logging-off', true);
        return navigateTo('/');
      });
      socket.on('gameEvent', function(data) {
        return lastAction("Игровое событие " + data.type + ".");
      });
      viewer = new Viewer(config, config.prefix, function() {
        return onReady();
      }, function(name, reason) {
        socket.removeAllListeners();
        return onLogout(name, reason);
      }, function(perc) {
        return onPercent(perc);
      });
      originalStartFn = viewer.start;
      viewer.start = function(name) {
        gameName = name;
        return originalStartFn.apply(viewer, arguments);
      };
      return viewer;
    };
    return window.reinitV = function() {
      var v;
      return window.v = v = initV(config, function(name) {
        v.done();
        return lastAction("Загружена игра " + name + ".");
      }, function(name, reason) {
        $('.close-game').data('logging-off', true);
        v.doneLogout();
        if (reason) {
          lastAction("Вышли из игры " + name + " [ошибка загрузки или прерывание].");
        } else {
          lastAction("Вышли из игры " + name + ".");
        }
        return navigateTo('/');
      }, function(perc) {
        var bar;
        bar = $('.bar');
        bar.width("" + perc + "%");
        if (perc === 100) {
          return setTimeout(function() {
            $('.progress').hide();
            adjustGameSize();
            return setTimeout(function() {
              return $('.game object').removeClass('do-not-show');
            }, 400);
          }, 100);
        }
      });
    };
  });

}).call(this);
