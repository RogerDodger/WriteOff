jQuery(document).ready(function($) {
	var uploadOk = 0;
	$('.has-placeholder')
		.focus(function() {
			var input = $(this);
			if(input.val() == input.attr('name')) { 
				input.val('');
				input.css('color', 'black');
			}
		})
		.blur(function() {
			var input = $(this);
			if(input.val() == '') {
				input.css('color', '#aaa');
				input.val(input.attr('name'));
			}
		})
		.blur();
	$('.link.new-window').attr({
		target : '_blank',
		title  : 'Open link in new tab',
	});
	$('a.ui-button, input[type=submit], button').button();
	$('.event-listing').accordion();
	var filesize = 0;
	var max = 4; //MB
	$('input[name=image]').bind('change', function() {
		filesize = this.files[0].size;
	});
	$('form.form-standard').on('submit', function(e) {
		if( filesize > max*1024*1024 ) {
			e.preventDefault();
			jAlert('Max filesize: ' + max + 'MB', 'File too big');
		}
	});
});