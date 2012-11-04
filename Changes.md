v0.24
=====

- Boatload of style changes
- Scoreboard data put into multiple tables for score breakdowns
- Awards are a table in the database now, rather than configured
- Made the wrapper render partial for XMLHttpRequests so that dialogs can be fetched easily
- All dialogs are now fetched instead of embedded
- Added config for Google Analytics
- Put full id_uri for event listing IDs (starting with a number is valid in HTML5)

v0.23
=====

### 27 Oct 2012

- Started using Google Analytics on the site
- Cleaned up popup messages to be more lightweight in the templates
- Added a Contact page
- Update Terms of Service to be more professional looking
- Swapped html5shiv for modernizr
- Added humans.txt
- Added a html filter before rendering markdown, as markdown doesn't do that by default

v0.22
=====

### 19 Oct 2012

- New navbar and other layout changes
- Art gallery done with data URI base64 images to reduce the number of server requests
  - IE8 and prior have a directive to still work with the gallery

v0.21
=====

### 18 Oct 2012

- Art gallery
- Related images/artworks listed in galleries
- Fixed Controller::Fic::form image_id logic bug
- Art public voting
- Art results
- Results page made columnar to use space more effectively
- Reserved artist/author names for first person to use them (using funky virtual tables, woo)
- Added logs for Controller::Fic::edit

v0.20
=====

### 16 Oct 2012

- VoteRecord filling and other various logic
- Prelim distribution
  - Algorithm surprisingly simpler when using an array rather than a hash
- Added public story candidate logic
- Judge distribution 
- Volunteer distribution
- Generalised Vote::Public so that Vote::Public::art will be easily implementable
- Added URL seek to event listing's accordion
- Added version numbers to css/js files so that new versions will update despite user caches
- Added app version to footer
- Ensured scheduler does not execute schedules twice
- +Hugbox score
- Decided that timestamps on changelogs *might* be a good idea

v0.19
=====
- Removed delay between events
  - Prelim rounds start with +leeway time so that stories submitted dring the leeway time don't miss out on the prelim distriution
- Massiely optimised the result listing page
  - Unfortunately, could not get a super-awesome all-encompassing query for all the data in one big sweep, but this is still good enough
- Misc template fidgeting
- Request logging logs the referer of requests without the same origin

