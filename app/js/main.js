
$(document).ready(function(){
  var options = {
    beforeSubmit: function(arr, $form, options){
      $form.validate();
      $('#start-migration').toggleClass('pure-button-disabled');
      $('#status-console').empty();
    },
    success:      function(responseText, statusText, xhr, $form){
      $('#start-migration').toggleClass('pure-button-disabled');
    },
    xhr:          function(){
      var xhr = new XMLHttpRequest();
      var cursor = new ResponseCursor();
      var emitter = new StatusEmitter();
          
      xhr.addEventListener("progress", function(evt){
        var updates = cursor.read_response(this.response);
        for (i = 0; i < updates.length; i++){
          updateStatus(updates[i], emitter);
        }
      });
      return xhr;
    }
  };

  $('#migration-form').ajaxForm(options);
});


function updateStatus(update, emitter){
    console.log(update);
    if (update.type == 'error') {
      emitter.show_error(update.body);
    } else if (update.type == 'status') {
      emitter.refresh_status(update.body);
    } else {
      // todo: toggle in progress bar
    }
}


function StatusEmitter() {
  var console = $('#status-console');

  this.refresh_status = function(status){
      console.append("<p>"+status+"</p>");
  }

  this.show_error = function(error){
    console.addClass('error');
    console.append("<p><b>"+error+"</b></p>");
  }
}


function ResponseCursor() {
  var _index = 0;
  var response_buffer = "";
  var latest = "";

  this.read_response = function(response_string) {
    latest = response_string.substring(_index);
    _index = response_string.length;

    var buffered = response_buffer + latest;
    var chunked = buffered.split(/---\n/);    
    var updates = [];

    for (i = 0; i < chunked.length - 1; i++) {
      updates[i] = JSON.parse(chunked[i]);
    }

    response_buffer = chunked[chunked.length - 1];
    return updates;
  }  
}