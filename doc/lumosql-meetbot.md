# Automated Meeting Notes With lumosql-meetbot

We use [HcoopMeetbot](https://hcoop-meetbot.readthedocs.io) to make irc meetings simpler and easier.

Normal irc chat is ignored by the bot, but chat that tagged as part of meeting
goes in the notes. Any user on the #lumosql channel can participate in a
meeting, or call one.

Meetings notes automatically appear in the [Meetbot log directory](https://lumosql.org/meetings) as soon as 
the meeting is finished.

This Meetbot helps us remember the important information immediately, and the action items.

# How to Use the Meetbot

In the #lumosql chat room on the [libera chat network](https://libera.chat Libera), you should see a logged-in user
called "lumosql-meetbot". This is a bot, and its purpose is to hang around waiting until someone
says "#startmeeting" in the chat. From then on, it listens for more instructions preceded with "#".

You can read all the details in the help page above. These are the commands we need for LumoSQL meetings:

* **#startmeeting**            Anyone can start a meeting, and is then the chair until #endmeeting is issued.
* **#meetingname \<descriptive name\>**             Important! The chair should specify this, because it gets extracted as the comment in the [table of meetings](https://lumosql.org/meetings).
* **#here**                    List yourself as an attendee. Everyone should do this at the beginning because it looks neater in the notes.
* **#topic**                   Start a new topic, that is a section heading in the meeting notes.
  * **#info \<text\>**           Add a bullet item under the current topic heading.
  * **#link \<link\> \<text\>**    The supplied URL gets added under the current topic heading as a clickable HREF link.
  * **#action \<nick\> \<text\>**  Assign an action item to user <nick> eg "#action Björn to make the coffee".
  * **#accepted \<text\>**       Log an agreement we have made, eg "#accepted we are all going home now".
  * **#motion \<text\>**         The chair can propose any motion for voting, eg "#motion Vanilla icecream is best".
  * **#vote +1 / -1**          Anyone can vote +1 or -1.
  * **#close**                 The chair closes the vote, and the meetbot summarises the results.
* **#endmeeting**              Close the meeting. The formatted minutes and raw log magically appear in a few seconds.

#commands           get a list of all the valid commands, and be reminded of the URL of the help page.

There is also the ability to vote and other facilities. It's a great tool, thanks to
[Kenneth J. Pronovici](https://github.com/pronovic) and others.

You can address the bot directly and chat with it, including by the shortcut "@
\<text\>". You'll find out about that in the online help.


> <font size="6"> &#9757;&#127998; </font> The meeting logs are just HTML files, so if something *really* incorrect gets into the notes by accident we can edit them manually. But this should be very rare.

>    Obviously, chat in #lumosql is covered by the [LumoSQL Code of Conduct](CODE-OF-CONDUCT.md), which says "be a decent person".

