jQuery(document).ready(function($) {
	$('a.ui-button, input[type=submit], input[type=reset], button, .fake-ui-button').button();
	$('.event-listing').accordion();
	$('.has-placeholder').focus(function() {
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
	}).blur();
	$('.userbar .ui-state-highlight, .userbar .ui-state-error').fadeOut(5000, "easeInQuint");
	var uploadOk = 0;
	$('a.new-window').attr({
		target : '_blank',
		title  : 'Open link in new tab',
	});
	var filesize = 0;
	var max = 4; //MB
	$('input[name=image]').bind('change', function() {
		filesize = this.files[0].size;
	});
	$('form.form-standard').on('submit', function(e) {
		if( filesize > max*1024*1024 ) {
			e.preventDefault();
			alert('Max filesize: ' + max + 'MB');
		}
	});
});