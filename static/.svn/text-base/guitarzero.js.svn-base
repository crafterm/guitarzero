function setFocus() {
  var f = $$('.focus-on-load');
  if (!f.empty && (f.first().value.length == 0)) {
    f.first().focus();
  }  
}

function initAjaxPoll() {
  new Ajax.PeriodicalUpdater('content', '/', {frequency:15, method:'get'});
}

window.onload = function() {
  setFocus();
  initAjaxPoll();
}
