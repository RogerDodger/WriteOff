# Frequently Asked Questions

## Submissions

### Can I submit more than one entry per event?

Yes.

### How do I format my story?

See [this page](/style).

### How do I delete/edit a submission?

You may delete/edit a submission by going to the submission page and following the appropriate links.

If you want a submission deleted or edited after submissions are closed, you’ll have to take it up with the event’s organiser.

## Voting

### Can I vote on my own entry?

No. It will not appear in your ballot.

### How many entries pass through the prelim round?

Approximately 15 and 35 entries for short story and minific contests respectively.

### How many entries do I get in my ballot?

You're assigned an amount that approximates 35 minutes of reading/reviewing per day.

## How many entries can I abstain?

You get 1 abstain, plus 1 for every 10 entries.

## How does the voting algorithm work?

The votes are modelled as stories playing a series of head-to-head matches against each other.
For each ballot, the top ranking story beats every other story; the second ranking story beats every other story except the first, etc.
This model is then resolved using [maximum likelihood estimation](https://en.wikipedia.org/wiki/Maximum_likelihood) to find a unified ranking that has the highest probability of being correct.

The result of this system is that votes are considered in the context of the other stories the voter voted for, and voters who are too harsh or too nice do not disproportionately skew results.

The scores each story gets in this system have the following interpretation:

Let the score of story x be S<sub>x</sub>.
The probability that story A will beat story B in a match is equal to S<sub>A</sub> / (S<sub>A</sub> + S<sub>B</sub>).
In the context of the model, this is the probability that a random voter will prefer story A to story B.

## Scoreboard

### How are the scores calculated?

Each submission type in each event has a difficulty score calculated.

For art submissions, this is always 500.

For fic submissions, this is equal to ten times the average square root of the event’s story’s wordcounts.
For minific and short story contests, this is approximately 250 and 600 respectively.

Entries are awarded a fraction of this score based on their performance.
This is equal to `(1 - i/n)^e`, where *i* is the entry’s position (e.g, “1” for 1st place), *n* is the number of entries in the event, and *e* is 1.6.

This means that, for example, in a short story contest with 20 contestants, 1st place will receive `(1 - 1/20)^1.6 = 0.92 =` 92% of ~600 points, 10th place will receive `(1 - 10/20)^1.6 = 0.33 =` 33% of ~600 points, and last place will receive 0 points.

In addition, any submission from an artist after the first will have 20% of the difficulty subtracted from its final score.
In this way, it is possible for entries to get negative score, but also possible for an artist to get more points from an event with multiple entries than just one.
This is to encourage multiple submissions from the same artist without encouraging people to spam entries.

After each event, scores decay by 10%.
This is to encourage consistent performance and to enable newcomers to overtake the old guard.

### Why is my name there twice?

Accolades are tied to author/artist names, *not* login names.
Login names are used to identify users with the site.
The aliases are for what shows up next to each submission and in comments.
Most people will probably use the same name for both, but the option is nice for those who like to use pseudonyms.

## Miscellaneous

### Can I host an event?

Sure! [mailto:cthor@cpan.org](Send me an email) outlining what you’d like to do.
