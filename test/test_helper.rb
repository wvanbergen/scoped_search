require 'test/unit'
require 'rubygems'
require 'active_record'
require 'ruby-debug'

require "#{File.dirname(__FILE__)}/../lib/scoped_search"

ActiveRecord::Migration.verbose = false
class InitialSchema < ActiveRecord::Migration

  def self.up
    
    create_table :search_test_models do |t|
      t.string :string_field
      t.text :text_field
      t.string :ignored_field
      t.date :date_field
      t.timestamps
    end
    
    create_table :users do |t|
      t.string :first_name, :last_name, :login
      t.integer :group_id
      t.integer :address_id
    end   
    
    create_table :clients do |t|
      t.string :first_name, :last_name
    end     
    
    create_table :offices do |t|
      t.string :name
      t.integer :user_id, :client_id
    end    
    
    create_table :groups do |t|
      t.string :name
    end    
    
    create_table :locations do |t|
      t.string :name
    end   
    
    create_table :locations_users, :id => false, :force => true do |t|
      t.integer :user_id
      t.integer :location_id
    end 
    
    create_table :notes do |t|
      t.string :title
      t.text :content
      t.integer :user_id
    end      
    
    create_table :addresses do |t|
      t.string :street, :city, :state, :postal_code
    end    
  end

  def self.down
    drop_table :search_test_models    
    drop_table :users     
    drop_table :clients     
    drop_table :offices     
    drop_table :groups     
    drop_table :locations     
    drop_table :locations_users    
    drop_table :notes     
    drop_table :addresses
  end

end


def create_sqlite3_connection
  ActiveRecord::Base.establish_connection(
    :adapter => "sqlite3", 
    :dbfile => ":memory:"
  )
end

def create_postgresql_connection
  ActiveRecord::Base.establish_connection(
    :adapter  => "postgresql",
    :host     => "localhost",
    :username => "sstest",
    :password => "sstest",
    :database => "scoped_search_test"
  )    
end

def create_mysql_connection
  # '/tmp/mysql.sock' is the default location and file rails looks for.
  mysql_socket = ENV['MYSQLSOCKET'].nil? ? '/tmp/mysql.sock' : ENV['MYSQLSOCKET']
  ActiveRecord::Base.establish_connection(
    :adapter  => "mysql",
    :host     => "localhost",
    :username => "sstest",
    :password => "sstest",
    :database => "scoped_search_test",
    :socket   => mysql_socket
  )    
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

class User < ActiveRecord::Base
  belongs_to :group
  belongs_to :address
  has_many :notes
  has_and_belongs_to_many :locations
  
  has_many :offices, :dependent => :destroy
  has_many :clients, :through => :offices  
  def self.create_corpus!
    create!(:first_name => 'Willem',  :last_name => 'Van Bergen', :login => 'wvanbergen', :group_id => 1, :address_id => 1) 
    create!(:first_name => 'Wes',     :last_name => 'Hays',       :login => 'weshays',    :group_id => 1, :address_id => 2) 
    create!(:first_name => 'John',    :last_name => 'Dell',       :login => 'jdell',      :group_id => 2, :address_id => 3) 
    create!(:first_name => 'Ray',     :last_name => 'York',       :login => 'ryork',      :group_id => 3, :address_id => 4) 
    create!(:first_name => 'Anna',    :last_name => 'Landis',     :login => 'alandis',    :group_id => 4, :address_id => 5) 
    
    user = self.find_by_first_name('Willem')
    user.locations << Location.find_by_name('Office')
    
    user = self.find_by_first_name('Wes')
    user.locations << Location.find_by_name('Store')
    
    user = self.find_by_first_name('John')
    user.locations << Location.find_by_name('Office')
    
    user = self.find_by_first_name('Ray')
    user.locations << Location.find_by_name('Home')
    
    user = self.find_by_first_name('Anna')
    user.locations << Location.find_by_name('Beach')                
  end
end

class Client < ActiveRecord::Base
  has_many :offices, :dependent => :destroy
  has_many :users, :through => :offices
  def self.create_corpus!
    create!(:first_name => 'Bob',    :last_name => 'Smith') 
    create!(:first_name => 'Sam',    :last_name => 'Lovett')
    create!(:first_name => 'Sally',  :last_name => 'May')
    create!(:first_name => 'Mary',   :last_name => 'Smith')
    create!(:first_name => 'Darren', :last_name => 'Johnson')
  end
end

class Office < ActiveRecord::Base
  belongs_to :client
  belongs_to :user
  def self.create_corpus!
    create!(:name => 'California Office', :user_id => 1, :client_id => 1)
    create!(:name => 'California Office', :user_id => 2, :client_id => 2)
    create!(:name => 'California Office', :user_id => 3, :client_id => 3)
    create!(:name => 'Reno Office',       :user_id => 4, :client_id => 4)
    create!(:name => 'Reno Office',       :user_id => 5, :client_id => 5)        
  end
end

class Group < ActiveRecord::Base
  has_many :users
  def self.create_corpus!
    create!(:name => 'System Administrator') 
    create!(:name => 'Software Managers')    
    create!(:name => 'Office Managers')      
    create!(:name => 'Accounting')           
  end
end

class Location < ActiveRecord::Base
  has_and_belongs_to_many :users
  def self.create_corpus!
    create!(:name => 'Home')   
    create!(:name => 'Office') 
    create!(:name => 'Store')  
    create!(:name => 'Beach')  
  end
end

class Note < ActiveRecord::Base
  belongs_to :user
  def self.create_corpus!
    wes = User.find_by_first_name('Wes')
    john = User.find_by_first_name('John')
    
    create!(:user_id => wes.id,         
            :title   => 'Purchases', 
            :content => "1) Linksys Router. 2) Network Cable")   
            
    create!(:user_id => wes.id,         
            :title  => 'Tasks',
            :content => 'Clean my car, walk the dog and mow the yard buy milk') 
            
    create!(:user_id => wes.id,         
            :title   => 'Grocery List',
            :content => 'milk, gum, apples')  
            
    create!(:user_id => wes.id,         
            :title   => 'Stocks to watch',
            :content => 'MA, AAPL, V and SSO.  Straddle MA at 200 with JAN 09 options')            
    
    create!(:user_id => john.id,        
            :title   => 'Spec Tests',
            :content => 'Spec Tests... Spec Tests... Spec Tests!!')   
            
    create!(:user_id => john.id,        
            :title   => 'Things To Do',
            :content => '1) Did I mention Spec Tests!!!, 2) Buy Linksys Router WRT160N')
  end
end

class Address < ActiveRecord::Base
  has_one :user
  def self.create_corpus!
    create!(:street => '800 Haskell St',     :city => 'Reno',       :state => 'NV', :postal_code => '89509') 
    create!(:street => '2499 Dorchester Rd', :city => 'Charleston', :state => 'SC', :postal_code => '29414')
    create!(:street => '474 Mallard Way',    :city => 'Fernley',    :state => 'NV', :postal_code => '89408')
    create!(:street => '1600 Montero Ct',    :city => 'Sparks',     :state => 'NV', :postal_code => '89434')
    create!(:street => '200 4th St',         :city => 'Sparks',     :state => 'NV', :postal_code => '89434')
  end
end