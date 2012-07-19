#!/usr/bin/env ruby

# (c) 2012 Jesse Newland, jesse@jnewland.com
# (c) 2011 Rdio Inc
# Permission is hereby granted, free of charge, to any person obtaining a copy
# of this software and associated documentation files (the "Software"), to deal
# in the Software without restriction, including without limitation the rights
# to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
# copies of the Software, and to permit persons to whom the Software is
# furnished to do so, subject to the following conditions:
#
# The above copyright notice and this permission notice shall be included in
# all copies or substantial portions of the Software.
#
# THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
# IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
# FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
# AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
# LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
# OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN
# THE SOFTWARE.

require 'sinatra'
require 'uri'
$LOAD_PATH << './lib'
require 'rdio'

RDIO_CONSUMER_KEY    = ENV['RDIO_CONSUMER_KEY']
RDIO_CONSUMER_SECRET = ENV['RDIO_CONSUMER_SECRET']


enable :sessions
disable :protection

set :public_folder, File.dirname(__FILE__) + '/static'

helpers do
  def partial(page, options={})
    erb page, options.merge!(:layout => false)
  end
end

get '/' do
  access_token = session[:at]
  access_token_secret = session[:ats]
  if access_token and access_token_secret
    rdio = Rdio.new([RDIO_CONSUMER_KEY, RDIO_CONSUMER_SECRET],
                    [access_token, access_token_secret])

    user_key  = rdio.call('currentUser')['result']['key']
    play_data = rdio.call('get', { :keys => user_key, :extras => 'lastSongPlayed,lastSongPlayTime'})['result'][user_key]

    play_time = play_data['lastSongPlayTime']
    song_key = play_data['lastSongPlayed']['key']

    song = rdio.call('get', { :keys => song_key, :extras => 'bigIcon'})['result'][song_key]

    erb :index, :locals => {:song => song}
  else
    redirect to('/login')
  end
end

get '/login' do
  session.clear
  # begin the authentication process
  rdio = Rdio.new([RDIO_CONSUMER_KEY, RDIO_CONSUMER_SECRET])
  callback_url = (URI.join request.url, '/callback').to_s
  url = rdio.begin_authentication(callback_url)
  # save our request token in the session
  session[:rt] = rdio.token[0]
  session[:rts] = rdio.token[1]
  # go to Rdio to authenticate the app
  redirect url
end

get '/callback' do
  # get the state from cookies and the query string
  request_token = session[:rt]
  request_token_secret = session[:rts]
  verifier = params[:oauth_verifier]
  # make sure we have everything we need
  if request_token and request_token_secret and verifier
    # exchange the verifier and request token for an access token
    rdio = Rdio.new([RDIO_CONSUMER_KEY, RDIO_CONSUMER_SECRET],
                    [request_token, request_token_secret])
    rdio.complete_authentication(verifier)
    # save the access token in cookies (and discard the request token)
    session[:at] = rdio.token[0]
    session[:ats] = rdio.token[1]
    session.delete(:rt)
    session.delete(:rts)
    # go to the home page
    redirect to('/')
  else
    # we're missing something important
    redirect to('/logout')
  end
end

get '/logout' do
  session.clear
  redirect to('/')
end

get '/search/:search' do
  access_token = session[:at]
  access_token_secret = session[:ats]
  if access_token and access_token_secret
    rdio = Rdio.new([RDIO_CONSUMER_KEY, RDIO_CONSUMER_SECRET],
                    [access_token, access_token_secret])

    erb :search, :locals => { :results => rdio.call('search', :query => (params[:search] || 'Rick Astley'), :types => 'Track,Album')['result']['results'] }
  end
end

get '/queue' do
  access_token = session[:at]
  access_token_secret = session[:ats]
  if access_token and access_token_secret
    rdio = Rdio.new([RDIO_CONSUMER_KEY, RDIO_CONSUMER_SECRET],
                    [access_token, access_token_secret])

    # TODO create playlist automatically
    queue = rdio.call('getPlaylists', :extras => 'tracks')['result']['owned'].detect { |r| r['name'] == '_queue'}
    tracks = queue['tracks']
    playlist = queue['key']

    # gotta prune the already played songs
    user_key  = rdio.call('currentUser')['result']['key']
    play_data = rdio.call('get', { :keys => user_key, :extras => 'lastSongPlayed'})['result'][user_key]

    now_playing_track_key = play_data['lastSongPlayed']['key']
    past_now_playing = false
    tracks.each_with_index do |track, index|
      if past_now_playing
        track['played'] = false
      else
        track['played'] = true
        if now_playing_track_key == track['key']
          past_now_playing = true
        else
          logger.info rdio.call('removeFromPlaylist', {
              :playlist => playlist,
              :count    => 1,
              :index    => 0,
              :tracks   => track['key']
            }
          )
        end
      end
    end
    tracks = tracks.reject { |t| t['played'] == true }

    erb :queue, :locals => { :tracks => tracks }
  end
