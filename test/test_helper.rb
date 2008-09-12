require 'test/unit'
require 'rubygems'
require 'active_record'

require "#{File.dirname(__FILE__)}/../lib/scoped_search"

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
  ActiveRecord::Base.connection.tables.each { |table| ActiveRecord::Base.connection.drop_table(table) }
end

class SearchTestModel < ActiveRecord::Base
  def self.create_corpus!
    create!(:string_field => "Programmer 123", :text_field => nil,               :ignored_field => "123456")    
    create!(:string_field => "Jim",            :text_field => "Henson",          :ignored_field => "123456a")   
    create!(:string_field => "Jim",            :text_field => "Bush",            :ignored_field => "123456b")    
    create!(:string_field => "Wes",            :text_field => "Hays",            :ignored_field => "123456c")  
    create!(:string_field => "Bob",            :text_field => "Hays",            :ignored_field => "123456d")  
    create!(:string_field => "Dogs",           :text_field => "Pit Bull",        :ignored_field => "123456e") 
    create!(:string_field => "Dogs",           :text_field => "Eskimo",          :ignored_field => "123456f")
    create!(:string_field => "Cows",           :text_field => "Farms",           :ignored_field => "123456g")
    create!(:string_field => "Hello World",    :text_field => "Hello Moon",      :ignored_field => "123456h")   
    create!(:string_field => "Hello World",    :text_field => "Goodnight Moon",  :ignored_field => "123456i")
    create!(:string_field => "Happy Cow",      :text_field => "Sad Cow",         :ignored_field => "123456j")
    create!(:string_field => "Happy Frog",     :text_field => "Sad Frog",        :ignored_field => "123456k")
    create!(:string_field => "Excited Frog",   :text_field => "Sad Frog",        :ignored_field => "123456l")    
    create!(:string_field => "Man made",       :text_field => "Woman made",      :ignored_field => "123456m")
    create!(:string_field => "Cat Toys",       :text_field => "Frog Toys",       :ignored_field => "123456n") 
  end
end