require "sinatra"
require "sinatra/content_for"
require "tilt/erubis"
require "date"
require "redcarpet"
require "dotenv/load"

require_relative "./db/board_db"

configure do
  enable :sessions
  set :session_secret, ENV.fetch('SESSION_SECRET') { SecureRandom.hex(64) }
  set :erb, :escape_html => true
end

configure(:development) do
  require "sinatra/reloader"
  also_reload "./db/board_db.rb"
end

before do
  content_type :html, 'charset' => 'utf-8'
  session[:dark_mode] ||= false
  session[:user] ||= false
  @database = BoardDB.new
  @user = session[:user]
end

after do
  @database.disconnect
end

not_found do
  erb :not_found
end

get "/" do
  @topics = @database.recent_topics
  erb :home
end

get "/join" do
  if @user
    session[:error] = "You've already joined!"
    redirect "/"
  end

  erb :join
end

post "/join" do
  initials = params["initials"].strip.upcase

  if /^[A-Z]{2}$/ =~ initials
    session[:user] = { initials: initials, theme: params["theme"] }
    redirect "/"
  else
    session[:error] = 'Initials must be two alphabetical characters.'
    erb :join
  end
end

get "/topic/new" do
  if !@user
    session[:error] = 'You must join to make a topic!'
    redirect "/"
  end

  erb :new_topic
end

post "/topic/new" do
  topic_title = params["title"].strip
  content = params["content"].strip

  if content.empty? || topic_title.empty?
    session[:error] = "Title and message must not be blank!"
    erb :new_topic
  else
    topic_id = @database.add_topic(topic_title, content, @user[:initials], @user[:theme])
    redirect "/topic/#{topic_id}"
  end
end

get "/topic/:id" do
  @topic = @database.topic(params["id"].to_i)

  if !@topic[:id]
    session[:error] = 'Topic not found!'
    redirect "/"
  end

  erb :topic
end

post "/topic/:id" do
  content = params["content"].strip

  if content.empty?
    session[:error] = "Message must not be blank!"
    redirect "/topic/#{params["id"]}"
  else
    @database.add_message(params["id"], content, @user[:initials], @user[:theme])
    redirect "/topic/#{params["id"]}"
  end
end

post "/options" do
  session[:dark_mode] = (params["darkMode"] == "true")
  redirect "/"
end
