require "pg"

class BoardDB
  def initialize
    @db = if ENV['DATABASE_URL']
      PG.connect({ host: ENV['DATABASE_URL'], user: 'postgres' })
    elsif Sinatra::Base.test?
      PG.connect(dbname: 'tinyboard_test')
    else
      PG.connect(dbname: 'tinyboard')
    end
  end

  def recent_topics
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

    topics_result.map do |tuple|
      { id: tuple["id"],
        title: tuple["title"],
        author_initials: tuple["author_initials"],
        author_theme: tuple["author_theme"],
        message_count: tuple["message_count"] }
    end
  end

  def topic(id)
    sql = 'SELECT * FROM topics INNER JOIN messages ON topics.id = messages.topic_id WHERE topic_id = $1 ORDER BY posted;'
    result = @db.exec_params(sql, [id]);

    if result.first
      messages = result.map do |tuple|
        formatted_date = DateTime.parse(tuple["posted"]).strftime("%B %d, %Y @ %I:%M%p")
        formatted_content = Redcarpet::Markdown.new(Redcarpet::Render::Safe, fenced_code_blocks: true).render(tuple["content"])

        { content: formatted_content,
          author_initials: tuple["author_initials"],
          author_theme: tuple["author_theme"],
          posted: formatted_date }
      end

      {id: result.first["topic_id"], title: result.first["title"], messages: messages}
    else
      {}
    end
  end

  def add_message(topic_id, content, author_initials, author_theme)
    sql = 'INSERT INTO messages (topic_id, content, author_initials, author_theme) VALUES ($1, $2, $3, $4)'
    @db.exec_params(sql, [topic_id, content, author_initials, author_theme])
  end

  def add_topic(title, content, author_initials, author_theme)
    topics_sql = 'INSERT INTO topics (title) VALUES ($1) RETURNING id;'
    insert_result = @db.exec_params(topics_sql, [title])
    topic_id = insert_result.first["id"]

    add_message(topic_id, content, author_initials, author_theme)

    topic_id
  end

  def disconnect
    @db.close
  end
end
