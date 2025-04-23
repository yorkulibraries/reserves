function bootstrap_modal_show(modal_id, content){
  var holder_id = modal_id + "_holder";

  $("#" + holder_id).remove();
  $("body").append("<div id='" + holder_id + "'></div>");
  $("#" + holder_id).append(content);

  var modalElement = document.getElementById(modal_id);
  var myModal = new bootstrap.Modal(modalElement, { backdrop: 'static' });
  myModal.show();
}

function bootstrap_modal_close(modal_id) {
  var holder_id = modal_id + "_holder";

  var modalElement = document.getElementById(modal_id);
  var myModal = bootstrap.Modal.getInstance(modalElement);
  if (myModal) {
    myModal.hide();
  }
  $("#" + holder_id).remove();
}

function bootstrap_modal_replace_content(modal_id, new_content) {
  var holder_id = modal_id + "_holder";

  var modalElement = document.getElementById(modal_id);
  var currentModal = bootstrap.Modal.getInstance(modalElement);
  if (currentModal) {
    currentModal.hide();
  }

  $("#" + holder_id).empty();
  $("#" + holder_id).append(new_content);

  var newModalElement = document.getElementById(modal_id);
  var newModal = new bootstrap.Modal(newModalElement, { backdrop: 'static' });
  newModal.show();
}