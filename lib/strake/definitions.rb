class Object

  def strake_desc(*a)
    # Throw it all down the garbage bin
  end
  
  def strake_task(*a, &blk)
    name, args, deps = Rake.application.resolve_args(a)
    task name => deps do |*a|
      def self.migrate_to(version)
        Thread.current[:strake_allow_migration] = true
        ENV["VERSION"] = version.to_s
        Rake::Task['db:migrate'].invoke
      ensure
        Thread.current[:strake_allow_migration] = false
      end
      blk.call(*a)
    end
  end
  
end
