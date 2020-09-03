FROM ruby:2.6.1

WORKDIR /usr/src/app

COPY Gemfile Gemfile.lock ./

RUN gem update --system
RUN gem install bundler -v 2.0.2
RUN bundle install

COPY . .

CMD ["ruby", "/usr/src/app/board.rb"]