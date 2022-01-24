# Automated Meeting Notes With lumosql-meetbot

We can use [HcoopMettbot](https://hcoop-meetbot.readthedocs.io) to make irc meetings simpler and easier.

Only text that is tagged as part of meeting goes in the notes, so any other
discussions can continue uninterrupted.

Meetings notes automatically appear in the [Meetbot log
directory](https://lumosql.org/meetings) as soon as the meeting is finished.
This is a way of remembering the important information immediately, and who has
agreed to do what actions.

# How to Use the Meetbot

If you enter the #lumosql chat room on the [libera chat
network](https://libera.chat Libera), you will see there is a logged-in user
called "lumosql-meetbot". This is a bot, and while you can have a limited
conversation with it, its main purpose is to hang around waiting until someone
says "#startmeeting".

You can read all the details in the help page above, but in brief the commands we mostly need are:

```
#startmeeting       anyone can start a meeting
#here               list yourself as an attendee
#topic              here is a new topic
#info                  bullet item under the topic
#link                  this URL gets added to the topic
#action <nick>      assign an action item to user <nick> eg "#action Björn to make the coffee"
#accepted           log an agreement that we have made, eg "#accepted we are all going home now"
#endmeeting         close the meeting, update the HTML files and both the formatted minutes and raw log magically appear in a few seconds

    also

#commands           get a list of all the valid commands, and be reminded of the URL of the help page.
```

There is also the ability to vote and other facilities. It's a great tool, thanks to
[Kenneth J. Pronovici](https://github.com/pronovic) and others.


> <font size="6"> &#9757;&#127998; </font> The meeting logs are just HTML files, so if something *really* incorrect gets into the notes by accident we can edited them manually at need. But this should be very rare.

>    Obviously, chat in #lumosql is covered by the [LumoSQL Code of Conduct](CODE-OF-CONDUCT.md), which says "be a decent person".


