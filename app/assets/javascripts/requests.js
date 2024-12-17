var COURSE;

$(document).ready(function() {

	$(".click_redirect").click(function() {
		var path = $(this).data("redirect-path");
		location.href=path;
	});

	$('#requester_name').autocomplete({
    source: $('#requester_name').data('autocomplete-source'),
		appendTo: "#change_owner_form .modal-body",
		focus: function(event, ui) {
			event.preventDefault();
			$(this).val(ui.item.label);
		},
		select: function(event, ui) {
			event.preventDefault();
			$(this).val(ui.item.label);
			$("#requester_id").val(ui.item.value);
		}
	});

	$("#request_course_attributes_term, #request_course_attributes_year").on("input_load change", function(e) {

		var term = $("#request_course_attributes_term").val();
		var year = parseInt($("#request_course_attributes_year").val());
		//console.log("Here I am" + year);

		var start_month_day = "09-01"; // F, Y, FW
		var end_month_day = "04-30"; // Y, FW, W
		var start_year = year;  // F, Y, FW
		var end_year = year + 1; // Y, FW, W
		//console.log(term)

		
		switch(term) {
			case "F":
				end_month_day = "12-31";
				end_year = year;
				break;
			case "W":
				start_month_day = "01-01";
				start_year = year + 1;
				break;
			case "S":
			case "SU":
			case "S1":
			case "S2":
				start_month_day = "05-01";
				start_year = year + 1;
				end_month_day = "08-30";
		}

		$("#request_reserve_start_date").val(start_year + "-" + start_month_day);
		$("#request_reserve_end_date").val(end_year + "-" + end_month_day);


	}).trigger("input_load");;

	$("#rollover_course_term, #rollover_course_year").on("input_load change", function(e) {
		console.log("testie")
		var term = $("#rollover_course_term").val();
		var year = parseInt($("#rollover_course_year").val());
		//console.log("Here I am" + year);

		var start_month_day = "09-01"; // F, Y, FW
		var end_month_day = "04-30"; // Y, FW, W
		var start_year = year;  // F, Y, FW
		var end_year = year + 1; // Y, FW, W
		//console.log(term)

		
		switch(term) {
			case "F":
				end_month_day = "12-31";
				end_year = year;
				break;
			case "W":
				start_month_day = "01-01";
				start_year = year + 1;
				break;
			case "S":
			case "SU":
			case "S1":
			case "S2":
				start_month_day = "05-01";
				start_year = year + 1;
				end_month_day = "08-30";
		}

		$("#rollover_start_date").val(start_year + "-" + start_month_day);
		$("#rollover_end_date").val(end_year + "-" + end_month_day);


	}).trigger("input_load");;

	$(".change-item-status").each(function() {
	  item_status = $(this).data("status");
	  if (item_status == "ready") {
      $(this).addClass("green");
      $(this).removeClass("blend");
    } else if (item_status == "deleted") {
			$(this).hide();
    } else{
      $(this).addClass("blend");
      $(this).removeClass("green");
    }
	});

	$(".history-show-details").on('click', function() {
	  $('.audit_details').toggle();
	  $(".details-text").toggle();
  });
});
