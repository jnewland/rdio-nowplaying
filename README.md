# rdio Now Playing

http://rdio-nowplaying.herokuapp.com/

Simple app to toss up on your media center TV that shows what song is currently playing in your rdio account.

# Hacking

Grab an [rdio API key](http://developer.rdio.com/)

Create a `.env` file in this repo with your keys and the poll interval:

    RDIO_CONSUMER_KEY=foo
    RDIO_CONSUMER_SECRET=bar
    POLL_INTERVAL=30

Then start:

    bundle install
    foreman start

Boom: http://localhost:4567/

# Running your own copy on heroku

Create an app at heroku in a clone of this repo:

    heroku create --stack cedar jnewland-rdio-nowplaying

Push your config up:

    heroku config:push

Ship it:

    git push heroku master

# OMGHAX

This currently uses a HTML meta refresh tag to update on a poll interval. lol.

# Credit Where Credit Is Due

Styles shamelessly copypasta'd from [play](https://github.com/play/play).

# License

MIT