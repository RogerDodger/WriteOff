function resetStoryFontSize() {
	var config = $.cookie('story-font-size') * 1 || 1;

	//min of 0.6em and max of 1.4em
	if(config < 0.6) config = 0.6;
	if(config > 1.4) config = 1.4;

	$('.story').css('font-size', config + 'em');
}

String.prototype.trim = function() {
	return this.replace(/^\s+|\s+$/g, "");
};
String.prototype.collapse = function() {
	return this.replace(/\s+/g, " ");
};
String.prototype.collate = function() {
	return this
		.toLowerCase()
		.trim()
		.collapse()
		.replace(/[^\x20-\x7E]/g, "");
};
String.prototype.regex = function() {
	//http://stackoverflow.com/questions/3446170/escape-string-for-use-in-javascript-regex
	return this.replace(/[\-\[\]\/\{\}\(\)\*\+\?\.\\\^\$\|]/g, "\\$&");
};

jQuery(document).ready(function($) {
	$('a.ui-button, input[type=submit], button').button();
	$('.fake-ui-button').button({ disabled: true });

	//Story font-size togglers
	resetStoryFontSize();
	$('aside.font-size-chooser a').on('click', function() {
		var a = $(this);
		if( a.hasClass('default') ) {
			$.removeCookie('story-font-size');
		}
		else {
			config = $.cookie('story-font-size') * 1 || 1;

			if( a.hasClass('bigger') )
				config += 0.05;
				if( config >= 1.4 ) config = 1.4;
			if( a.hasClass('smaller') ) {
				config -= 0.05;
				if( config < 0.6 ) config = 0.6;
			}

			$.cookie('story-font-size', config, { expires: 365 });
		}

		resetStoryFontSize();
	});

	//Event accordion
	var defaultEventIndex = $('.events h1.prompt').index(
		$( '.events h1 a' + (window.location.hash || '#null') ).parent()
	);
	$('.events').accordion({
		active: defaultEventIndex >= 0 ? defaultEventIndex : false,
		collapsible: true,
		change: function(event, ui) {
			window.location.hash = ui.newHeader.children('a').attr('href') || '';
		}
	});

	$('input[type="checkbox"].toggler')
		.on('change', function() {
			$(this).nextAll('input').get(0).disabled = !this.checked;
		})
		.trigger('change');

	$('a.new-window, a.new-tab').attr('target', '_blank');
	$('a.new-window, a.new-tab').attr('title', function(i, title) {
		return title || 'Open link in new tab';
	});

	$('input.autocomplete-user').autocomplete({
		source: '/user/list?view=json&order_by=username',
		minLength: 1,
	});

	// Image upload preview
	$('#preview img').each( function() {
		$(this).data('default', $(this).attr('src'));
	});
	$('input[name="image"]').on('change', function() {
		var img = $('#preview img');

		if(this.files && this.files[0]) {
			var reader = new FileReader();

			reader.onload = function(e) {
				img.attr('src', e.target.result);
			};

			reader.readAsDataURL(this.files[0]);
		}
		else {
			img.attr('src', img.data('default'));
		}
	});

	//VoteRecord::fill form handlers
	var sortable_update = function() {
		if(	$(this).children(':first').attr('data-name').collate()
			!= $('#sortable-confirm').attr('value').collate() )
		{
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
		if( this.value.collate()
			== $('#sortable').children(':first').attr('data-name').collate() ) {
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
});
