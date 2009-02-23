ActiveRecord::Migration.verbose = false unless ENV.has_key?('DEBUG')

class ScopedSearch::Test::DatabaseSchema < ActiveRecord::Migration

  def self.up
    
    create_table :foos do |t|
      t.string :string_field
      t.text :text_field
      t.string :ignored_field
      t.integer :some_int_field
      t.date :date_field
      t.timestamps
    end
    
    create_table :users do |t|
      t.string :first_name, :last_name, :login
      t.integer :age
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
    drop_table :foos    
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