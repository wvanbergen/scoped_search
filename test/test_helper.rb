require 'test/unit'
require 'rubygems'
require 'active_record'
require 'ruby-debug'

require "#{File.dirname(__FILE__)}/../lib/scoped_search"

def setup_db
  ActiveRecord::Base.establish_connection(:adapter => "sqlite3", :dbfile => ":memory:")
  ActiveRecord::Schema.define(:version => 1) do
    create_table :search_test_models do |t|
      t.string :string_field
      t.text :text_field
      t.string :ignored_field
      t.date :date_field
      t.timestamps
    end
  end
end

def teardown_db
  ActiveRecord::Base.connection.tables.each { |table| ActiveRecord::Base.connection.drop_table(table) }
end

class SearchTestModel < ActiveRecord::Base
  def self.create_corpus!
    create!(:string_field => "Programmer 123", :text_field => nil,              :ignored_field => "123456",  :date_field => '2000-01-01')    
    create!(:string_field => "Jim",            :text_field => "Henson",         :ignored_field => "123456a", :date_field => '2001-04-15')   
    create!(:string_field => "Jim",            :text_field => "Bush",           :ignored_field => "123456b", :date_field => '2001-04-17')    
    create!(:string_field => "Wes",            :text_field => "Hays",           :ignored_field => "123456c", :date_field => '1980-09-27')  
    create!(:string_field => "Bob",            :text_field => "Hays",           :ignored_field => "123456d", :date_field => '2002-11-09')  
    create!(:string_field => "Dogs",           :text_field => "Pit Bull",       :ignored_field => "123456e", :date_field => '2002-12-26') 
    create!(:string_field => "Dogs",           :text_field => "Eskimo",         :ignored_field => "123456f", :date_field => '2003-03-19')
    create!(:string_field => "Cows",           :text_field => "Farms",          :ignored_field => "123456g", :date_field => '2004-05-01')
    create!(:string_field => "Hello World",    :text_field => "Hello Moon",     :ignored_field => "123456h", :date_field => '2004-07-11')   
    create!(:string_field => "Hello World",    :text_field => "Goodnight Moon", :ignored_field => "123456i", :date_field => '2004-09-12')
    create!(:string_field => "Happy Cow",      :text_field => "Sad Cow",        :ignored_field => "123456j", :date_field => '2005-02-05')
    create!(:string_field => "Happy Frog",     :text_field => "Sad Frog",       :ignored_field => "123456k", :date_field => '2006-03-09')
    create!(:string_field => "Excited Frog",   :text_field => "Sad Frog",       :ignored_field => "123456l", :date_field => '2006-07-15')    
    create!(:string_field => "Man made",       :text_field => "Woman made",     :ignored_field => "123456m", :date_field => '2007-06-13')
    create!(:string_field => "Cat Toys",       :text_field => "Frog Toys",      :ignored_field => "123456n", :date_field => '2008-03-04') 
    create!(:string_field => "Happy Toys",     :text_field => "Sad Toys",       :ignored_field => "123456n", :date_field => '2008-05-12') 

    create!(:string_field => "My son was born on 7/15/2006 and weighed 5.5 lbs",     
            :text_field => "Sad Toys",       
            :ignored_field => "123456n", 
            :date_field => '2008-09-22')
  end
end