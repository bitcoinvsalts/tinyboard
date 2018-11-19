CREATE TABLE topics (
  id serial PRIMARY KEY,
  title text NOT NULL
);

CREATE TABLE messages (
  id serial PRIMARY KEY,
  topic_id integer REFERENCES topics (id) NOT NULL,
  content text NOT NULL,
  author_initials char(2) NOT NULL,
  author_theme text,
  posted timestamp NOT NULL DEFAULT NOW()
);
