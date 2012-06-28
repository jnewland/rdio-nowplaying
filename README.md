## Running on Heroku

Clone this repo.

In the clone:

    heroku create --stack cedar jnewland-rdio-nowplaying

Set the following config at heroku:

    heroku config:add RDIO_CONSUMER_KEY=foo
    heroku config:add RDIO_CONSUMER_SECRET=foo@foo.com
    heroku config:add POLL_INTERVAL=10

Ship it:

    git push heroku master

Fire up a web process:

    heroku scale web=1

Hit up [papertrail](https://papertrailapp.com/events) and check on the logs.