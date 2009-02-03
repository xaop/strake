class ActiveRecord::Migration

  class << self

    alias prev_migrate migrate

    def migrate(*a, &b)
      fully_installed = false
      begin
        cl = Class.new(ActiveRecord::Base) do
          self.table_name = "strake_data"
        end
        fully_installed = cl.find(:first)
      rescue Exception => e
      end
      if !fully_installed || Thread.current[:strake_allow_migration]
        prev_migrate(*a, &b)
      else
        raise "Running migrations outside strake is not allowed. Please create a strake task to run your migrations. Do script/generate strake migration VERSION to get a skeleton."
      end
    end

  end

end
