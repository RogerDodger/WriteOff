jQuery(document).ready(function($) {
	$('a.ui-button, input[type=submit], button').button();
	$('.fake-ui-button').button({ disabled: true });
	
	//Event-listing
	var defaultEventIndex = $('.event-listing h3.event-name').index(
		$( '.event-listing h3 a' + (window.location.hash || '#null') ).parent()
	);
	$('.event-listing').accordion({ 
		active: defaultEventIndex >= 0 ? defaultEventIndex : false,
		collapsible: true,
		change: function(event, ui) {
			window.location.hash = ui.newHeader.children('a').attr('href') || '';
		}
	});
	
	$('a.new-window, a.new-tab').attr('target', '_blank');
	$('a.new-window, a.new-tab').attr('title', function(i, title) {
		return title || 'Open link in new tab';
	});
	
	$('input.autocomplete-user').autocomplete({
		source: '/user/list?view=json&order_by=username',
		minLength: 1,
	});
	
	//VoteRecord::fill form handlers
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
	
	//Dialogs
	$('.dialog-fetcher')
		.click( function(e) {
			var div = $('<div class="dialog"><div class="loading"></div></div>').appendTo('body');
			
			var pos = [ 'center', 40 ];
			
			div.dialog({
				title: 'Please Wait',
				modal: true,
				closeOnEscape: true,
				width: 'auto',
				resizable: false,
				close: function(ui, e) {
					div.remove();
				},
				position: pos
			});
			
			div.load(
				$(this).data('target'),
				function(res, status, xhr) {
					if( status != 'error' ) {
						div.find('a.ui-button, input[type=submit], button').button();
						
						//Order here is important
						div.dialog('option', 'title', div.find('h1').html() );
						div.find('h1').remove();
						div.dialog('option', 'position', pos);
						
						div.find('input:first').focus();
					}
					else {
						div.dialog('option', {
							position: pos,
							title: 'Error'
						})
						div.html( xhr.status + " " + xhr.statusText );
					}
				}
			);
		})
		.each( function() { 
			$(this).data('target', $(this).attr('href') );
		})
		.removeAttr('href');
	
	//Popups
	$('.popup-msg').fadeOut(5000, "easeInQuint");
});

function toggleField(id) {
	var field = document.getElementById(id);
	field.disabled = !field.disabled;
}