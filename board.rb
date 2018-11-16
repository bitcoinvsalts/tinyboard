require "sinatra"
require "sinatra/content_for"
require "tilt/erubis"
require "pg"
require "date"
require "redcarpet"

configure do
  enable :sessions
  set :session_secret, 'secret'
  set :erb, :escape_html => true
end

configure(:development) do
  require "sinatra/reloader"
end

helpers do
end

before do
  @db = if Sinatra::Base.production?
    PG.connect(ENV['DATABASE_URL'])
  else
    PG.connect(dbname: "tinyboard")
  end

  session ||= {dark_mode: false}
end

after do
  @db.close
end

get "/" do
  @user = session[:user]
  sql = <<~SQL
    SELECT DISTINCT topics.*,
     (SELECT COUNT(messages.id) FROM messages WHERE topic_id = topics.id) AS "message_count",
     (SELECT author_initials FROM messages WHERE topic_id = topics.id ORDER BY posted LIMIT 1) AS "author_initials",
     (SELECT author_theme FROM messages WHERE topic_id = topics.id ORDER BY posted LIMIT 1) AS "author_theme"
    FROM topics
    INNER JOIN messages
    ON topics.id = messages.topic_id;
  SQL

  topics_result = @db.exec(sql);

  @topics = topics_result.map do |tuple|
    { id: tuple["id"],
      title: tuple["title"],
      author_initials: tuple["author_initials"],
      author_theme: tuple["author_theme"],
      message_count: tuple["message_count"] }
  end

  erb :home
end

get "/topic/:id" do
  @user = session[:user]
  @topic_id = params["id"]
  sql = 'SELECT * FROM topics INNER JOIN messages ON topics.id = messages.topic_id WHERE topic_id = $1 ORDER BY posted;'
  messages_result = @db.exec_params(sql, [@topic_id]);

  @title = messages_result.first["title"]
  @messages = messages_result.map do |tuple|
    formatted_date = DateTime.parse(tuple["posted"]).strftime("%B %d, %Y @ %I:%M%p")
    formatted_content = Redcarpet::Markdown.new(Redcarpet::Render::HTML, fenced_code_blocks: true).render(tuple["content"])

    { content: formatted_content,
      author_initials: tuple["author_initials"],
      author_theme: tuple["author_theme"],
      posted: formatted_date }
  end

  erb :topic
end

post "/topic/:id" do
  @user = session[:user]
  content = params["content"]
  topic_id = params["id"]
  author_initials = @user[:initials]
  author_theme = @user[:theme]
  sql = 'INSERT INTO messages (topic_id, content, author_initials, author_theme) VALUES ($1, $2, $3, $4)'

  @db.exec_params(sql, [topic_id, content, author_initials, author_theme])
  redirect "/topic/#{topic_id}"
end

post "/options" do
  @user = session[:user]
  session[:dark_mode] = (params["darkMode"] == "true")
  redirect params["prev"]
end

get "/join" do
  @user = session[:user]
  erb :join
end

post "/join" do
  @user = session[:user]
  initials = params["initials"].strip

  if initials.size != 2
    session[:error] = 'Initials must be two characters.'
    erb :join
  else
    theme = params["theme"]
    session[:user] = { initials: initials, theme: theme }
    redirect "/"
  end
end

get "/new-topic" do
  @user = session[:user]
  redirect "/" if !session[:user]
  erb :new_topic
end

post "/topics/new" do
  topic_title = params["title"]
  content = params["content"]
  author_theme = session[:user][:theme]
  author_initials = session[:user][:initials]

  topics_sql = 'INSERT INTO topics (title) VALUES ($1) RETURNING id;'
  insert_result = @db.exec_params(topics_sql, [topic_title])
  topic_id = insert_result.first["id"]

  message_sql = 'INSERT INTO messages (topic_id, content, author_initials, author_theme) VALUES ($1, $2, $3, $4)'
  @db.exec_params(message_sql, [topic_id, content, author_initials, author_theme])

  redirect "/"
end
