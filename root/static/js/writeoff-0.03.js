jQuery(document).ready(function($) {
	$('a.ui-button, input[type=submit], input[type=reset], button, .fake-ui-button').button();
	
	{ //Event-listing accordion magic
		var index = $('.event-listing h3').index(
			$( '.event-listing h3 a[href="' + window.location.hash + '"]' ).parent()
		);
		$('.event-listing').accordion({ 
			active: index,
			change: function(event, ui) {
				window.location.hash = ui.newHeader.children('a').attr('href');
			}
		});
	}
	$('.userbar .ui-state-highlight, .userbar .ui-state-error').fadeOut(5000, "easeInQuint");
	$('a.new-window').attr('target', '_blank');
	$('a.new-window').attr('title', function(i, title) {
		return title || 'Open link in new tab';
	});
	$('input.autocomplete-user').autocomplete({
		source: '/user/list?view=json&order_by=username',
		minLength: 1,
	});
	var sortable_update = function() {
		if(	$(this).children(':first').attr('data-name') != $('#sortable-confirm').attr('value') ) {
			$('#sortable-submit').button('disable');
			$('#sortable-confirm').attr('value', '');
		}
		var data = '';
		$(this).children().each( function(i) {
			if( i != 0 ) data += ';';
			data += $(this).attr('data-id');
		});
		$('#sortable-data').attr('value', data);
	};
	$('#sortable').sortable({
		update: sortable_update,
		create: sortable_update
	});
	$('#sortable-confirm').on('input', function() {
		if( this.value == $('#sortable').children(':first').attr('data-name') ) {
			$('#sortable-submit').button('enable');
		}
	});
});

function toggleField(id) {
	var field = document.getElementById(id);
	field.disabled = !field.disabled;
}