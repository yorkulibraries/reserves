function bootstrap_modal_show(modal_id, content){
  var holder_id = modal_id + "_holder";

  $("#" + holder_id).remove();
  $("body").append("<div id='" + holder_id + "'></div>");
  $("#" + holder_id).append(content);

  $("#" + modal_id).modal({ show: true, backdrop: 'static' });
}

function bootstrap_modal_close(modal_id) {
  var holder_id = modal_id + "_holder";

  $("#" + modal_id).modal("hide");
  $("#" + holder_id).remove();
}

function bootstrap_modal_replace_content(modal_id, new_content) {
  var holder_id = modal_id + "_holder";

  $("#" + modal_id).modal("hide");
  $("#" + holder_id).empty();
  $("#" + holder_id).append(new_content);
  $("#" + modal_id).modal({ show: true, backdrop: 'static' });

}
