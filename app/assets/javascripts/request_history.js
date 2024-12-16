$(document).ready(function() {
	$(".request_history table .comment").click(function() {
		//alert($(this).parent().next().prop("class"));
		$(this).parent().next().toggleClass('hide');
	});



  $(document).on('keyup', '[id^="note-textarea_"]', function () {
    checkCount($(this));
  });



	$('#history_popup').on('shown.bs.modal', function (e) {

		var data_url = $("#request_history_log").data("url");
		$( "#request_history_log" ).load( data_url);
	}	);

  $(document).on('shown.bs.modal', '[id^="item_history_popup_"]', function () {
    var $modal = $(this);
    var itemId = $modal.attr('id').split('_').pop();
    var dataUrl = $modal.find("#request_history_log_" + itemId).data("url");
    
    if (dataUrl) {
      $modal.find("#request_history_log_" + itemId).load(dataUrl);
    }
  });
  
});

/* Checks the count of the note text area and changes color to red if limit hit */
function checkCount(textArea) {
  var textAreaValue = textArea.val();
  var itemId = textArea.attr('id').split('_').pop();
  var remainingCounter = $(`#item_history_popup_${itemId} .remaining`);
  
  remainingCounter.text(textAreaValue.length);

  if (textAreaValue.length > 255) {
    remainingCounter.addClass("red");
  } else {
    remainingCounter.removeClass("red");
  }
}
