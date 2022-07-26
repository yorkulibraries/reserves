$(document).ready(function() {
	$(".request_history table .comment").click(function() {
		//alert($(this).parent().next().prop("class"));
		$(this).parent().next().toggleClass('hide');
	});



  $("#note-textarea").bind('keyup', function(){
    checkCount();
  });



	$('#history_popup').on('shown.bs.modal', function (e) {

		var data_url = $("#request_history_log").data("url");
		$( "#request_history_log" ).load( data_url);
	}	);

});

/* Checks the count of the note text area and changes color to red if limit hit */
function checkCount(){
  var textAreaValue = $("#note-textarea").val();
  $('.remaining').html(textAreaValue.length);
  if (textAreaValue.length > 255) {
    $('.remaining').addClass("red");
  }
  else {
    $('.remaining').removeClass("red");
  }
}
