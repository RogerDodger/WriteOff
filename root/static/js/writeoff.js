/*
 * Dynamic web page behaviour for WriteOff
 *
 * Copyright (c) 2016 Cameron Thornton <cthor@cpan.org>
 *
 * This library is free software. You can redistribute it and/or modify
 * it under the same terms as Perl version 5.
 */

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

Date.prototype.daysInMonth = function () {
	var month = this.getUTCMonth();
	if (month == 4 || month == 6 || month == 9 || month == 11) {
		return 30;
	}
	else if (month == 2) {
		return this.leapYear() ? 29 : 28;
	}
	else {
		return 31;
	}
};

Date.prototype.delta = function (other) {
	var self                = this;
	var other_              = other || new Date();
	var significant_figures = 2;
	var units               = ['year', 'month', 'day', 'hour', 'minute', 'second'];
	var methods             = ['FullYear', 'Month', 'Date', 'Hours', 'Minutes', 'Seconds'];

	if (Math.abs(self.getTime() - other.getTime()) < 3000) {
		return 'just now';
	}

	if (other < self) {
		var ago = other.delta(self);
		return 'in ' + ago.substr(0, ago.length - 4);
	}

	var delta = {};
	units.forEach(function (unit, i) {
		var m = 'getUTC' + methods[i];
		delta[unit] = other[m]() - self[m]();
	});

	// Normalise delta to positive values
	if (delta['second'] < 0) {
		delta['minute']--;
		delta['second'] += 60;
	}

	if (delta['minute'] < 0) {
		delta['hour']--;
		delta['minute'] += 60;
	}

	if (delta['hour'] < 0) {
		delta['day']--;
		delta['hour'] += 24;
	}

	if (delta['day'] < 0) {
		delta['month']--;
		delta['day'] += self.daysInMonth();
	}

	if (delta['month'] < 0) {
		delta['year']--;
		delta['month'] += 12;
	}

	var deltas = [];
	units.forEach(function (unit) {
		if (significant_figures == 0) return;
		var n = delta[unit];
		if (n) deltas.push(n + " " + unit + (n == 1 ? '' : 's'));
		// Significant figures start counting as soon as a non-zero is found.
		if (deltas.length) significant_figures--;
	});

	var time;
	// x and y
	if (deltas.length <= 2) {
		time = deltas.join(" and ");
	}
	// x, y, and z
	else {
		deltas[deltas.length - 1] = "and " + deltas[deltas.length - 1];
		time = deltas.join(", ");
	};

	return time + " ago";
};

Date.prototype.leapYear = function () {
	var y = this.getUTCFullYear();
	return y % 4 == 0 && y % 100 != 0 || y % 400 == 0;
};

Date.prototype.getShortMonth = function () {
	return ["Jan", "Feb", "Mar", "Apr", "May", "Jun", "Jul", "Aug", "Sep", "Oct", "Nov", "Dec"][this.getMonth()];
};

Date.prototype.getDateSuffixed = function () {
	return this.getDate().ordinal();
};

Number.prototype.ordinal = function () {
	var ii = this % 100;
	var i = this % 10;
	return this + (i == 0 || i >= 4 || ii >= 11 && ii <= 13 ? "th" : ["st", "nd", "rd"][i-1]);
};

Number.prototype.zeropad = function (n) {
	var s = this + "";
	while (s.length < n) {
		s = "0" + s;
	}
	return s;
}

