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

