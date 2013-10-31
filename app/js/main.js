
$(document).ready(function(){
  var options = {
    beforeSubmit: function(arr, $form, options){
      $form.validate();
      $('#start-migration').toggleClass('pure-button-disabled');
      $('#download-files').addClass('pure-button-disabled');
      $('#download-log').addClass('pure-button-disabled');
      $('#status-console').empty();
//      $('#status-console').append("<progress></progress>");
    },
    success:      function(responseText, statusText, xhr, $form){
      $('#start-migration').toggleClass('pure-button-disabled');
      $('#download-files').removeClass('pure-button-disabled');
      $('#download-log').removeClass('pure-button-disabled');
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

  $("#nodourl").click(function(){
    // If checked
    if ($("#nodourl").is(":checked")) {
      //show the hidden div
      $("#do_baseurl").removeAttr('required');
    }  else {
      //otherwise, hide it
      $("#do_baseurl").attr("required", "true");
    }
  });

});


function updateStatus(update, emitter){
    console.log(update);
    if (update.type == 'error') {
      emitter.show_error(update.body);
    } else if (update.type == 'status') {
      emitter.add_status(update.body);
    } else if (update.type == 'warning') {
      emitter.show_error(update.body);
    } else if (update.type == 'update') {
      emitter.show_update(update.body, update.source);
    } else if (update.type == 'flash') {
      emitter.flash(update.body, update.source);
    } else if (update.type == 'progress') {
      emitter.show_progress(update.ticks, update.total);
    } else if (update.type == 'progress_message') {
      emitter.show_progress_message(update.body);
    } else if (update.type == 'log') {
      $('#download-log').attr('href', update.file);
    }
}


function StatusEmitter() {
  var statusBox = $('#status-console');

  this.last_status = function() {
    return statusBox.children('div.status:last');
  }

  this.add_status = function(status) {
    last_status = this.last_status();
    console.log(last_status);
    if (last_status.length) {
      last_status.addClass("collapsed");
      last_status.children('div.updates').children('p:last').children('span.progress').remove();
      last_status.children('div.updates').children('p.flash').fadeOut(500, function() {
        this.remove()
      });
    }
    statusBox.append("<div class=\"status\"><div class=\"main\">"+status+" <a href=\"#\" class=\"toggleUpdates\"> (+/-)</a></div><div class=\"updates\"></div></div>");

    last_status = this.last_status();
    toggler = last_status.children('div.main').children('a.toggleUpdates');

    toggler.on('click', function(e) {
      $(this).parent().parent().toggleClass('collapsed');
    });
  }

  this.show_error = function(body){
    last_status = this.last_status();
    if (!last_status.length) {
      this.add_status('Migration Errors');
      last_status = this.last_status();
    }

    html = "<p class='error'><b>"+body+"</b></p>";
    last_status.children('div.updates').append(html);
  }

  this.show_update = function(body, source){
    source = typeof source !== 'undefined' ? source : 'migration';
    last_status = this.last_status();
    last_status.children('div.updates').children('p:last').children('span.progress').remove();

    last_status.children('div.updates').children('p.flash').fadeOut(500, function() {
      this.remove()
    });

    html = "<p class='update "+source+"'>" + body + "</p>";
    last_status.children('div.updates').append(html);
  }

  this.show_progress = function(ticks, total) {
    percent = Math.round((ticks / total) * 100);
    last_status = this.last_status();

    last_status.children('div.updates').children('p:last').children('span.progress').remove();
    html = "<span class='progress'> " + percent + "%</span>";
    last_status.children('div.updates').children('p:last').append(html);
  }

  this.show_progress_message = function(body) {
    $("#status-console div.status:last div.updates span.progress-message").remove();
    $("#status-console div.status:last div.updates p.migration:last").append("<span class='progress-message'> - " + body + "</span>");
  }

  this.flash = function(body, source){
    source = typeof source !== 'undefined' ? source : 'migration';
    last_status = this.last_status();

    last_status.children('div.updates').children('p:last').children('span.progress').remove();
    last_status.children('div.updates').children('p.flash').fadeOut(500, function() {
      this.remove()
    });

    html = "<p class='update flash "+source+"'>" + body + "</p>";
    last_status.children('div.updates').append(html);
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