v0.18
=====
- Delete form prettied up
- Every submit/edit form prettied up
- CSS made more generalised (also prettied up, because that word isn't trite by now!)
- Fic submit/edit can choose one or more related art items now
- Fic editing uses the same form as submitting, so you can edit anything basically
- Password recover page added
- Email sending stuff put in isolated subs
  - Verification email doesn't send the password out now for security reasons
- Fics don't point to other fics until gallery is open
- Added link to plain text view on fic gallery
- Item deletion logs now
- Settings form tidied up
- User list HTML view added 
  - No public link yet though, because it's kind of useless + ugly
- Added a clean_unverified_users method to the cleanup schedule, dousing the system of the unpure
- Started using proper many_to_many create functions
- Replaced up all the messy js with inline HTML5 validation
  - Miracle shit that is
- Probably broke something

v0.17
=====
- Added placeholder templates/actions for art gallery and voting, and prelim and private voting
- Prettied up the event/edit form
- Tidied up the CSS

v0.16
=====
- Email notifications
- Nicer forms (in some places)
  - HTML5 validation woo

v0.15
=====
- Wooden spoon award
- Confetti award
- Cleaned up voterecord/list
- Cleaned up position-determining routines by taking them out of templates
- Optimised `is_manipulable_by` methods
- Pushed event archive clock back 1 day, so that recently finished events don't go straight in the archive

v0.14
=====
- Put parsers where they belong (for reals this time)
- Organiser/Judge CRUD added
- Organiser functionality fully implemented
- Rule sets and custom rule funtionality added
- Cleaned up the templates and stylesheet a little
- Event listing more detailed
- Removed second HTML view for emails
  - The wrapper is now smart enough to not need it
- Added JSON view
- Added a FillForm check to Root/end, instead of doing it the silly way

v0.13
=====
- Made public votes saveable to session data

v0.12
=====
- Moved event management view to event/$id/...
  - Cleans up the logic and makes implementing organisers much easier
- VoteRecord view/delete added
- Scoreboard controller added
- Admin controller removed - actions put in other controllers
- DateTimes now format into time tags, with title attribute as a full RFC2822 date time in UTC
- Added a number of title attributes to truncated table data
- Fixed Cron controller
- Set $ENV{TZ} to UTC and configurable at deployment level
- Log archiver script added
- Cleaned up FAQ and Rules page to validate as HTML5
- Added login hook for testing purposes

v0.11
=====
- Scoreboard done
- FAQ cleaned up

v0.10
=====
- Public voting implemented
- BBCode parsing done up proper
- Scoreboard half done
- Heats done up proper
- Discovered the magic of pre-defined TT subs
  - i.e., Date math done up proper

v0.09
=====
- Fixed some forms & cleaned up the code
- Parsers put where they belong & links done up right w/o any messy view code
- Case-sensitive collation put on columns that should have it
- Tests should actually work now
- Database backup script added
- Time to *actually implement the voting* now? Haha, maybe...
- Nobody reads these anyway

v0.08
=====
- Logs

v0.07
=====
- Events able to have a pre-set title for descriptiveness before the prompt overwrites it
- Submission pages requiring logins made more guest-friendly
- BBCode parser put where it belongs
- Configurable footer addendum added
- FAQ made clearer
- Prompt submission-limit bug fixed
- Register form mailme bug fixed
- Added counter measures to login-attempt spam
- Site's font chain made super long so I look like I know what I'm doing

v0.06
=====
- Rules added
- FAQ mostly completed
- Stories and images given a seed for randomised listing order
- Form validation solidified
- DB Schema (mostly) finalised
- URLs on items made descriptive
- Soul-barter clause added to Terms of Service
- Placeholders for votes and galleries in place
  - Will be complete before planned minific event starts
- Let's do this

v0.05
=====
- Per-event blurb added
  - Editable with markdown (should only use links in lists, mostly)
- Prompt submission/voting logic ironed out
  - Submit/vote pages made to look similar to others for consistency
  - Prompt submit page lets users know how many prompt submissions they have left
- Submission count added to submission pages (in lieu of providing every bit of submission data)
- Event archive added with proper nav. in place
- General refractoring (good stuff that nobody else care about...)

Added table for event-user association. Possibly going to use this for adding organisers to events, such that they can delete/modify/view entries in given events (i.e., so they can *organise* it).

Considering doing accolades as purely numerical, following the formula `m - 2p + 1`, where `m` is the count of entries and `p` is the position of the scored item. This way, player scores can be tallied together in one scoresheet without winners in a contest of 5 entries being scored equally to a winner in a contest of 50 entries.

It'd also be easier to implement. 

Made vote records more generalised, such that the addition of a private judging round can happen. Also considering the possibility of using votes on artworks, though how that ties in to event flow... I'm not sure. Something to ponder, but not a top priority in any case.

v0.04
=====
- FAQ added
- Word limits now on per-event basis
- Interim set to global 1 hour
- Scheduler table and cron tasks added
- Row logic in row classes
- Generalised some resultset logic
- Added TODO

v0.03
=====
- Added CSRF counter-measures
- Business rules on submissions
- Prompts
  - Submission
  - Deletion
  - Voting (uses Elo comparison)

v0.02
=====
- Changed paths on item manipulation to (fic|art)/*/(view|edit|delete)

v0.01
=====

##Implemented

###Users
- Register
- Verify
- Settings
- View and manipulate own submissions (of implemented types)
- Access controls (e.g., restricting admin tasks to the admin)

###Events
- Create
- Event flow
- List
- Submission time logic

###Stories
- Submit
- View (parsed BBCode and plaintext)
- Edit
- Delete

###Images
- Submit
- Thumbnailing
- View
- Delete

##To Be Implemented

###Events
- Results

###Prompts
- Submit
- View
- Delete
- Comparison logic (ELO Ranking)

###Heats
- Request
- Vote

###Vote Records
- Distribution for participants
- Distribution for volunteers
- Relative voting (for prelims)
- Scaled voting (for finals)
- Prelim → Finals flow
- Results

###Documentation
- Everything
- FAQ
- Flow-chart of event operation


Fic submissions require a login. Art submissions don't, but you won't be able to manipulate your submissions without one. Art rounds and prelim rounds are both optional on a per-event basis.

I suspect that dealing with the vote distribution will take longer than other components, since a nice interface to the voting will take a bit of javascript magic. That said, the main algorithm for participant distributions is already written from earlier; it just needs a little wrapping to be more modular. 

The only thing that isn't trivial is the volunteer distribution. I'm still thinking about how I should handle that. Suggestions are welcome.

