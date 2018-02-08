/*
 * Dynamic web page behaviour for WriteOff
 *
 * Copyright (c) 2016 Cameron Thornton <cthor@cpan.org>
 *
 * This library is free software. You can redistribute it and/or modify
 * it under the same terms as Perl version 5.
 */

Array.prototype.uniq = function() {
	var u = [];
	var h = {};
	for (var i = 0; i < this.length; ++i) {
		if (!h[this[i]]) {
			h[this[i]] = true;
			u.push(this[i]);
		}
	}
	return u;
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

Date.prototype.daysInMonth = function () {
	var month = this.getUTCMonth() + 1;
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

Date.deltaUnits = ['year', 'month', 'day', 'hour', 'minute', 'second'];
Date.deltaMethods = ['FullYear', 'Month', 'Date', 'Hours', 'Minutes', 'Seconds'];

Date.prototype._delta = function (other_) {
	var self = this;
	var other = other_;

	// The delta is always positive, so `self` must be the smaller date
	if (self > other) {
		other = self;
		self = other_;
	}

	var delta = {};
	Date.deltaUnits.forEach(function (unit, i) {
		var m = 'getUTC' + Date.deltaMethods[i];
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

	return delta;
}

Date.prototype.delta = function (other_, sigFigs_) {
	var self = this;
	var other = other_ || new Date();
	var sigFigs = sigFigs_ || 2;

	if (Math.abs(self.getTime() - other.getTime()) < 3000) {
		return 'just now';
	}

	var delta = self._delta(other);
	var strings = [];

	Date.deltaUnits.forEach(function (unit) {
		if (!sigFigs) return;
		var n = delta[unit];
		if (n) strings.push(n + " " + unit + (n == 1 ? '' : 's'));
		// Significant figures start counting as soon as a non-zero is found.
		if (strings.length) sigFigs--;
	});

	var ret;
	// x and y
	if (strings.length <= 2) {
		ret = strings.join(" and ");
	}
	// x, y, and z
	else {
		strings[strings.length - 1] = ", and " + strings[strings.length - 1];
		ret = strings.join(", ");
	};

	if (other < self) {
		return "in " + ret;
	}
	else {
		return ret + " ago";
	}
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

function decode_utf8 (s) {
  return decodeURIComponent(escape(s));
}

// t0 is compared against the real current time to determine how long the page
// has been opened. This is useful to know what the "current" time is when
// using a mocked now.
var t0 = new Date();

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

	// Don't draw if there's no data
	if (!data || !data.length) {
		return;
	}

	data.sort(function (a, b) {
		return a.start.getTime() - b.start.getTime();
	});

	var modes = data.map(function (e) { return e.mode; }).uniq();

	var width = $(e).width();
	var heightMode = 65;
	var fontsize = 14;
	var xpad = fontsize * 2;

	// Don't draw if the container is hidden
	if (!width) {
		return;
	}

	var scale = d3.time.scale()
		.domain([
			data[0].start,
			Math.max.apply(null, data.map(function (e) { return e.end; }))
		])
		.range([0 + xpad, width - xpad]);

	// Clear previous draw
	d3.select(e).selectAll('svg').remove();

	var svg = d3.select(e)
		.append('svg')
		.attr('width', width)
		.attr('height', heightMode * modes.length);

	modes.forEach(function (m, i) {
		var rounds = data.filter(function (e) { return e.mode === m; });
		var g = svg.append('g');
		var cy = heightMode * (i + 0.5);

		g.selectAll('line.timeline')
			.data(rounds)
			.enter()
			.append('line')
			.attr('stroke', 'black')
			.attr('x1', function (d) {
				return scale(d.start);
			})
			.attr('x2', function (d) {
				return scale(d.end);
			})
			.attr('y1', cy)
			.attr('y2', cy);

		g.selectAll('circle.boundary.start')
			.data(rounds.filter(function (e, i) {
				return i == 0 || Math.abs(e.start - rounds[i-1].end) > 10 * 60 * 1000;
			}))
			.enter()
			.append('circle')
			.attr('cx', function(d, i) {
				return scale(d.start);
			})
			.append('svg:title').text(function(d) {
				return d.start.toUTCString();
			});

		g.selectAll('circle.boundary.end')
			.data(rounds)
			.enter()
			.append('circle')
			.attr('cx', function(d, i) {
				return scale(d.end);
			})
			.append('svg:title').text(function(d) {
				return d.end.toUTCString();
			});

		g.selectAll('circle')
			.attr('cy', cy)
			.attr('r', 5)
			.attr('fill', 'grey')
			.attr('stroke', 'black')
			.attr('stroke-width', 1);

		g.append('circle')
			.attr('cx', scale(now))
			.attr('cy', cy)
			.attr('r', 4)
			.attr('fill', 'red')
			.attr('stroke', 'black')
			.attr('stroke-width', 1)
			.append('svg:title').text(function(d) {
				return now.toUTCString();
			});

		g.selectAll('text.dates.start')
			.data(rounds.filter(function (e, i) {
				return i == 0 || Math.abs(e.start - rounds[i-1].end) > 12 * 60 * 60 * 1000;
			}))
			.enter()
			.append('text')
			.text(function(d, i) {
				return d.start.getDate() + " " + d.start.getShortMonth();
			})
			.attr('x', function(d, i) {
				return scale(d.start);
			})
			.append('svg:title').text(function(d) {
				return d.start.toUTCString();
			});

		g.selectAll('text.dates.end')
			.data(rounds)
			.enter()
			.append('text')
			.text(function(d, i) {
				return d.end.getDate() + " " + d.end.getShortMonth();
			})
			.attr('x', function(d, i) {
				return scale(d.end);
			})
			.append('svg:title').text(function(d) {
				return d.end.toUTCString();
			});

		g.selectAll('text')
			.attr('text-anchor', 'middle')
			.attr('y', cy + fontsize * 1.5)
			.attr('fill', 'black')
			.attr('font-size', fontsize * 0.9)
			.attr('font-family', 'sans-serif');

		g.selectAll('text.labels')
			.data(rounds)
			.enter()
			.append('text')
			.text(function(d, i) {
				return d.name;
			})
			.attr('text-anchor', 'middle')
			.attr('x', function(d, i) {
				return (scale(d.end) + scale(d.start)) / 2;
			})
			.attr('y', cy - fontsize * 0.75)
			.attr('fill', 'black')
			.attr('font-size', fontsize)
			.attr('font-family', 'sans-serif');
	});
};

$(document).ready(function () {
	$('.Event-timeline').each(function () {
		var timeline = timelines.shift();

		if (typeof timeline === "undefined") {
			return;
		}

		console.log(typeof timeline, timeline)

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
// Guess graph
// ===========================================================================

function DrawGuessGraph (e) {
	var fontsize = parseFloat($(e).css('font-size'));
	var ypad = fontsize * 3;
	var xpad = fontsize * 0.75;
	var vrad = xpad - 1;
	var lmrg = fontsize * 0.3;
	var gwid = fontsize * 0.15;

	var data = $(e).data('graph');
	var width = $(e).width();
	var rows = Math.max(
		data.theorys.length, data.artists.length, data.entrys.length);
	var height = (vrad * 2 + fontsize + lmrg) * (2 + rows);

	var yrange = [0 + ypad, height - vrad - 1];

	var tscale = d3.scale.linear()
		.domain([0, data.theorys.length - 1])
		.range(yrange);

	var ascale = d3.scale.linear()
		.domain([0, data.artists.length - 1])
		.range(yrange);

	var escale =  d3.scale.linear()
		.domain([0, data.entrys.length - 1])
		.range(yrange);

	var tx = 0 + xpad;
	var ax = width / 2;
	var ex = width - xpad;

	data.artists.sort(function (a, b) {
		if (a.name.collate() < b.name.collate()) {
			return -1;
		}
		if (a.name.collate() > b.name.collate()) {
			return 1;
		}
		return 0;
	});

	var ty = {}, ay = {}, ey = {};
	data.theorys.forEach(function (e, i) { ty[e.id] = i; });
	data.artists.forEach(function (e, i) { ay[e.id] = i; });
	data.entrys.forEach( function (e, i) { ey[e.id] = i; });

	// Clear previous draw
	d3.select(e).selectAll('svg').remove();

	var svg = d3.select(e)
		.append('svg')
		.attr('width', width)
		.attr('height', height);

	var dimg = svg.append('g').classed('guess-dim', true);
	var focusg = svg.append('g').classed('guess-focus', true);
	var labelg = svg.append('g').classed('labels', true);
	var nodeg = svg.append('g').classed('nodes', true);

	var drawGuessLines = function (guesses, focus) {
		var line = d3.svg.line()
			.x(function (d) { return d.x; })
			.y(function (d) { return d.y; })
			.interpolate("cardinal");

		var guessLine = function (e) {
			return [
				{ x: tx, y: tscale(ty[e.theory_id]) },
				{ x: ax, y: ascale(ay[e.guessed_id]) },
				{ x: ex, y: escale(ey[e.entry_id]) },
			];
		};

		var greenLines = guesses
			.filter(function (e) { return e.correct; })
			.map(guessLine);

		var redLines = guesses
			.filter(function (e) { return !e.correct; })
			.map(guessLine);

		var lines = [
			[redLines,     'red', 0 ],
			[greenLines, 'green', 120 ],
		];

		var container = focus ? focusg : dimg;

		lines.forEach(function (e) {
			var data = e[0],
				class_ = e[1],
				hue = e[2],
				color = "hsla(" + hue + ",75%," + (focus ? "70%" : "93%") + ",1)";

			container.selectAll('path.' + class_)
				.data(data)
				.enter()
				.append('path')
				.classed(class_, true)
				.attr('d', line)
				.attr('fill', 'transparent')
				.attr('stroke', color)
				.attr('stroke-width', gwid);
		});
	};

	drawGuessLines(data.guesses);

	var cols = [
		[ 'theorys', 'artist_name', 'theory_id',  'start',  tx, tx + vrad + lmrg, tscale ],
		[ 'artists', 'name',        'guessed_id', 'middle', ax, ax,               ascale ],
		[ 'entrys',  'title',       'entry_id',   'end',    ex, ex - vrad - lmrg, escale ],
	].map(function (e) {
		var ret = {};
		['name', 'id', 'fk', 'anchor', 'cx', 'tx', 'scale'].forEach(function (k, i) {
			ret[k] = e[i];
		});
		ret.class_ = ret.name.slice(0, -1);
		return ret;
	});

	var focused = [];
	// 1. If no lines are focused, clicking on a node will focus all
	// intersecting lines.

	// 2. If lines are already focused, then only intersecting lines that were
	// already focused remain focused.

	// 3. If cliking a node doesn't unfocus any lines, then all lines are
	// unfocused.

	// 4. If no lines are focused, focus all lines intersecting the
	// clicked node.
	svg.on('click', function () {
		var t = d3.event.target;

		focusg.selectAll('*').remove();

		var intersect;
		if (t.tagName !== "circle") {
			intersect = function () { return false; };
		}
		else {
			var col = cols.find(function (e) {
				return t.cx.baseVal.value - e.cx < 0.1;
			});

			if (typeof col === 'undefined') return;

			var idx = Math.round(col.scale.invert(t.cy.baseVal.value));
			var id = data[col.name][idx].id;
			intersect = function (g) {
				return g[col.fk] === id;
			};
		}

		var l = focused.length;

		// (1)
		if (!focused.length) focused = data.guesses;

		// (2)
		focused = focused.filter(intersect);

		// (3)
		if (l === focused.length) {
			focused = [];
		}

		// (4)
		else if (!focused.length) focused = data.guesses.filter(intersect);

		drawGuessLines(focused, true);
	});

	cols.forEach(function (c) {
		labelg.selectAll('text.' + c.class_)
			.data(data[c.name])
			.enter()
			.append('text')
			.text(function (e, i) {
				// TODO: pretty sure I shouldn't be doing this here?
				return decode_utf8(e[c.id])
				     + (c.name === "theorys" ? " (" + e.accuracy + ")" : "");
			})
			.attr('x', c.tx)
			.attr('y', function (e, i) {
				return c.scale(i) - (c.anchor === "middle" ? lmrg + vrad : 0);
			})
			.attr('text-anchor', c.anchor)
			.attr('dominant-baseline', c.anchor === "middle" ? 'auto' : 'middle')
			.attr('opacity', 0.8)
			.attr('fill', 'black')
			.attr('font-size', fontsize * 0.9)
			.attr('font-family', 'sans-serif');
	});

	cols.forEach(function (c) {
		nodeg.selectAll('circle.' + c.class_)
			.data(data[c.name])
			.enter()
			.append('circle')
			.attr('cx', c.cx)
			.attr('cy', function (e, i) {
				return c.scale(i);
			})
			.attr('r', vrad)
			.attr('fill', 'grey')
			.attr('stroke', 'black')
			.attr('stroke-width', 1)
			.attr('cursor', 'pointer');
	});
};

$(document).ready(function () {
	$('.Guess-graph').each(function () {
		var graph = graphs.shift();

		$(this).parent().removeClass('hidden');
		$(this).data('graph', graph);
		DrawGuessGraph(this);
	});

	$(window).on('resize', function () {
		$('.Guess-graph').each(function () {
			DrawGuessGraph(this);
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
				if ($(e.target).is('a') || $(e.target).closest('a').length) {
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
		var n = $('.Ballot .ordered .Ballot-score').length;
		$('.Ballot .Ballot-score').text('N/A');
		$('.Ballot .ordered .Ballot-score').each(function (i) {
			var pct = (1 - i/(n - 1));
			if (!isNaN(pct)) {
				this.innerHTML = '<span>' + (i+1).ordinal() + '</span>';
				this.firstChild.style.color = 'hsla(' + (120 * pct) + ', 100%, 25%, 1)';
				this.firstChild.title = (100 * pct).toFixed(0) + '%';
			}
			else {
				this.innerHTML = '&ndash;';
			}
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

	var drake = dragula([$('.Ballot .ordered')[0], $('.Ballot .unordered')[0]], {
		moves: function (el, source, handle, sibling) {
			return el.classList.contains('Ballot-item');
		},
		accepts: function (el, target, source, sibling) {
			return target.classList.contains('ordered') || source.classList.contains('unordered');
		}
	});

	drake.on('shadow', function () {
		resetPercentiles();
	});

	drake.on('drop', function () {
		sendOrder();
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
//
// (Note: This can and is used for elements other than .Post)

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
		var t;
		var tick = function tick (e) {
			t = new Date();
			// `now` is defined in the global scope as the server's current time.
			// This is used so that it's spoofable, and so that countdowns are
			// based off the server's clock rather than the client's.

			// `t0` is defined as `new Date()` on pageload. This is so we know
			// what the "current" time is with respect to a spoofed `now`.
			var now_ = now.getTime() + t.getTime() - t0.getTime();

			var delta = (new Date($(e).attr('datetime'))).delta(new Date(now_), 1 + !$(e).hasClass('short'));
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
		var t;
		var tick = function () {
			t = new Date();
			// Same as above
			var now_ = now.getTime() + t.getTime() - t0.getTime();

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

		// Was doing 1000ms before, but this causes the timer to jump from 2s
		// to 0s, or not to tick on the second. This is because setInterval
		// doesn't guarantee it procs exactly every 1000ms. Sometimes it's
		// 998ms or 1002ms.
		//
		// We can avoid the problem by simply ticking much more often. This
		// would be a performance concern if there were many countdowns, but
		// since there is only going to be 1 per page it's not a problem.
		setInterval(tick, 100);
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
// Load scoreboard with AJAX
// ===========================================================================

$(document).ready(function() {
	var $form = $('.Scoreboard-filter');
	if (!$form.length) return;
	var $doc = $form.closest('.Document');
	var $spinner = $doc.find('.Spinner');

	// Because most of the layout is centered, allowing the scroll bar to
	// disappear while the scoreboard disappears temporarily creates a
	// jarring effect where everything repositions. Instead, force the
	// scroll bar to show on this page no matter what.
	$('html').attr('style', 'overflow-y: scroll');

	// Hide the submit control since we're doing AJAX updates
	$form.find('[type="submit"]').addClass('hidden');

	// Hide the "format" control if mode is "fic"
	$form.find('select[name="mode"]')
		.change(function () {
			var $fmt = $form.find('[name="format"]');
			$fmt.prop('disabled', this.value != "fic");
			$fmt.closest('.Scoreboard-filter--cat')
				[$fmt.prop('disabled') ? 'addClass' : 'removeClass']('hidden');
			if ($fmt.prop('disabled')) $fmt.val('');
		})
		.change();

	var xhr = new XMLHttpRequest();
	var timeout;

	function fetchScoreboard () {
		// If a previous fetch is queued, kill it
		xhr.abort();
		window.clearTimeout(timeout);

		$doc.find('.Scoreboard').remove();
		$spinner.removeClass('hidden');

		// Minific › Original › Scoreboard • Writeoff
		// Original › Art › Scoreboard • Writeoff
		var title = ['format', 'genre', 'mode'].map(function (e) {
			return $form.find('[name="' + e + '"] :selected').text().trim();
		});

		// If format defined, pop mode, else shift format
		title[ title[0].length ? 'pop' : 'shift' ]();

		document.title = document.title.replace(
			/^.+( › .+? • .+?)$/,
			title.join(' › ') + '$1'
		);

		var path = window.location.pathname + '?' + $form.serialize();
		// Chop blank format off for tidy URL
		path = path.replace(/&format=$/, '');
		window.history.pushState('', '', path);

		// For some reason, Firefox doesn't flush the document.title if
		// there's  an XHR immediately after it. Delaying the xhr.open
		// slightly seems to flush it.
		setTimeout(function () {
			xhr.open('GET', path);
			xhr.send();
		}, 4);
	}

	xhr.addEventListener('load', function () {
		res = $.parseHTML(xhr.response);
		postModifiers.apply(res);
		var $res = $('<div/>').append(res);

		if ($res.find('.Scoreboard').length) {
			$spinner.addClass('hidden');
			$res.find('.Scoreboard').insertAfter($form);
		}
		else {
			timeout = window.setTimeout(function () {
				xhr.open('GET', xhr.responseURL);
				xhr.send();
			}, 3000);
		}
	});

	xhr.addEventListener('error', function () {
		alert('Failed to fetch scoreboard');
		$spinner.addClass('hidden');
	});

	$form.find('select').change(fetchScoreboard);

	var $flash = $doc.find('.Flash');
	if ($flash.length) {
		$flash.remove();
		fetchScoreboard();
	}
});

//==========================================================================
// Collapsing score breakdowns
//==========================================================================

postModifiers.push(function (ctx) {
	$('.Breakdown', ctx)
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

// ===========================================================================
// Sortable tables
// ===========================================================================

postModifiers.push(function (ctx) {
	$('.Results, .Scoreboard, .Prompts, .Ballot, .Artist-entries, .Storys.gallery', ctx).each(function () {
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

		q = q.then(
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
		[ '.fa-low-vision', 'spoiler', false ],

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

postModifiers.push(function (ctx) {
	$('.Pager a', ctx).removeAttr('href');
});

$(document).ready(function () {
	var $pagers = $('.Pager');

	var loadPage = function (page) {
		$pagers.addClass('loading');
		return $.ajax({
			url: document.location.pathname,
			data: { 'page' : page },
			method: 'GET',
			success: function (res, status, xhr) {
				res = $.parseHTML(res);
				postModifiers.apply(res);
				var $res = $('<div/>').append(res);

				$('.Pager.top').html($res.find('.Pager.top ul'));
				$('.Posts').html($res.find('.Post.view'));
				$('.Pager.bottom').html($res.find('.Pager.bottom ul'));

				$pagers.removeClass('loading');

				// Loading a new page via AJAX should behave like it would
				// otherwise. Just as it's expected that a thread might be
				// outdated if left too long (e.g., people edit their
				// comments), it's also expected orphans would too, so we
				// empty our cache at the same time as we load a new page.
				$orphans = [];

				// Because we use scrollTop after loading the page sometimes,
				// the hover can get "stuck" (i.e., the mouseout event doesn't
				// fire), so we clean it up here if necessary.
				$('.Post-hover').remove();
			},
		});
	};

	if ($pagers.size()) {
		// Handler attaches to the $pagers so that we can modify their
		// contents without having to add new handlers.
		$pagers.on('click', 'a', function (e) {
			var $this = $(e.target);
			if (!$pagers.hasClass('loading')) {
				// $this will be removed from the document after loadPage, so
				// we find this now
				var $pager = $this.closest('.Pager');
				loadPage($this.text()).then(function () {
					if (!$this.hasClass('current') && $pager.hasClass('bottom')) {
						$('html, body').scrollTop($('.Pager.top').offset().top);
					}
				})
			}
		});
	}

	var hashchanged = function () {
		$('.Post.highlight').removeClass('highlight');

		if (document.location.hash.search(/^#[0-9]+$/) != -1) {
			var $post = $('.Posts .Post' + document.location.hash);
			var pid = document.location.hash.substr(1);
			var q = $.when();

			var jump = function () {
				$post.addClass('highlight');
				$('html, body').scrollTop($post.offset().top);
			};

			if ($post.size()) {
				jump();
			}
			else {

				if (!$orphans[pid]) {
					q = loadOrphan(pid);
				}

				q.then(function () {
					var $orphan = $orphans[pid];
					if ($orphan.size()) {
						if ($orphan.attr('data-page') != '0') {
							loadPage($orphan.attr('data-page')).then(function () {
								$post = $('.Post' + document.location.hash);
								jump();
							});
						}
						else {
							window.location = '/post/' + $orphan.attr('id');
						}
					}
				});
			}
		}
	};

	$(window).on('hashchange', hashchanged).trigger('hashchange');
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
				$target = $orphans[tid].clone();
			}
			else {
				$reply.addClass('loading');
				q = loadOrphan(tid).then(function () {
					$reply.removeClass('loading');
					$target = $orphans[tid].clone();
				});
			}

			q = q.then(function () {
				// Make sure a hashchange doesn't cause the browser to try and
				// jump to the hoverbox.
				$target.removeAttr('id');

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
		.removeAttr('href')
		.on('click', function () {
			document.location.hash = $(this).attr('data-target');
		});
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
// New post role preview
// ===========================================================================

$(document).ready(function () {
	$('.Post-form--role')
		.on('change', function () {
			$(this).closest('.Post')
				.removeClass('user admin organiser')
				.addClass(this.value);
		})
		.trigger('change');
});

// ===========================================================================
// Timeline form
// ===========================================================================

function RenderSchedule () {
	const NAMES = {
		vote: [
			[ 'final' ],
			[ 'prelim', 'final' ],
			[ 'prelim', 'semifinal', 'final' ],
		],
		submit: {
			art: 'drawing',
			fic: 'writing',
		},
	};
	const DAY = 1000 * 60 * 60 * 24;

	var $form = $('.Rounds').closest('form');
	var $rounds = $form.find('.Rounds .Round');

	var date = $form.find('[type="date"]').get(0).valueAsDate;
	var time = $form.find('[type="time"]').get(0).valueAsDate;
	var t0;
	if (date !== null && time !== null) {
		t0 = new Date(date.getTime() + time.getTime());
	}
	else {
		t0 = new Date(0);
	}

	var $rorder = $form.find('[name="rorder"]');
	var $modes = $rounds.find('[name="mode"]')
	var modes = Array.prototype.map.call($modes, function (e) { return e.value; }).uniq();
	var rorder = 'simul';

	var t = {};
	modes.forEach(function (m) { t[m] = t0.getTime(); });

	if (modes.length == 2) {
		$rorder.attr('disabled', false);
		$rorder.closest('.Form-item').removeClass('hidden');

		var rorder = $rorder.filter(':checked').val() || 'simul';

		if (rorder !== 'simul') {
			var fr = rorder.substring(0, 3).replace('pic', 'art');
			var to = rorder.substring(4, 7).replace('pic', 'art');

			var $fr = $rounds.find('[name="mode"]')
				.filter(function () { return this.value === fr;	})
				.first();

			t[to] += DAY * $fr.closest('.Round').find('[name="duration"]').val();
		}
	}
	else {
		$rorder.attr('disabled', true);
		$rorder.closest('.Form-item').addClass('hidden');
	}

	var timeline = [];

	$rounds.each(function (e, i) {
		var $round = $(i);

		timeline.push({
			mode: $round.find('[name="mode"]').val(),
			duration: $round.find('[name="duration"]').val(),
		});
	});

	modes.forEach(function (m) {
		var tl = timeline.filter(function (r) { return r.mode === m; });
		var s = tl.slice(0, 1);
		var v = tl.slice(1, tl.length);

		s.forEach(function (r, i) {
			r.action = 'submit';
			r.name = NAMES[r.action][r.mode];
		});

		v.forEach(function (r, i) {
			r.action = 'vote';
			if (v.length <= 3) {
				r.name = NAMES[r.action][ v.length - 1 ][i];
			}
			else {
				r.name = 'round ' + (i + 1);
			}
		});

		tl.forEach(function (r, i) {
			r.start = new Date(t[r.mode]);
			t[r.mode] += DAY * r.duration;
			r.end = new Date(t[r.mode]);

			if (r.name) r.name = r.name.ucfirst();
		});
	});

	$('.Event-timeline').each(function () {
		$(this).removeClass('hidden');
		$(this).data('timeline', timeline);
		DrawTimeline(this);
	});
}

$(document).ready(function () {
	var $rounds = $('.Rounds');
	if (!$rounds.length) {
		return;
	}

	$('.Round-add').on('click', function (e) {
		e.preventDefault();
		var $t = $('.Round-template .Round').clone(true, true);
		$t.find(':disabled').attr('disabled', false);
		$('.Rounds').append($t);
		RenderSchedule();
	});

	$('.Round-remove').on('click', function (e) {
		e.preventDefault();
		$(this).closest('.Form-subsection').remove();
		RenderSchedule();
	});

	$rounds.closest('form').find('input, select').on('change', RenderSchedule);

	var drake = dragula([$rounds.get(0)]);
	drake.on('drop', RenderSchedule);

	RenderSchedule();
});

// ===========================================================================
// Apply post modifiers to document
// ===========================================================================

$(document).ready(function () {
	postModifiers.apply(document);
});
