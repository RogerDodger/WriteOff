# Frequently Asked Questions

## Events

### What the hay is this?

The writeoff is a timed challenge where writers and artists create stories and images to a given prompt.
The works are then released anonymously for all to see, followed by judging rounds to allow readers to determine the winners.
The event is concluded with the results posted and the authors and artists revealed.

If the events has both an art and a fic round, artists draw to the prompt,	and writers then write to the art.
The art scores are augmented by how many stories were written to each artwork.

### How does it work?

The writeoff is split into a series of rounds, all of which are optional: some events will have no prompt round; some events will have no fic round; and some events will have no voting at all, making the event unranked.
The most common operating procedure is to have a prompt round, a fic round, a prelim voting round, and a public voting round.

__Prompt round.__
Before the start of the event, users submit prompts.
24 hours before the start of the event, users vote on the prompts to
indicate which they like the most.

At its onset, the event is named after the winning prompt.
This prompt sets the general theme for the event, and it is expected (though not strictly enforced) that entries will bear some resemblance to it.

__Submission rounds.__
The submission rounds constitute the main part of the event where participants actually create something.
If there is both an art and fic round, the art round will precede the fic round.
Artists submit artworks that mean to act as prompts for stories.

__Preliminary voting round.__
Before the main voting begins, it’s sometimes necessary to pare the list of entries down to a digestable amount.

Each participant is assigned a ballot of entries to read and rate.
Participants must fill this ballot or abstain for their entry to qualify.
The scores from these ballots determine which entries go through to the next voting round.

__Public voting round.__
A public poll is released where anyone may give the stories and/or artworks a ranking from 0&ndash;10.
Entries are scored by their average ranking.
Voters must vote on at least half of the candidates, and participants may not vote on their own entries.

__Private voting round.__
A number of finalists are given to a panel of judges.
They rank the stories in a manner similar to the prelminary round.

## Submissions

### Can I submit more than one entry per event?

Yes.

### How do I format my story?

Click the buttons on the story editor. (TBD)

### How do I delete/edit a submission?

You may delete/edit a submission by going to the submission page and following the appropriate links.

If you want a submission deleted or edited after submissions are closed, you’ll have to take it up with the event’s organiser.

## Voting

### How many stories pass through the prelim round?

Approximately 15 and 35 stories for short story and minific contests respectively.

### How many stories do I get in my assigned prelim ballot?

You're assigned an amount that approximates 35 minutes of reading/reviewing per day.

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
The author/artist fields are for what shows up next to each submission.
Most people will probably use the same name for both, but the option is nice for those who like to use pseudonyms.

This also means that if you one day call yourself “Joe Blow”, then the next day call yourself “Joe__Blow”, those two names will get a different entry on the scoreboard.
(I can merge them for you if you <del>beg</del> ask nicely.)

### How are the scores calculated?

The controversy rating of a story is the standard deviation of the votes it received.
Prelim and and private votes are normalised linearly over the range 0&ndash;10.

## Miscellaneous

### Can I host an event?

Sure! Send me an email outlining what you’d like to do.

I’m currently working on expanding the scoreboard to allow for different communities to host writeoffs without “disturbing” the main events.
