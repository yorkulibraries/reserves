function deletable(e) {
	if(e.keyCode == 8 && e.shiftKey && $(this).val() == "") {
		$(this).remove();
	}
}

$(document).ready(function() {
	$("a[data-visibility-toggle], [data-on-click-toggle]").on("click", function(e) {
		var t = $(this).data("visibility-toggle");
		$(t).toggleClass("hidden");
		e.preventDefault();
	});

	onClickShow()

	$("a[data-slide-up]").on("click", function(e) {
		var t = $(this).data("slide-up");
		$(t).slideUp("slow");
		e.preventDefault();
	});

	$("a[data-slide-down]").on("click", function(e) {
		var t = $(this).data("slide-down");
		$(t).slideDown("slow");
		e.preventDefault();
	});


	$("a.add-array-field").click(function() {
		var c = $(this).data("class");
		var n = $(this).data("name");
		var t = $(this).data("type");
		var i = $("<input/>", { name: n, type: t, class: c, value: "" } ).keyup(deletable);
		$(i).insertBefore(this);

	});

	$(".deletable").keyup(deletable);
});


function onClickShow() {
	$("[data-on-click-show]").on("click", function(e) {
		var t = $(this).data("on-click-show");
		$(t).removeClass("hidden");
	});
}
