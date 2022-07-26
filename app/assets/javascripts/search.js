$(document).ready(function() {

  var throttled_submit = _.throttle(function(f) {
    $(f).closest("form").submit();
  }, 800);

  $(".search_auto_submit").keyup(function(e) {
    throttled_submit(this);
  });


});
