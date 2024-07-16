source 'https://rubygems.org'
gemspec

gem 'actionview'
gem 'activerecord'

gem 'nokogiri', '~> 1.6.0' if RUBY_VERSION.start_with?('2.0')

platforms :jruby do
  gem 'activerecord-jdbcsqlite3-adapter'
  gem 'activerecord-jdbcmysql-adapter'
  gem 'activerecord-jdbcpostgresql-adapter'
end

platforms :ruby do
  gem 'sqlite3'
  gem 'mysql2'
  gem 'pg'
end
