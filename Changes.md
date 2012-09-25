v0.12
=====
- Moved event management view to event/$id/...
  - Cleans up the logic and makes implementing organisers much easier
- VoteRecord view/delete added
- Scoreboard controller added
- Admin controller removed - actions put in other controllers
- DateTimes now format into <time> tags, with title attribute as a full RFC2822 date time in UTC
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

