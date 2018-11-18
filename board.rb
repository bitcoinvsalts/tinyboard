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
    PG.connect(dbname: 'tinyboard')
  end

  session ||= {dark_mode: false}
end

after do
  @db.close
end

# Homepage
get "/" do
  @user = session[:user]

  sql = <<~SQL
    SELECT DISTINCT topics.*,
     (SELECT COUNT(messages.id) FROM messages WHERE topic_id = topics.id) AS "message_count",
     (SELECT author_initials FROM messages WHERE topic_id = topics.id ORDER BY posted LIMIT 1) AS "author_initials",
     (SELECT author_theme FROM messages WHERE topic_id = topics.id ORDER BY posted LIMIT 1) AS "author_theme",
     (SELECT posted FROM messages WHERE topic_id = topics.id ORDER BY posted DESC LIMIT 1) AS "last_message"
    FROM topics
    INNER JOIN messages
    ON topics.id = messages.topic_id
    ORDER BY last_message DESC
    LIMIT 50;
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

# View a topic
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

# POST for adding a message to a topic
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
    sql = 'INSERT INTO messages (topic_id, content, author_initials, author_theme) VALUES ($1, $2, $3, $4)'
    @db.exec_params(sql, [topic_id, content, author_initials, author_theme])
    redirect "/topic/#{topic_id}"
  end
end

# POST for setting user options (currently only dark/light mode)
post "/options" do
  @user = session[:user]
  session[:dark_mode] = (params["darkMode"] == "true")
  redirect "/"
end

# Display join form
get "/join" do
  if session[:user]
    session[:error] = "You've already joined!"
    redirect "/"
  end

  erb :join
end

# Handle join form
post "/join" do
  @user = session[:user]
  initials = params["initials"].strip.upcase

  if /^[A-Z]{2}$/ =~ initials
    theme = params["theme"]
    session[:user] = { initials: initials, theme: theme }
    redirect "/"
  else
    session[:error] = 'Initials must be two alphabetical characters.'
    erb :join
  end
end

# Display new topic form
get "/new-topic" do
  @user = session[:user]
  redirect "/" if !session[:user]
  erb :new_topic
end

# Handle new topic form
post "/topics/new" do
  @user = session[:user]
  topic_title = params["title"].strip
  content = params["content"].strip
  author_theme = session[:user][:theme]
  author_initials = session[:user][:initials]

  if content.empty? || topic_title.empty?
    session[:error] = "Title and message must not be blank!"
    erb :new_topic
  else
    topics_sql = 'INSERT INTO topics (title) VALUES ($1) RETURNING id;'
    insert_result = @db.exec_params(topics_sql, [topic_title])
    topic_id = insert_result.first["id"]

    message_sql = 'INSERT INTO messages (topic_id, content, author_initials, author_theme) VALUES ($1, $2, $3, $4)'
    @db.exec_params(message_sql, [topic_id, content, author_initials, author_theme])

    redirect "/"
  end
end
