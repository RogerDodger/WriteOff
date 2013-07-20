WriteOff.pm TODO
----------------

- Make it so that events can have no voting rounds (and hence, no results nor awards)
- Add functionality to change email
- Split "settings" into password/email changing and preferences (timezone, mailme)
- Box-and-whisker plot for public vote data
- Author guessing
- Remove uses of smart match throughout code
- Make "News" scalable
  - Let people know when there's new news?
- Add pagination to /archive
- Move email tokens into a table of their own such that they can have unique types (verification token, recovery token, some other token) and expire after a certain time
  - Possibly make use of memcacheing for this as well as other temporary data like prompt heats and login attempts
- Let users view their cast votes

Last updated 29 Jul 2013
