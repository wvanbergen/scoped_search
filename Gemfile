source :rubygems
gemspec

gem 'activerecord', '~> 4.0.0.beta1'

platforms :jruby do
  gem 'activerecord-jdbcsqlite3-adapter'
  gem 'activerecord-jdbcmysql-adapter'
  gem 'activerecord-jdbcpostgresql-adapter'
end

platforms :ruby do
  gem 'sqlite3'
  gem 'mysql2', '~> 0.3.11'
  gem 'pg'
end
