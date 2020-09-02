task default: %w[seed_test_db test]

task :seed_test_db do
  `dropdb --if-exists tinyboard_test`
  `createdb tinyboard_test`
  `psql -d tinyboard_test < ./db/schema.sql`
  `psql -d tinyboard_test < ./db/seeds.sql`
end

task :test do
  ruby "-W0 ./test/board_test.rb"
end

task :seed_db do
  `psql -d tinyboard < ./db/seeds.sql`
end

task :create_db do
  `dropdb --if-exists tinyboard`
  `createdb tinyboard`
  `psql -d tinyboard < ./db/schema.sql`
end
