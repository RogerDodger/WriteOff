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
String.prototype.ucfirst = function() {
	return this.substring(0, 1).toUpperCase() + this.substring(1, this.length);
}

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
			var caller = this;
			$(this).parent().find('input').each(function() {
				if (this.name !== caller.name) {
					this.disabled = !caller.checked;
				}
			});
			if (this.name == 'has_fic') {
				$('input[name="wc_min"], input[name="wc_max"]').each(function () {
					this.disabled = !caller.checked;
				});
			}
		})
		.trigger('change');

	$('a.new-window, a.new-tab').attr('target', '_blank');
	$('a.new-window, a.new-tab').attr('title', function(i, title) {
		return title || 'Open link in new tab';
	});

	$('input.autocomplete-user').autocomplete({
		source: '/user/list?format=json&q=username',
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

//==========================================================================
// Auto-updating form for public votes
//==========================================================================

$(document).ready(function() {
	var $form = $('#auto-update');
	var $status_area = $(
		'<p class="status-msg ui-widget ui-corner-all ui-state-highlight">' +
		'<span class="ui-icon ui-icon-alert"></span> Automatic updates enabled' +
		'</p>');

	var type = $form.hasClass('public') ? 'vote' : 'guess';

	// Keep track of dirty fields in case the update fails.
	//
	// Similarly, to ensure there's no issue with concurrency (two votes being
	// submitted simultaneously), the dirty fields have to be cleared as soon
	// as they're accessed. There's still a *slight* possibility of race
	// conditions occuring with this setup, though, because JS culture doesn't
	// seem to like the idea of a proper locking mechanism. Disabling the form
	// while a vote updates is obviously not a good solution.
	var $dirty_fields = $();

	if ($form) {
		// Remove the manual update button
		$form.find('input[type="submit"]').parent().remove();

		// Add status updater below the form
		$status_area.insertAfter($form);

		$form.find('input,select').change(function(e) {
			// Each callback needs its own $submitting_fields to ensure
			// concurrent calls don't clobber it before it's used.
			var $submitting_fields;

			$status_area.removeClass('ui-state-error');
			$status_area.addClass('ui-state-highlight');
			$status_area.html(
				'<span class="ui-icon ui-icon-spinner"></span>' + "\n" +
				'Updating ' + type + '...'
			);

			$submitting_fields = $dirty_fields.add(this);
			// If an interrupt happens here, then its possible some dirty
			// fields never get updated. Unlikely, but possible.
			$dirty_fields = $();

			$.ajax({
				type: 'POST',
				url: window.location.pathname,
				data: $submitting_fields.serialize(),
				success: function(res, status, xhr) {
					$status_area.html(
						'<span class="ui-icon ui-icon-check"></span>' + "\n" +
						type.ucfirst() + ' updated'
					);

					$('#votes-received').html(
						$(res).find('#votes-received').text()
					);
				},
				error: function(xhr, status, err) {
					$status_area.removeClass('ui-state-highlight');
					$status_area.addClass('ui-state-error');
					$status_area.html(
						'<span class="ui-icon ui-icon-alert"></span>' + "\n" +
						'Error updating ' + type + ': ' + err + '.'
					);

					// The fields failed to send, so they're still dirty
					$dirty_fields = $dirty_fields.add($submitting_fields);
				}
			});
		});
	}
});

//==========================================================================
// Collapsing score breakdowns
//==========================================================================

$(document).ready(function() {
	var er_class = 'artist-breakdown-row';

	$('.artist-breakdown')
		.click(function() {
			var $icon = $(this).find('span');
			var $row = $(this).parent().parent();
			var $next = $row.next();

			// Expand
			if ($icon.hasClass('ui-icon-plus')) {
				$icon.removeClass('ui-icon-plus');
				$icon.addClass('ui-icon-minus');
				$(this).attr('title', 'Hide breakdown');

				if ($next.hasClass(er_class)) {
					$next.removeClass('hidden');
				}
				else {
					var $expand_row = $('<tr class="' + er_class + '"></tr>');
					var $expand_cell = $('<td colspan="5"></td>');

					$expand_row.addClass(
						$row.hasClass('odd') ? 'odd' : 'even'
					);
					$expand_row.html($expand_cell);
					$expand_row.insertAfter($row);

					$expand_cell.load(
						$(this).data('target'),
						function(res, status, xhr) {
							if (status != 'error') {
								$expand_cell.find('h1').remove();
							}
							else {
								$expand_cell.html(xhr.statusText);
							}
						}
					);
				}
			}
			else {
				// Collapse
				$icon.removeClass('ui-icon-minus');
				$icon.addClass('ui-icon-plus');
				$(this).attr('title', 'Show breakdown');

				if ($next.hasClass(er_class)) {
					// Check that the previous expand succeeded, to see
					// if we want to save the block or not
					if ($next.find('table')) {
						$next.addClass('hidden');
					}
					else {
						$next.remove();
					}
				}
			}
		})
		.each(function() {
			$(this).data('target', $(this).attr('href'));
		})
		.removeAttr('href');
});

//==========================================================================
// Story form wordcount checker
//==========================================================================


$(document).ready(function() {
	var $story = $("#story-field"), story;
	var $wc = $("#wordcount"), wc;
	var min = $story.data('min');
	var max = $story.data('max');

	$story.bind('keypress change', function(e) {
		story = this.value.trim();
		if (story.length) {
			wc = story.split(/\s+/).length;
		}
		else {
			wc = 0;
		}
		$wc.val(wc);
	});

	$story.bind('change', function(e) {
		this.setCustomValidity(
			min >= wc ? 'Too few words' :
			max <= wc ? 'Too many words' : ''
		);
	});
});
