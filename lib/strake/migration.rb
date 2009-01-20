require 'strake/engine'

class CreateStrakes < ActiveRecord::Migration
  def self.up
    create_table :strake_data do |t|
      t.column "my_data", :text, :null => false
    end
    Strake::Data.create!(:my_data => {})
  end

  def self.down
    drop_table :strake_data
  end
end
