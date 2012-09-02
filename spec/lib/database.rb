require 'erb'
ActiveRecord::Migration.verbose = false unless ENV.has_key?('DEBUG')

module ScopedSearch::RSpec::Database

  def self.establish_connection
    if ENV['DATABASE']
      self.establish_named_connection(ENV['DATABASE'])
    else
      self.establish_default_connection
    end
  end

  def self.test_databases_configuration
    file = if RUBY_PLATFORM == 'java'
      File.expand_path("../database.jruby.yml", File.dirname(__FILE__))
    else
      File.expand_path("../database.ruby.yml", File.dirname(__FILE__))
    end

    @database_connections ||= YAML.load(File.read(file))
  end
  
  def self.test_databases
    database_names = test_databases_configuration.keys.sort
    if ENV['EXCLUDE_DATABASE'].present?
      exclude_databases = ENV['EXCLUDE_DATABASE'].split(',')
      database_names -= exclude_databases
    end
    return database_names
  end

  def self.establish_named_connection(name)
    raise "#{name} database not configured" if test_databases_configuration[name.to_s].nil?
    ActiveRecord::Base.establish_connection(test_databases_configuration[name.to_s])
  end

  def self.establish_default_connection
    ActiveRecord::Base.establish_connection(:adapter => 'sqlite3', :database => ':memory:')
  end

  def self.close_connection
    ActiveRecord::Base.remove_connection
  end

  def self.create_model(fields)
    table_name = "model_#{rand}".gsub(/\./, '')
    ActiveRecord::Migration.create_table(table_name) do |t|
      fields.each do |name, field_type|
        options = (field_type == :decimal) ? { :scale => 2, :precision => 10 } : {}
        t.send(field_type.to_s.gsub(/^unindexed_/, '').to_sym, name, options)
      end
    end

    klass = Class.new(ActiveRecord::Base)
    klass.table_name = table_name
    yield(klass) if block_given?
    return klass
  end

  def self.drop_model(klass)
    ActiveRecord::Migration.drop_table(klass.table_name)
  end
end