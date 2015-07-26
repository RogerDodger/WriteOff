function resetStoryFontSize() {
	var config = $.cookie('story-font-size') * 1 || 1;

	//min of 0.6em and max of 1.4em
	if(config < 0.6) config = 0.6;
	if(config > 1.4) config = 1.4;

	$('.story').css('font-size', config + 'em');
}

function removeStatus(el) {

}

function pushStatus () {

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
};

Date.prototype.getShortMonth = function () {
	return ["Jan", "Feb", "Mar", "Apr", "May", "Jun", "Jul", "Aug", "Sep", "Oct", "Nov", "Dec"][this.getMonth()];
};

Date.prototype.getDateSuffixed = function () {
	this.getDate().ordinal();
};

Number.prototype.ordinal = function () {
	var ii = this % 100;
	var i = this % 10;
	return this + (i == 0 || i >= 4 || ii >= 11 && ii <= 13 ? "th" : ["st", "nd", "rd"][i-1]);
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

	//Dialogs
	$('.dialog-fetcher')
		.click( function(e) {
			var div = $(
				'<div class="dialog"><div class="loading"></div></div>'
			).appendTo('body');

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

	$story.bind('input change', function(e) {
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
			min > wc ? 'Too few words' :
			max < wc ? 'Too many words' : ''
		);
	});
});

//==========================================================================
// VoteRecord::fill magic
//==========================================================================

$(document).ready(function() {
	var datamunge = function() {
		var data = '';
		$(this).children().each( function(i) {
			if( i != 0 ) data += ';';
			data += $(this).attr('data-id');
		});
		$('#sortable-data').attr('value', data);
	};

	$('#sortable').sortable({
		update: datamunge,
		create: datamunge
	});


	var absCheck = function () {
		if (this.checked) {
			$('#sortable li').addClass('ui-state-disabled');
		}
		else {
			$('#sortable li').removeClass('ui-state-disabled');
		}
	};

	// Set the handler and call it with right context
	absCheck.call($('input[name=abstain]').click(absCheck).get(0));
});

// ===========================================================================
// FAQ Expander
// ===========================================================================

$(document).ready(function() {
	$('.expander').each(function() {
		var $btn = $(this);
		var $target = $btn.next();
		if ($target && $target.hasClass('expandable')) {
			$btn.addClass('active');
			$target.addClass('hidden');
			$btn.click(function() {
				$target.toggleClass('hidden');
			});
		}
	});
});

// ===========================================================================
// Draw event timelines
// ===========================================================================

function DrawTimeline (e) {
	var data = $(e).data('timeline');
	var width = $(e).width();
	var height = 95;
	var fontsize = 14;
	var xpad = fontsize * 3;

	// Don't draw if the container is hidden
	if (!width) {
		return;
	}

	var scale = d3.time.scale()
		.domain([data[1].start, data[data.length-1].end])
		.range([0 + xpad, width - xpad]);

	// Clear previous draw
	d3.select(e).selectAll('svg').remove();

	var svg = d3.select(e)
		.append('svg')
		.attr('width', width)
		.attr('height', height);

	svg.append('line')
		.attr('stroke', 'black')
		.attr('x1', 0)
		.attr('y1', height / 2)
		.attr('x2', width)
		.attr('y2', height / 2);

	svg.selectAll('circle.boundary')
		.data(data)
		.enter()
		.append('circle')
		.attr('title', function(d, i) {
			return d.end.toUTCString();
		})
		.attr('cx', function(d, i) {
			return scale(d.end);
		})
		.attr('cy', height / 2)
		.attr('r', 5)
		.attr('fill', 'grey')
		.attr('stroke', 'black')
		.attr('stroke-width', 1);

	svg.append('circle')
		.attr('title', function(d, i) {
			return now.toUTCString();
		})
		.attr('cx', scale(now))
		.attr('cy', height / 2)
		.attr('r', 4)
		.attr('fill', 'red')
		.attr('stroke', 'black')
		.attr('stroke-width', 1);

	svg.selectAll('text.dates')
		.data(data)
		.enter()
		.append('text')
		.text(function(d, i) {
			return d.end.getDate() + " " + d.end.getShortMonth();
		})
		.attr('title', function(d, i) {
			return d.end.toUTCString();
		})
		.attr('text-anchor', 'middle')
		.attr('y', height / 2 + fontsize * 1.5)
		.attr('x', function(d, i) {
			return scale(d.end);
		})
		.attr('fill', 'black')
		.attr('font-size', fontsize * 0.9)
		.attr('font-family', 'sans-serif');

	svg.selectAll('text.rounds')
		.data(data.slice(1))
		.enter()
		.append('text')
		.text(function(d, i) {
			return d.round;
		})
		.attr('text-anchor', 'middle')
		.attr('x', function(d, i) {
			return (scale(d.end) + scale(d.start)) / 2;
		})
		.attr('y', height / 2 - fontsize * 0.75)
		.attr('fill', 'black')
		.attr('font-size', fontsize)
		.attr('font-family', 'sans-serif');
};

