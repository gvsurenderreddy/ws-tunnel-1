(function() {

  $(function() {
    var blockWithdrawWindow, clearWithdrawTimer, lastActionTimers, loadWindows, navigating, postWithdrawData, setFormBusy, withdrawValueTimer;
    $(document).on('click', '.close-game', function(evt) {
      var elem;
      elem = $(this);
      if (!elem.data('logging-off')) {
        elem.data('logging-off', true);
        setBackdrop(true);
        v.stop();
      }
      return false;
    });
    window.adjustGameSize = function() {
      return $('object').height($(window).height() - $('.navbar').height() - 40);
    };
    $(window).resize(function(evt) {
      return adjustGameSize();
    });
    adjustGameSize();
    loadWindows = function() {
      if (($('.logged-in').length)) {
        $('#profile .modal-body').load('/profile');
        $('#funds .modal-body').load('/funds');
        $('#withdraw .modal-body').load('/withdraw_funds');
        return $('#payments-history .modal-body').load('/funds/history');
      } else {
        $('#login .modal-body').load('/login');
        return $('#register .modal-body').load('/register');
      }
    };
    loadWindows();
    window.closeActivePopup = function() {
      return $('.modal').modal('hide');
    };
    window.reloadHeader = function() {
      return $('.navbar').load('/application/header', {}, function() {
        return loadWindows();
      });
    };
    setFormBusy = function(form, state) {
      form.data('busy', state);
      return form.find('input[type="submit"]').attr('disabled', state);
    };
    window.setBackdrop = function(state) {
      var backdrop, spinner;
      backdrop = $('.modal-backdrop');
      if (state && backdrop.length) {
        return backdrop;
      } else {
        if (!state) {
          return backdrop.remove();
        } else {
          backdrop = $('<div class="modal-backdrop custom-backdrop"/>');
          backdrop.appendTo($('body'));
          spinner = new Spinner({
            color: '#fff'
          });
          return spinner.spin(backdrop.get(0));
        }
      }
    };
    $(document).on('submit', 'form', function(evt) {
      var form;
      evt.preventDefault();
      form = $(this);
      if (!form.data('busy')) {
        setFormBusy(form, true);
        return form.ajaxSubmit({
          success: function(response) {
            var html, newForm, parent, prev;
            if (typeof response === 'object') {
              html = response.html;
            } else if (typeof response === 'string' && response[0] === '{') {
              try {
                response = $.parseJSON(response);
                html = response.html;
              } catch (e) {

              }
            } else {
              html = response;
            }
            if (typeof response === 'object') {
              if (response.execute) {
                try {
                  eval(response.execute);
                } catch (e) {
                  console.log(e);
                }
              }
              if (response.redirect) {
                window.location.href = response.redirect;
              }
            }
            html = html.indexOf('<') === 0 ? $(html) : $("<div>" + html + "</div>");
            newForm = html.find('~ form');
            if (newForm.length) {
              html = newForm;
            }
            prev = form.prev();
            parent = form.parent();
            form.remove();
            if (prev.length) {
              html.insertAfter(prev);
            } else {
              html.appendTo(parent);
            }
            return setFormBusy(form, false);
          }
        });
      }
    });
    navigating = false;
    window.navigateTo = function(url, callback) {
      var closeGameButton;
      closeGameButton = $('.close-game');
      if (closeGameButton.length && !closeGameButton.data('logging-off')) {
        closeGameButton.click();
        return;
      }
      if (!navigating) {
        navigating = true;
        setBackdrop(true);
        return $.get(url, function(html) {
          console.log("Navigate to " + url + "...");
          $('.content >').remove();
          $('.content').append($(html).find('>'));
          $('.content').append($(html).filter('script'));
          reloadHeader();
          History.pushState({
            url: window.location.href
          }, document.title, url);
          navigating = false;
          setBackdrop(false);
          if (callback) {
            return callback(url);
          }
        });
      }
    };
    typeof History !== 'undefined' && History.Adapter.bind(window, 'statechange', function() {
      var state;
      state = History.getState();
      if (!navigating) {
        return navigateTo(state.url);
      }
    });
    $(document).on('click', 'a[href]', function(evt) {
      var elem, url;
      elem = $(this);
      url = elem.attr('href');
      if (url[0] !== '#' && url !== '/logout') {
        navigateTo(url);
        return false;
      }
    });
    withdrawValueTimer = null;
    blockWithdrawWindow = function(state) {
      if (state == null) {
        state = true;
      }
      return $('#withdraw-form input, #withdraw-form select').attr('disabled', state);
    };
    clearWithdrawTimer = function() {
      clearTimeout(withdrawValueTimer);
      return withdrawValueTimer = null;
    };
    postWithdrawData = function() {
      var form;
      form = $('#withdraw-form');
      return $.post(form.data('refresh-url'), {
        sum: parseInt($('#withdraw-value').val()),
        payment_system: $('#withdraw-system').val(),
        currency: $('#withdraw-system').find(':selected').data('currency'),
        user_id: $('input[name="user_id"]').val()
      }, function(html) {
        form.find('>').remove();
        return form.append($(html).find('>'));
      });
    };
    window.handleWithdrawSubmit = function(evt) {
      var e, textarea;
      e = $.Event(evt || event);
      textarea = $('#withdraw-requisites');
      if (textarea.val() === '') {
        alert(textarea.data('error-empty'));
        e.preventDefault();
        return e.stopImmediatePropagation();
      }
    };
    $(document).on('keyup', '#withdraw-value', function(evt) {
      var defValue, elem, form, maxValue, value;
      clearWithdrawTimer();
      defValue = 50;
      elem = $(this);
      form = elem.closest('form');
      value = parseInt(elem.val());
      maxValue = form.data('max');
      $('#withdraw-desc').hide();
      $('#withdraw-system').parent().parent().hide();
      $('#withdraw-submit').hide();
      return withdrawValueTimer = setTimeout(function() {
        if (isNaN(value) || value < defValue) {
          elem.val(defValue);
        }
        if (value > maxValue) {
          elem.val(maxValue);
        }
        blockWithdrawWindow();
        return postWithdrawData();
      }, 1500);
    });
    $(document).on('change', '#withdraw-system', function(evt) {
      var elem, form, value;
      clearWithdrawTimer();
      elem = $(this);
      form = elem.closest('form');
      value = parseInt($('#withdraw-value').val());
      blockWithdrawWindow();
      $('#withdraw-desc').hide();
      $('#withdraw-submit').hide();
      return postWithdrawData();
    });
    lastActionTimers = [];
    window.lastAction = function(text, title) {
      var time, timeMark;
      time = lastActionTimers.length >= 1 ? 2000 : 400;
      timeMark = new Date();
      return lastActionTimers.push(setTimeout(function() {
        var existing, html, titleElem;
        existing = $('.popover');
        if (existing.length) {
          html = existing;
        } else {
          html = $('<div class="popover popover-global fade bottom in"><div class="arrow"></div><h3 class="popover-title"></h3><div class="popover-content"></div></div>');
        }
        html.click(function() {
          return html.remove();
        });
        if ((typeof text === 'boolean' && text === false) || !text) {
          html.remove();
        } else {
          html.css('display', 'block');
          titleElem = html.find('.popover-title');
          if (!title) {
            titleElem.hide();
          } else {
            titleElem.show();
            titleElem.html(title);
          }
          html.find('.popover-content').html("<em>" + (timeMark.toLocaleTimeString ? timeMark.toLocaleTimeString() : timeMark.toString()) + "</em> " + text);
          html.appendTo($('body'));
        }
        return lastActionTimers.shift();
      }, time));
    };
    window.inGame = function() {
      return ~window.location.href.indexOf("/play");
    };
    window.reloadCurrentLocation = function(callback) {
      return navigateTo(window.location.href, callback);
    };
    return $(document).on('change', '.lang-selector', function(evt) {
      setBackdrop(true);
      return $(this).closest('form').submit();
    });
  });

}).call(this);
