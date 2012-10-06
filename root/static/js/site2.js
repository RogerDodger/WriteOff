jQuery(document).ready(function($) {
	$('a.ui-button, input[type=submit], input[type=reset], button, .fake-ui-button').button();
	$('.event-listing').accordion();
	$('.userbar .ui-state-highlight, .userbar .ui-state-error').fadeOut(5000, "easeInQuint");
	$('a.new-window').attr('target', '_blank');
	$('a.new-window').attr('title', function(i, title) {
		return title || 'Open link in new tab';
	});
	$('input.autocomplete-user').autocomplete({
		source: '/user/list?view=json&order_by=username',
		minLength: 1,
	});
});

function toggleField(id) {
	var field = document.getElementById(id);
	field.disabled = !field.disabled;
}