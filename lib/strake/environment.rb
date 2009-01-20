class ActiveRecord::Migration

  class << self

    alias prev_migrate migrate

    def migrate(*a, &b)
      if Thread.current[:strake_allow_migration]
        prev_migrate(*a, &b)
      else
        raise "Running migrations outside strake is not allowed. Please create a strake task to run your migrations. Do script/generate strake migration VERSION to get a skeleton."
      end
    end

  end

end
