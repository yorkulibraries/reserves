var COURSE;

$(document).ready(function() {


	let isSelectionMade = false;

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
		isSelectionMade = true;
		enableSubmitButton();
		disableTyping();
	  }
	});
	
	$('#requester_name').on('input change', function() {
	  if (isSelectionMade) {
		enableSubmitButton();
	  }
	});
	
	function disableTyping() {
	  $('#requester_name').attr('readonly', true);
	}
	
	function enableTyping() {
	  $('#requester_name').attr('readonly', false);
	}
	
	function enableSubmitButton() {
	  const requesterIdValue = $('#requester_id').val().trim();
	  if (requesterIdValue !== "") {
		$('#change_owner_submit').prop('disabled', false);
	  } else {
		$('#change_owner_submit').prop('disabled', true);
	  }
	}
	
	$('#requester_name').on('keyup', function() {
	  if (isSelectionMade) {
		$(this).val('');
		$("#requester_id").val('');
		isSelectionMade = false;
		enableSubmitButton();
		enableTyping();
	  }
	});
	
  
	
	function computeDates(year, term) {
		let startMonthDay = "09-01",
			endMonthDay   = "04-30",
			startYear     = year,
			endYear       = year + 1;

		switch(term) {
		case "F":
			endMonthDay = "12-31";
			endYear     = year;
			break;
		case "W":
			startMonthDay = "01-01";
			startYear    = year + 1;
			break;
		case "S": case "SU": case "S1": case "S2":
			startMonthDay = "05-01";
			startYear    = year + 1;
			endMonthDay  = "08-30";
			break;
		}

		return {
		start: `${startYear}-${startMonthDay}`,
		end:   `${endYear}-${endMonthDay}`
		};
	}

	
	function updateReserveDatesFromCode(code) {
		if (!code) return;
		const parts = code.split('_');
		if (parts.length < 4) return;

		const year = parseInt(parts[0], 10),
			term = parts[3];
		if (isNaN(year)) return;

		const { start, end } = computeDates(year, term);
		$('#request_reserve_start_date').val(start);
		$('#request_reserve_end_date').val(end);
	}

	
	function initRequestCourseAutocomplete() {
		const $search = $('#request_course_search:visible');
		if ($search.length === 0) return;
	  
		$search.autocomplete({
		  source(request, response) {
			$.getJSON('/courses/autocomplete', { term: request.term }, response);
		  },
		  minLength: 4,
		  open() {
			const $input = $(this), widthPx = $input.outerWidth();
			$input.autocomplete('widget').css('width', widthPx + 'px');
		  },
		  select(event, ui) {
			$search.val(ui.item.label);
	  
			$('#request_course_id_hidden').val(ui.item.value);
	  
			updateReserveDatesFromCode(ui.item.code);
	  
			const rawName = (ui.item.instructor || '').trim();
	  
			let firstName = '', lastName = '';
			if (/,/.test(rawName)) {
			  // "Last, First Middle"
			  const [last, rest] = rawName.split(',', 2);
			  lastName  = (last || '').trim();
			  firstName = (rest || '').trim().split(/\s+/)[0] || '';
			} else {
			  // "First [Middle...] Last"
			  const parts = rawName.split(/\s+/);
			  firstName = parts[0] || '';
			  lastName  = parts.slice(1).join(' ');
			}
	  
			if (firstName) {
			  $.getJSON('/alma/users/lookup_by_name', { first_name: firstName, last_name: lastName }, function(users) {
				if (!users || users.length === 0) return;
	  
				if ($('#request_alma_instructor_id').length === 0) {
				  $('<input>', { type: 'hidden', id: 'request_alma_instructor_id', name: 'request[alma_instructor_id]' })
					.appendTo('form');
				}
	  
				if (users.length === 1) {
				  $('#request_alma_instructor_id').val(users[0].primary_id);
				} else {
				  let optionsHtml = '';
				  users.forEach(user => {
					const label = `${user.name} (${user.email || 'No email'})`;
					optionsHtml += `<option value="${user.primary_id}">${label}</option>`;
				  });
	  
				  const modalHtml = `
					<div class="modal fade" id="instructorModal" tabindex="-1" aria-labelledby="instructorModalLabel" aria-hidden="true">
					  <div class="modal-dialog"><div class="modal-content">
						<div class="modal-header">
						  <h5 class="modal-title" id="instructorModalLabel">Choose Instructor</h5>
						  <button type="button" class="btn-close" data-bs-dismiss="modal" aria-label="Close"></button>
						</div>
						<div class="modal-body">
						  <label for="instructor-choice" class="form-label">Multiple instructors found. Select the correct one:</label>
						  <select id="instructor-choice" class="form-select">
							${optionsHtml}
						  </select>
						</div>
						<div class="modal-footer">
						  <button type="button" class="btn btn-secondary" data-bs-dismiss="modal">Cancel</button>
						  <button type="button" id="confirm-instructor" class="btn btn-primary">Confirm</button>
						</div>
					  </div></div>
					</div>`;
	  
				  $('#instructorModal').remove();
				  $('body').append(modalHtml);
	  
				  const modal = new bootstrap.Modal(document.getElementById('instructorModal'));
				  modal.show();
	  
				  $(document).off('click', '#confirm-instructor').on('click', '#confirm-instructor', function () {
					const selected = $('#instructor-choice').val();
					$('#request_alma_instructor_id').val(selected);
					modal.hide();
					$('#instructorModal').remove();
				  });
				}
			  });
			}
	  
			return false;
		  }
		});
	  
		// ---------- (two lines, highlighted) ----------
		function esc(s){
		  return String(s).replace(/[&<>"']/g, c => ({'&':'&amp;','<':'&lt;','>':'&gt;','"':'&quot;',"'":'&#39;'}[c]));
		}
		function mark(text, term){
		  if(!term) return esc(text||'');
		  const re = new RegExp('(' + $.ui.autocomplete.escapeRegex(term) + ')','ig');
		  return esc(text||'').replace(re,'<mark>$1</mark>');
		}
	  
		const ac = $search.autocomplete('instance') || $search.data('ui-autocomplete');
		if (ac) {
		  ac._renderItem = function(ul, item){
			const term = this.term;
	  
			const title      = mark(item.title, term);
			const metaLeft   = `${esc(item.faculty)}/${esc(item.subject)} ${esc(item.number)} ${esc(item.credits)}`;
			const pillsRight = `
			  <span class="ac-pill">${esc(item.section)}</span>
			  <span class="ac-pill">${esc(item.year)} ${esc(item.term)}</span>
			`;
			const instructor = mark(item.instructor || '', term);
	  
			const html = `
			  <div class="ac-item">
				<div class="ac-top">
				  <span class="ac-title">${title}</span>
				  <span class="ac-meta">${metaLeft}</span>
				  <span class="ac-right">${pillsRight}</span>
				</div>
				<div class="ac-bottom">
				  <span class="ac-instructor">${instructor}</span>
				</div>
			  </div>
			`;
	  
			return $('<li>').append(html).appendTo(ul);
		  };
		}
		$search.on('autocompletechange', function(event, ui) {
		  if (!ui.item) {
			$search.val('');
			$('#request_course_id_hidden').val('');
			$('#request_reserve_start_date').val('');
			$('#request_reserve_end_date').val('');
			$('#request_alma_instructor_id').val('');
		  }
		});
	}


	  
	// Turbo-aware init
	document.addEventListener('turbo:load', initRequestCourseAutocomplete);
	// Fallback for non-Turbo pages (keeps your other code working)
	$(document).ready(initRequestCourseAutocomplete);  

	$("#rollover_course_term, #rollover_course_year").on("input_load change", function(e) {
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