$(document).ready(function ($) {
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

	$('input.autocomplete-user').autocomplete({
		source: '/user/list?format=json&q=username',
		minLength: 1,
	});

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
					if (status != 'error') {
						//Order here is important
						div.dialog('option', 'title', div.find('h1').html());
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
// Auto-submit fields in marked forms
//==========================================================================

$(document).ready(function() {
	$('.Form.auto').each(function () {
		var $form = $(this);
		$form.find('input[type="submit"]').remove();

		var q = $.when();
		$form.find('input, select, textarea').on('change', function () {
			var $field = $(this);
			q.then(
				$.ajax({
					type: $form.attr('method'),
					url: $form.attr('action'),
					data: $field.serialize(),
					success: function () {
						$field.removeClass('Form-error');
					},
					error: function () {
						$field.addClass('Form-error');
					}
				})
			);
		});
	});
});

//==========================================================================
// Collapsing score breakdowns
//==========================================================================

$(document).ready(function() {
	$('.Breakdown')
		.click(function() {
			var $link = $(this);
			var $icon = $(this).find('i');
			var $row = $(this).closest('tr');

			while ($row.next() && $row.next().hasClass('Breakdown-row')) {
				$row.next().remove();
			}

			var expand = $icon.hasClass('fa-plus');
			$row.find('.Breakdown i').each(function () {
				$(this).removeClass('fa-minus');
				$(this).addClass('fa-plus');
				$(this).attr('title', 'Show breakdown');
			});

			if (expand) {
				$icon.removeClass('fa-plus');
				$icon.addClass('fa-minus');
				$icon.attr('title', 'Hide breakdown');

				var $expand_row = $row.clone().addClass('Breakdown-row');
				var $expand_cell = $('<td colspan="99"/>');
				$expand_row.html($expand_cell);

				$row.after($expand_row);
				$row.after('<tr class="Breakdown-row hidden"/>');

				if ($link.data('res')) {
					$expand_cell.html($link.data('res'));
				}
				else {
					$expand_cell.load(
						$link.data('target'),
						function(res, status, xhr) {
							if (status != 'error') {
								$expand_cell.find('h1').remove();
								$link.data('res', $expand_cell.html());
							}
							else {
								$expand_cell.html(xhr.statusTxt);
							}
						}
					);
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
		.domain([data[0].start, data[data.length-1].end])
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

	svg.selectAll('circle.boundary.start')
		.data(data.filter(function (e, i) {
			return i == 0 || e.start - data[i-1].end > 10 * 60 * 1000;
		}))
		.enter()
		.append('circle')
		.attr('title', function(d, i) {
			return d.start.toUTCString();
		})
		.attr('cx', function(d, i) {
			return scale(d.start);
		});

	svg.selectAll('circle.boundary.end')
		.data(data)
		.enter()
		.append('circle')
		.attr('title', function(d, i) {
			return d.end.toUTCString();
		})
		.attr('cx', function(d, i) {
			return scale(d.end);
		});

	svg.selectAll('circle')
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

	svg.selectAll('text.dates.start')
		.data(data.filter(function (e, i) {
			return i == 0 || e.start - data[i-1].end > 12 * 60 * 60 * 1000;
		}))
		.enter()
		.append('text')
		.text(function(d, i) {
			return d.start.getDate() + " " + d.start.getShortMonth();
		})
		.attr('title', function(d, i) {
			return d.start.toUTCString();
		})
		.attr('x', function(d, i) {
			return scale(d.start);
		});

	svg.selectAll('text.dates.end')
		.data(data)
		.enter()
		.append('text')
		.text(function(d, i) {
			return d.end.getDate() + " " + d.end.getShortMonth();
		})
		.attr('title', function(d, i) {
			return d.end.toUTCString();
		})
		.attr('x', function(d, i) {
			return scale(d.end);
		});

	svg.selectAll('text')
		.attr('text-anchor', 'middle')
		.attr('y', height / 2 + fontsize * 1.5)
		.attr('fill', 'black')
		.attr('font-size', fontsize * 0.9)
		.attr('font-family', 'sans-serif');

	svg.selectAll('text.labels')
		.data(data)
		.enter()
		.append('text')
		.text(function(d, i) {
			return d.name;
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
	var $events = $('.Event-header');
	$events.each(function () {
		if (this.dataset.nocollapse) {
			return;
		}

		var $btn = $(this);
		var $target = $btn.next();

		if ($target && $target.hasClass('Event-details')) {
			$btn.addClass('active');

			// Highlight events that are within 12 hours of having an active round
			var interesting = 0;
			if ($events.size() > 1 && 8 > $events.size()) {
				var hype = 1000 * 60 * 60 * 12;
				$target.find('.Event-timeline').data('timeline').forEach(function (e) {
					if (e.start.getTime() - hype < now.getTime() && now.getTime() < e.end.getTime() + hype) {
						interesting = 1;
					}
				});
			}

			if (interesting) {
				$btn.addClass('expanded');
			}
			else {
				$target.addClass('hidden');
			}

			$btn.click(function (e) {
				if (e.target.localName == 'a') {
					// Disable expand if the "permalink" is clicked
					return;
				}

				$btn.toggleClass('expanded');
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
	var $ballot = $('.Ballot.cast');

	if (!$ballot.length) {
		return;
	}

	var q = $.when();

	var resetPercentiles = function () {
		var n = $('.Ballot .ordered .Ballot-item').length;
		$('.Ballot .ordered .Ballot-score').each(function (i) {
			var score = 100 * (1 - i/(n - 1));
			this.innerHTML = '<span title="' + score.toFixed(5) + '">' + Math.round(score) + '%</span>';
		});
	};

	var sendOrder = function () {
		q.then(
			$.ajax({
				method: 'POST',
				url: document.location.pathname,
				data: $('.Ballot .ordered input[name="order"]').serialize()
			})
		);
	};

	Sortable.create($('.Ballot .ordered')[0], {
		group: {
			name: "ballot",
			pull: false,
			put: true
		},
		filter: '.Ballot-directions',
		onSort: function () {
			resetPercentiles();
			sendOrder();
		}
	});

	Sortable.create($('.Ballot .unordered')[0], {
		group: {
			name: "ballot",
			pull: true,
			put: false
		},
		filter: '.Ballot-append',
	});

	var moveup = function () {
		var $row = $(this).closest('.Ballot-item');
		var $target = $row.prev();

		if ($row.parent().hasClass('unordered')) {
			$row.detach();
			$('.Ballot-directions').before($row);
		}
		else if ($target.length && $target.hasClass('Ballot-item')) {
			$row.detach();
			$target.before($row);
		}
		else {
			return;
		}

		resetPercentiles();
		sendOrder();
	};

	var abstain = function () {
		var $row = $(this).closest('.Ballot-item');
		q.then(
			$.ajax({
				type: 'POST',
				url: document.location.pathname,
				data: {
					action: 'abstain',
					vote: $row.find('input').attr('value')
				},
				success: function (abstainsLeft) {
					$row.find('.Ballot-score').text('N/A');
					$row.detach();
					$('.Ballot .abstained').append($row);
					$('.Ballot .abstained').prev().removeClass('hidden');
					resetPercentiles();

					if (abstainsLeft <= 0) {
						$('.Ballot-abstain').addClass('hidden');
					}
				}
			})
		);
	};

	var unabstain = function () {
		var $row = $(this).closest('.Ballot-item');
		q.then(
			$.ajax({
				type: 'POST',
				url: document.location.pathname,
				data: {
					action: 'unabstain',
					vote: $row.find('input').attr('value')
				},
				success: function (abstainsLeft) {
					$row.detach();
					$('.Ballot-append').before($row);
					if ($('.Ballot .abstained .Ballot-item').length == 0) {
						$('.Ballot .abstained').prev().addClass('hidden');
					}

					if (abstainsLeft > 0) {
						$('.Ballot-abstain').removeClass('hidden');
					}
				}
			})
		);
	};

	$('.Ballot-abstain').click(abstain);
	$('.Ballot-unabstain').click(unabstain);
	$('.Ballot-up').click(moveup);

	$('.Ballot-append').click(function () {
		var $this = $(this);
		if (!$this.hasClass('active') || $this.hasClass('waiting')) {
			return;
		}
		$this.addClass('waiting');
		q.then(
			$.ajax({
				type: 'POST',
				url: document.location.pathname,
				data: {
					action: 'append'
				},
				success: function(res, status, xhr) {
					if (res == 'None left') {
						$this.removeClass('active');
					}
					else {
						var $row = $(res.substring(res.indexOf('<tr'), res.indexOf('tr>') + 3));
						$row.find('.Ballot-abstain').click(abstain);
						$row.find('.Ballot-unabstain').click(unabstain);
						$row.find('.Ballot-up').click(moveup);
						$this.before($row);
					}
				},
				complete: function(xhr, status) {
					$this.removeClass('waiting');
				}
			})
		);
	});
});

// ===========================================================================
// .Post modifiers
// ===========================================================================

// Anything that modifies a .Post needs not only be applied on page load, but
// also to new .Post elements loaded into the page.
//
// This array contains callbacks that refer to a passed context, e.g.
//
// function (context) {
//   $('.Element', context).each(...);
// };

var postModifiers = [];

postModifiers.apply = function (ctx) {
	// $(selector, ctx) will only match *descendants* of ctx, so we box ctx
	// in a div to make sure our selectors match everything in ctx
	if (!$(ctx).is(document)) {
		ctx = $('<div/>').append(ctx);
	}

	postModifiers.forEach(function (f) {
		f(ctx);
	});
};

// ===========================================================================
// <time> prettifiers
// ===========================================================================

postModifiers.push(function (ctx) {
	var $deltas = $('time.delta', ctx).not('.Countdown time');

	if ($deltas.size()) {
		var t, t0, ttl = $deltas.size();
		var tick = function tick (e) {
			t = new Date();
			// Same as above
			var now_ = now.getTime() + t.getTime() - t0.getTime() - 50;

			var delta = (new Date($(e).attr('datetime'))).delta(new Date(now_));
			e.textContent = delta;
			if (delta == 'just now' || /second/.test(delta) || /minute/.test(delta) && !/and/.test(delta)) {
				setTimeout(tick, 5000 + Math.random() * 5000, e);
			}
			else if (/minute/.test(delta) || /hour/.test(delta) && !/and/.test(delta)) {
				setTimeout(tick, 1000 * 60 + Math.random() * 500, e);
			}
			else {
				setTimeout(tick, 1000 * 60 * 60 + Math.random() * 500, e);
			}
		};
		t0 = new Date();
		$deltas.each(function () {
			tick(this);
		});
	}
});

$(document).ready(function () {
	var $countdowns = $('.Countdown time');
	var $dates = $('time.date');
	var $datetimes = $('time.datetime');

	if ($countdowns.size()) {
		var t, t0;
		var tick = function () {
			t = new Date();
			// `now` is defined in the global scope as the server's current time
			// this is used so that it's spoofable, and so that ountdowns are
			// based off the server's clock rather than the client's

			// 50ms is added for rounding purposes. The 1000ms interval can
			// end up being 998-1002ms. This can have the countdown seem to
			// skip a second as it goes from, for example, 4000ms to 2999ms to
			// 2000ms remaining.
			var now_ = now.getTime() + t.getTime() - t0.getTime() - 50;

			$countdowns.each(function () {
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
					h.zeropad(2) + "h " +
					m.zeropad(2) + "m " +
					s.zeropad(2) + "s";
			});
		};
		t0 = new Date();
		setInterval(tick, 1000);
		tick();
	}

	$dates.each(function () {
		var date = new Date($(this).attr('datetime'));
		this.textContent = date.getDate() + " " + date.getShortMonth() + " " + date.getFullYear();
	});

	$datetimes.each(function () {
		var date = new Date($(this).attr('datetime')),
		    z = date.getTimezoneOffset();

		this.textContent =
			date.getDate() + " " + date.getShortMonth() + " " + date.getFullYear() + " " +
			date.getHours().zeropad(2) + ":" +
			date.getMinutes().zeropad(2) + ":" +
			date.getSeconds().zeropad(2) + " " +
			(z > 0 ? "-" : "+") +
			Math.floor(Math.abs(z) / 60).zeropad(2) + (Math.abs(z) % 60).zeropad(2);
	})
});

// ===========================================================================
// Sortable tables
// ===========================================================================

$(document).ready(function () {
	$('.Results, .Scoreboard, .Prompts, .Ballot, .Artist-entries, .Storys.gallery').each(function () {
		if ($(this).find('thead').size()) {
			$(this).addClass('sortable');
			new Tablesort(this);
		}
	});
});

// ===========================================================================
// Story access flipper autoupdate
// ===========================================================================

$(document).ready(function () {
	$('.Storys-access').each(function () {
		var $form = $(this);
		$form.find('.Storys-access--update').remove();

		var q = $.when();
		$form.find('input[type="checkbox"]').on('change', function () {
			q.then(
				$.ajax({
					type: $form.attr('method'),
					url: $form.attr('action'),
					data: $form.serialize(),
				})
			);
		});
	});
})

// ===========================================================================
// Prompt and Post vote buttons
// ===========================================================================

postModifiers.push(function (ctx) {
	var q = $.when();
	$('.Prompts-vote--button, .Post-vote--button', ctx).on('click', function (e) {
		e.preventDefault();
		var $btn = $(this);
		var $form = $btn.closest('form');

		q = q.then(
			$.ajax({
				type: 'POST',
				url: $form.attr('action'),
				data: $form.serializeArray().concat({
					name: $btn.attr('name'),
					value: $btn.attr('value')
				}),
				success: function(res, status, xhr) {
					$form.attr('data-vote', res.vote);
					if ('score' in res) {
						$form.siblings().text(res.score || '');
					}
				},
				error: function(xhr, status, err) {
					alert('Vote failed: ' + err);
				}
			})
		);
	});
});

// ===========================================================================
// Artist swap buttons
// ===========================================================================

$(document).ready(function () {
	var q = $.when();
	var $btns = $('.Artist-swap');
	$btns.on('click', function (e) {
		e.preventDefault();
		var $btn = $(this);
		var $form = $btn.closest('form');

		q = q.then(
			$.ajax({
				type: 'POST',
				url: $form.attr('action'),
				data: $form.serializeArray(),
				success: function(res, status, xhr) {
					res = $.parseJSON(res);
					$btns.removeClass('active');
					$btn.addClass('active');

					$('.Artist-swap--selected')
						.text(res.name)
						.closest('a').attr('href', $btn.closest('li').find('a').attr('href'));

					$('.Post-submit').each(function () {
						var $post = $(this).closest('.Post');
						$post.find('.Post-author--name').text(res.name);
						$post.find('.Post-author--avatar img').attr('src', res.avatar);
					});
				}
			})
		);
	});
});

// ===========================================================================
// Post editor functions
// ===========================================================================

function replaceSelection(e, newSelection) {
	if ('selectionStart' in e) {
		e.focus();
		e.value = e.value.substr(0, e.selectionStart)
		        + newSelection.text
		        + e.value.substr(e.selectionEnd, e.value.length);

		e.selectionStart = newSelection.start;
		e.selectionEnd = newSelection.end;
	}
	// MSIE
	else if (document.selection) {
		e.focus();
		document.selection.createRange().text = newSelection.text;
	}
	// Unknown
	else {
		e.value += newSelection.text;
	}
};

function pushReply (reply) {
	var $textarea = $('.Post-submit textarea');

	if ($textarea.size()) {
		var selection = $textarea.getSelection();
		selection.text = ">>" + reply + "\n";
		selection.end = selection.start += selection.text.length;
		$textarea.focus();
		replaceSelection($textarea.get(0), selection);
		return 1;
	}
	else {
		return 0;
	}
};

$(document).ready(function () {
	var reply = localStorage.getItem('reply')
	if (reply && pushReply(reply)) {
		localStorage.removeItem('reply');
	}
});

postModifiers.push(function (ctx) {
	$('.Post-control--reply', ctx)
		.each(function() {
			$(this).data('redirect', $(this).attr('href'));
		})
		.removeAttr('href')
		.click(function () {
			var $btn = $(this);
			var reply = $btn.attr('data-target');

			if ($btn.data('redirect')) {
				localStorage.setItem('reply', reply)
				document.location = $btn.data('redirect');
			}
			else {
				pushReply(reply);
			}
		});
});

postModifiers.push(function (ctx) {
	$('.Post-control--edit', ctx)
		.removeAttr('href')
		.click(function () {
			$(this).closest('.Post').addClass('edit');
		});

	$('.Post-edit--cancel', ctx).click(function () {
		$(this).closest('.Post').removeClass('edit');
	});

	var q = $.when();
	$('.Post-edit--save', ctx).click(function () {
		var $btn = $(this);
		var $form = $btn.closest('form');
		var $post = $form.closest('.Post');

		q.then(
			$.ajax({
				method: 'POST',
				url: $form.attr('action'),
				data: $form.serializeArray(),
				success: function(res, status, xhr) {
					res = $.parseHTML(res);
					postModifiers.apply(res);
					$post.find('.Post-contents--body').empty().append(res);
				},
				error: function(xhr, status, error) {
					alert('Error: ' + error);
				},
				complete: function() {
					$post.removeClass('edit');
				}
			})
		);
	});
});

postModifiers.push(function (ctx) {
	var markup = [
		[ '.fa-bold',          'b', false, 66 ],
		[ '.fa-italic',        'i', false, 73 ],
		[ '.fa-underline',     'u', false, 85 ],
		[ '.fa-strikethrough', 's', false, 83 ],

		[ '.fa-link',        'url', true ],
		[ '.fa-text-height', 'size', true ],
		[ '.fa-font',        'color', true ],

		[ '.fa-quote-right',  'quote', false, 81 ],
		[ '.fa-align-center', 'center', false ],
		[ '.fa-align-right',  'right', false ],
	];
	var $controls = $('.Post-form--controls', ctx);

	markup.forEach(function (e) {
		var icon = e[0],
		    code = e[1],
		    hasArg = e[2],
		    hotkey = e[3];

		var clicked = function ($textarea) {
			var selection = $textarea.getSelection();

			if (hasArg) {
				selection.text = '[' + code + '=""]' + selection.text + '[/' + code + ']';
				selection.end = selection.start += 3 + code.length;
			}
			else {
				selection.text = '[' + code + ']' + selection.text + '[/' + code + ']';
				selection.start += 2 + code.length;
				selection.end += 2 + code.length;
			}
			$textarea.focus();
			replaceSelection($textarea.get(0), selection);
		};

		$controls.find(icon).click(function () {
			clicked($(this).closest('form').find('textarea'));
		});

		if (typeof hotkey === 'undefined') return;

		$('.Post-form--body textarea', ctx).on('keydown', function (ev) {
			if (ev.ctrlKey && ev.which == hotkey) {
				ev.preventDefault();
				clicked($(this));
			}
		});
	});
});

// ===========================================================================
// Dynamic paging
// ===========================================================================

var $orphans = [];

function loadOrphan (id) {
	return $.ajax({
		method: 'GET',
		url: '/post/' + id + '/view',
		data: {
			event_id : event_id,
			entry_id : entry_id,
		},
		success: function (res, status, xhr) {
			res = $.parseHTML(res);
			postModifiers.apply(res);
			$orphans[id] = $(res).filter('.Post');
		},
	});
}

$(document).ready(function () {
	var $pager = $('.Pager');
	var $page = function (page) {
		return $('.Post.view[data-page="' + page + '"]');
	};
	var key = document.location.pathname + '/page';

	var loadPage = function (page) {
		var req = {
			url: document.location.pathname,
			data: {
				'page' : page
			}
		};

		if ($page(page).size()) {
			req.method = 'POST';
			req.data.dry = 1;
			$.ajax(req);
			return $.when();
		}

		$pager.addClass('loading');
		req.method = 'GET';
		req.success = function (res, status, xhr) {
			res = $.parseHTML(res);
			postModifiers.apply(res);
			$('.Posts').append($(res).find('.Post'));
			$pager.removeClass('loading');
		};
		return $.ajax(req);
	};

	var changePage = function (page) {
		return loadPage(page).then(function () {
			$('.Post.view').addClass('hidden');
			$page(page).removeClass('hidden');
			$('.Pager a').removeClass('selected').each(function () {
				var $this = $(this);
				if ($this.text() == page) {
					$this.addClass('selected');
				}
			});
		});
	};

	if ($pager.size()) {
		$pager.find('a').removeAttr('href').click(function () {
			var $this = $(this);
			if (!$this.hasClass('selected') && !$pager.hasClass('loading')) {
				changePage($this.text()).then(function () {
					if ($this.closest('.Pager').hasClass('bottom')) {
						$('html, body').scrollTop($('.Pager.top').offset().top);
					}
				})
			}
		});
	}

	var hashchanged = function () {
		$('.Post.highlight').removeClass('highlight');

		if (document.location.hash.search(/^#[0-9]+$/) != -1) {
			var $post = $('.Post' + document.location.hash);
			var pid = document.location.hash.substr(1);
			var q = $.when();

			var jump = function () {
				$post.addClass('highlight');
				$('html, body').scrollTop($post.offset().top);
			};

			if ($post.size()) {
				if ($post.hasClass('hidden')) {
					q = changePage($post.attr('data-page'));
				}
				q.then(jump);
			}
			else {
				if (!$orphans[pid]) {
					q = loadOrphan(pid);
				}

				q.then(function () {
					var $orphan = $orphans[pid];
					if ($orphan && $orphan.attr('data-page')) {
						changePage($orphan.attr('data-page')).then(function () {
							$post = $('.Post' + document.location.hash);
							jump();
						});
					}
				})
			}
		}
	};

	$(window).on('hashchange', hashchanged);
	hashchanged();
});

// ===========================================================================
// More responsive behaviour for post reply links
// ===========================================================================

postModifiers.push(function (ctx) {
	var q = $.when();

	$('.Post-reply', ctx)
		.on('mouseenter', function () {
			var $reply = $(this);
			var $caller = $reply.closest('.Post');
			var tid = $reply.attr('data-target');
			var $target = $('.Post#' + tid);
			var $hover = $('<div class="Post-hover"/>');

			if ($target.size()) {
				$target = $target.clone().removeClass('hidden');
			}
			else if ($orphans[tid]) {
				$target = $orphans[tid];
			}
			else {
				$reply.addClass('loading');
				q = loadOrphan(tid).then(function () {
					$reply.removeClass('loading');
					$target = $orphans[tid];
				});
			}

			q.then(function () {
				$hover.css({
					top: $reply.offset().top + $reply.outerHeight() * 1.2,
					left: $caller.offset().left - $('body').css('font-size').replace(/px/,''),
				});

				if ($reply.is(':hover')) {
					$hover.append($target);
					$('body').append($hover);
				}
			});
		})
		.on('mouseleave', function () {
			$('.Post-hover').remove();
		})
		.on('click', function () {
			var $reply = $(this);

			q.then(function () {
				var tid = $reply.attr('data-target');

				var $post = $('.Post#' + tid);
				if (!$post.size()) {
					$post = $orphans[tid];
				}

				if ($post.size() && $post.attr('data-page')) {
					document.location.hash = tid;
				}
				else {
					window.location = '/post/' + tid;
				}
			});
		})
		.removeAttr('href');
});

// ===========================================================================
// New avatar preview
// ===========================================================================

$(document).ready(function () {
	$('input[name="avatar"]').on('change', function() {
		var $avatar = $('.Artist-avatar img');

		if (!$avatar.data('default')) {
			$avatar.data('default', $avatar.attr('src'));
		}

		if (this.files && this.files[0]) {
			var reader = new FileReader();

			reader.onload = function(e) {
				$avatar.attr('src', e.target.result);
			};

			reader.readAsDataURL(this.files[0]);
		}
		else {
			$avatar.attr('src', $avatar.data('default'));
		}
	});
});

// ===========================================================================
// Story font selector
// ===========================================================================

$(document).ready(function () {
	var $select = $('.Font-select');
	var $example = $('.Story-example');

	$example.removeClass('hidden');
	$select.on('change', function () {
			$example.css('font-family', $select.find(':selected').val());
		})
		.trigger('change');
});

// ===========================================================================
// Apply post modifiers to document
// ===========================================================================

$(document).ready(function () {
	postModifiers.apply(document);
});