$(document).ready(function () {
	$('.Event-timeline').each(function () {
		var timeline = timelines.shift();

		timeline.forEach(function (t) {
			if ('start' in t) {
				t.start = new Date(t.start + "Z");
			}
			t.end = new Date(t.end + "Z");
		});

		$(this).removeClass('hidden');
		$(this).data('timeline', timeline);
		DrawTimeline(this);
	});

	$(window).on('resize', function () {
		$('.Event-timeline').each(function () {
			DrawTimeline(this);
		});
	});
});

// ===========================================================================
// Event Expander
// ===========================================================================

$(document).ready(function () {
	$('.Event-header').each(function () {
		if (this.dataset.autoexpand) {
			return;
		}

		var $btn = $(this);
		var $target = $btn.next();

		if ($target && $target.hasClass('Event-details')) {
			$btn.addClass('active');
			$target.addClass('hidden');
			$btn.click(function (e) {
				if (e.target.localName == 'a') {
					// Disable expand if the "permalink" is clicked
					return;
				}

				$target.toggleClass('hidden');
				if (!$target.hasClass('hidden')) {
					DrawTimeline($target.find('.Event-timeline').get(0));
				}
			});
		}
	})
});

// ===========================================================================
// Ballot sorting and posting
// ===========================================================================

$(document).ready(function () {
	var $ballot = $('.Ballot');

	if (!$ballot.length) {
		return;
	}

	var resetPercentiles = function () {
		var n = $('.ordered .Ballot-item').length;
		$('.ordered .Ballot-item').each(function (i) {
			var score = 100 * (1 - i/(n - 1));
			this.cells[0].innerHTML = '<span title="' + score.toFixed(5) + '">' + Math.round(score) + '</span>';
		});
	};

	Sortable.create($('.ordered tbody')[0], {
		group: {
			name: "ballot",
			pull: false,
			put: true
		},
		filter: '.Ballot-directions',
		onSort: function () {
			resetPercentiles();
			$.ajax({
				method: 'POST',
				url: document.location.pathname,
				data: {
					order: $('.ordered input[name=order]').map(function () {
						return this.value;
					}).get()
				},
			});
		}
	});

	Sortable.create($('.unordered tbody')[0], {
		group: {
			name: "ballot",
			pull: true,
			put: false
		},
		filter: '.Ballot-append',
	});

	var waiting = false;
	$('.Ballot-append').click(function () {
		if (waiting) {
			return;
		}
		waiting = true;
		$('.Ballot-append--wait').removeClass('hidden');
		$('.Ballot-append--control').addClass('hidden');

		$.ajax({
			type: 'POST',
			url: document.location.pathname,
			data: {
				action: 'append'
			},
			success: function(res, status, xhr) {
				var $row = $(res.substring(res.indexOf('<tr'), res.indexOf('tr>') + 3));
				$('.Ballot-append').before($row);
			},
			complete: function(xhr, status) {
				waiting = false;
				$('.Ballot-append--wait').addClass('hidden');
				$('.Ballot-append--control').removeClass('hidden');
			}
		})
	});

	$('.Ballot-abstain').click(function () {
		if (waiting) {
			return;
		}
		waiting = true;

		var $button = $(this);
		var $row = $button.parents('.Ballot-item');
		$.ajax({
			type: 'POST',
			url: document.location.pathname,
			data: {
				action: 'abstain',
				vote: $row.find('input').attr('value')
			},
			success: function(res, status, xhr) {
				if (!$row.parents('.Ballot-part').hasClass('abstained')) {
					$button.text('Unabstain');
					$row.find('td').first().text('N/A');
					$row.detach();
					$('.abstained tbody').append($row);
					$('.abstained, .Ballot-divider--abstain').removeClass('hidden');
					resetPercentiles();

					if (res <= 0) {
						$('.ordered .Ballot-abstain, .unordered .Ballot-abstain').addClass('hidden');
					}
				}
				else {
					$button.text('Abstain');
					$row.detach();
					$('.Ballot-append').before($row);
					if ($('.abstained .Ballot-item').length == 0) {
						$('.abstained, .Ballot-divider--abstain').addClass('hidden');
					}

					if (res > 0) {
						$('.Ballot-abstain').removeClass('hidden');
					}
				}
			},
			complete: function(xhr, status) {
				waiting = false;
			}
		});
	})
})

// ===========================================================================
// Countdowns
// ===========================================================================

$(document).ready(function () {
	var $times = $('.Countdown time');
	if ($times.length) {
		var elapsed = 0;
		var tick = function () {
			// `now` is defined in the global scope as the server's current time
			// this is used so that it's spoofable, and so that ountdowns are
			// based off the server's clock rather than the client's
			var now_ = now.getTime() + elapsed;

			$times.each(function () {
				var ms = (new Date($(this).attr('datetime'))).getTime() - now_;

				if (ms < 0) {
					ms = 0;
				}

				var s = ms / 1000;
				var m = s / 60;
				var h = m / 60;
				var d = h / 24;

				s = Math.floor(s) % 60;
				m = Math.floor(m) % 60;
				h = Math.floor(h) % 24;
				d = Math.floor(d);

				this.textContent = d + "d " +
					(h < 10 ? "0" + h : h) + "h " +
					(m < 10 ? "0" + m : m) + "m " +
					(s < 10 ? "0" + s : s) + "s";
			});
			elapsed += 1000;
		};
		setInterval(tick, 1000);
		tick();
	}
});
