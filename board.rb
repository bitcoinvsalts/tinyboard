require "sinatra"
require "sinatra/content_for"
require "tilt/erubis"
require "date"
require "redcarpet"
require_relative "board_db"

configure do
  enable :sessions
  set :session_secret, 'secret'
  set :erb, :escape_html => true
end

configure(:development) do
  require "sinatra/reloader"
  also_reload "board_db.rb"
end

helpers do
end

before do
  @database = BoardDB.new
  session ||= {dark_mode: false}
end

after do
  @database.disconnect
end

not_found do
  erb :not_found
end

get "/" do
  @user = session[:user]
  @topics = @database.recent_topics
  erb :home
end

get "/join" do
  if session[:user]
    session[:error] = "You've already joined!"
    redirect "/"
  end

  erb :join
end

post "/join" do
  @user = session[:user]
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
  @user = session[:user]

  if !@user
    session[:error] = 'You must join to make a topic!'
    redirect "/"
  end

  erb :new_topic
end

post "/topic/new" do
  @user = session[:user]
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
  @user = session[:user]
  @topic_id = params["id"]
  @topic = @database.topic(@topic_id)
  erb :topic
end

post "/topic/:id" do
  @user = session[:user]
  content = params["content"].strip
  topic_id = params["id"]
  author_initials = @user[:initials]
  author_theme = @user[:theme]

  if content.empty?
    session[:error] = "Message must not be blank!"
    redirect "/topic/#{topic_id}"
  else
    @database.add_message(topic_id, content, author_initials, author_theme)
    redirect "/topic/#{topic_id}"
  end
end

post "/options" do
  @user = session[:user]
  session[:dark_mode] = (params["darkMode"] == "true")
  redirect "/"
end
