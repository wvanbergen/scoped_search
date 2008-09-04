require 'test/unit'
require 'rubygems'
require 'active_record'

require "#{File.dirname(__FILE__)}/../init"

def setup_db
  ActiveRecord::Base.establish_connection(:adapter => "sqlite3", :dbfile => ":memory:")
  ActiveRecord::Schema.define(:version => 1) do
    create_table :search_test_models do |t|
      t.string :string_field
      t.text :text_field
      t.string :ignored_field
      t.timestamps
    end
  end
end

def teardown_db
  ActiveRecord::Base.connection.tables.each do |table|
    ActiveRecord::Base.connection.drop_table(table)
  end
  ActiveRecord::Base.close_connection
end

class SearchTestModel < ActiveRecord::Base
  def self.create_corpus!
    create!(:string_field => "123", :text_field => "Hallo",     :ignored_field => "123 willem")
    create!(:string_field => "456", :text_field => "Hallo 123", :ignored_field => "123")
    create!(:string_field => "789", :text_field => "HALLO",     :ignored_field => "123456");
    create!(:string_field => "123", :text_field => nil,         :ignored_field => "123456");
  end
end