end

get '/queue/:keys' do
  access_token = session[:at]
  access_token_secret = session[:ats]
  if access_token and access_token_secret
    rdio = Rdio.new([RDIO_CONSUMER_KEY, RDIO_CONSUMER_SECRET],
                    [access_token, access_token_secret])

    # TODO create playlist automatically
    queue = rdio.call('getPlaylists')['result']['owned'].detect { |r| r['name'] == '_queue'}
    playlist = queue['key']

    params[:keys].split(',').each do |key|
      rdio.call('addToPlaylist', :playlist => playlist, :tracks => key)
    end
    redirect '/queue'
  end
end

__END__

@@ layout
<!DOCTYPE html>
  <head>
    <meta charset='utf-8'>
    <meta name='apple-mobile-web-app-capable' content='yes'>
    <link rel='stylesheet' href='/reset.css'>
    <link rel='stylesheet' href='/base.css'>
    <link media='only screen and (max-device-width: 480px)' href='/iphone.css' type='text/css' rel='stylesheet'>
    <link media='only screen and (max-device-width: 768px)' href='/tablet.css' type='ext/css' rel='stylesheet'>
    <link media='only screen and (aspect-ratio: 16/9)' href='/tv.css' rel='stylesheet' type='text/css'>
    <link href='//fonts.googleapis.com/css?family=Open+Sans:300italic,400italic,600italic,700italic,400,300,700,600' rel='stylesheet' type='text/css'>
    <link href='//fonts.googleapis.com/css?family=Open+Sans+Condensed:300' rel='stylesheet' type='text/css'>
    <title>Now Playing</title>
  </head>
  <body>
    <%= yield %>
  </body>
</html>

@@ index
<section id='now-playing' class='row'>
  <ul>
    <li class='name'><%= song['name'] %></li>
    <li class='artist'><em>by</em> <%= song['artist'] %></li>
    <li class='album'><em>from</em> <%= song['album'] %></li>
  </ul>
  <img src='<%= song['bigIcon'] %>' class='album-art' />
</section>

@@ inspect
<section id='now-playing' class='row'>
  <% inspect.each do |item| %>
  <pre><code>
    <%= item.inspect %>
  </code></pre>
  <% end %>
</section>

@@ search
<section id='songs'>
  <div class='list'>
    <% results.each do |result| %>
      <% if result['album'] %>
        <div class="song">
          <ul class="song-info">
            <li><%= result['artist'] %></a></li>
            <li><%= result['name'] %></li>
          </ul>
          <ul class="song-actions">
            <li><a href="/queue/<%= result['key'] %>">add song to queue</a></li>
          </ul>
          <div class="song_album">
            <img src="<%= result['icon'] %>">
          </div>
        </div>
      <% else %>
         <div class="song">
          <ul class="song-info">
            <li><%= result['artist'] %></a></li>
            <li><%= result['name'] %></li>
          </ul>
          <ul class="song-actions">
            <li><a href="/queue/<%= result['trackKeys'].join(',') %>">add album to queue</a></li>
          </ul>
          <div class="song_album">
            <img src="<%= result['icon'] %>">
          </div>
        </div>
       <% end %>
    <% end %>
  </div>
</section>

@@ queue
<section id='songs'>
  <div class='list'>
    <% tracks.each_with_index do |track, index| %>
      <% if !track['played'] %>
        <div class="song">
          <ul class="song-info">
            <li><%= track['artist'] %></a></li>
            <li><%= track['name'] %></li>
          </ul>
          <ul class="song-actions">
            <li><a href="/dequeue/<%= track['key'] %>:<%= index %>">remove from queue</a></li>
          </ul>
          <div class="song_album">
            <img src="<%= track['icon'] %>">
          </div>
        </div>
      <% end %>
    <% end %>
  </div>
</section>