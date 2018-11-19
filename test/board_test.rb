ENV["RACK_ENV"] = "test"

require "minitest/autorun"
require "minitest/reporters"
require "rack/test"
require_relative "../board"

Minitest::Reporters.use!

class RubagotchiTest < Minitest::Test
  include Rack::Test::Methods

  def app
    Sinatra::Application
  end

  def session
    last_request.env["rack.session"]
  end

  def user_session
    { "rack.session" => { user: {initials: 'JS', theme: 'blue'}}}
  end

  def test_home_logged_out
    get "/"

    assert_includes last_response.body, 'Anyone have experience training hippos?'
    assert_equal 200, last_response.status
  end

  def test_home_logged_in
    get "/", {}, user_session

    assert_includes last_response.body, 'Anyone have experience training hippos?'
    assert_includes last_response.body, '+ New topic'
    assert_equal 200, last_response.status
  end

  def test_topic_logged_out
    get "/topic/1"

    assert_includes last_response.body, "Training Henry has been far harder than any of the dogs"
    assert_includes last_response.body, "Join to post"
    assert_equal 200, last_response.status
  end

  def test_topic_logged_in
    get "/topic/1", {}, user_session

    assert_includes last_response.body, "Training Henry has been far harder than any of the dogs"
    assert_includes last_response.body, '<textarea name="content"'
    assert_equal 200, last_response.status
  end

  def test_topic_not_found
    get "/topic/foo"
    assert_equal 302, last_response.status
    get last_response["Location"]
    assert_includes last_response.body, "Topic not found!"

    get "/topic/999999999"
    assert_equal 302, last_response.status
    get last_response["Location"]
    assert_includes last_response.body, "Topic not found!"
  end

  def test_topic_add_message
    post "/topic/1", { content: 'I can help!' }, user_session
    assert_equal 302, last_response.status
    assert_includes last_response["Location"], "/topic/1"

    get last_response["Location"]
    assert_includes last_response.body, "<p>I can help!</p>"
  end

  def test_topic_empty_message_error
    post "/topic/1", { content: ' ' }, user_session
    assert_equal 302, last_response.status
    assert_includes last_response["Location"], "/topic/1"

    get last_response["Location"]
    assert_includes last_response.body, 'Message must not be blank!'
  end

  def test_join_page
    get "/join"

    assert_includes last_response.body, "Join the conversation."
    assert_includes last_response.body, "Two-character initials:"
    assert_includes last_response.body, "Favorite color:"
  end

  def test_join_logged_in
    get "/join", {}, user_session
    assert_equal 302, last_response.status

    get last_response["Location"]
    assert_includes last_response.body, "You've already joined!"
  end

  def test_join_bad_initials
    post "/join", {initials: '12', theme: 'blue'}
    assert_includes last_response.body, 'Initials must be two alphabetical characters.'

    post "/join", {initials: 'O', theme: 'blue'}
    assert_includes last_response.body, 'Initials must be two alphabetical characters.'

    post "/join", {initials: 'J0', theme: 'blue'}
    assert_includes last_response.body, 'Initials must be two alphabetical characters.'
  end

  def test_join_success
    post "/join", {initials: 'LK', theme: 'green'}
    assert_equal 302, last_response.status
    assert_includes last_response["Location"], "/"
    assert_equal session[:user][:initials], 'LK'
    assert_equal session[:user][:theme], 'green'
  end

  def test_new_topic_logged_out
    get "/topic/new"
    assert_equal 302, last_response.status
    assert_includes last_response["Location"], "/"

    get last_response["Location"]
    assert_includes last_response.body, "You must join to make a topic!"
  end

  def test_new_topic_logged_in
    get "/topic/new", {}, user_session

    assert_includes last_response.body, "<label>Title</label>"
    assert_includes last_response.body, '<span class="user-logo blue">JS</span>'
  end

  def test_new_topic_empty_input
    post "/topic/new", {title: ' ', content: 'Hello!'}, user_session
    assert_includes last_response.body, "Title and message must not be blank!"

    post "/topic/new", {title: 'Title', content: ' '}, user_session
    assert_includes last_response.body, "Title and message must not be blank!"
  end

  def test_new_topic_success
    title = 'Dunder Mifflin fantasy football'
    content = 'Pick your team!'

    post "/topic/new", {title: title, content: content}, user_session
    assert_equal 302, last_response.status

    get last_response["Location"]

    assert_includes last_response.body, "<h2>#{title}</h2>"
    assert_includes last_response.body, content
  end

  def test_dark_mode_toggle
    post "/options", { darkMode: "true" }
    assert_equal 302, last_response.status

    get last_response["Location"]
    assert_includes last_response.body, "Join to post"
    assert_includes last_response.body, '<body class="dark-mode">'
  end
end
