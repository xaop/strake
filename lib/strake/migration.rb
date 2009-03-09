class CreateStrakes < ActiveRecord::Migration
  def self.up
    require 'strake/engine'

    create_table :strake_data do |t|
      t.column "my_data", :text, :null => false, :limit => 2**24 - 1
      t.column "version", :string, :limit => 8
    end
    Strake::Data.reset_column_information
    Strake::Data.create!(:my_data => {}, :version => "0.0.9")
  end

  def self.down
    drop_table :strake_data
  end
end
