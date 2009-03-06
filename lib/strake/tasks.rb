STRAKE_INDEXES = Dir["strake/tasks/*.rake"].map { |f| f[/\d+/].to_i }
STRAKE_COUNT = STRAKE_INDEXES.length

namespace :strake do

  # Not for public use
  task :strake_environment => :environment do
    require 'strake/engine'
  end

  desc "List strake tasks (DEPRECATED, use rake strake:status)"
  task :list => :strake_environment do
    Strake.print_list
  end
  
  desc "Print a status report"
  task :status => :strake_environment do
    Strake.print_status
  end

  [true, false].each do |trace|

    defs = lambda do
      
      desc "Execute the next pending task. Use up2, up3, etc. to execute the next few tasks."
      task :up => :strake_environment do
        Strake.execute_next(1, trace)
      end

      (2..STRAKE_COUNT).each do |i|
        task :"up#{i}" => :strake_environment do
          Strake.execute_next(i, trace)
        end
      end

      desc "Execute all the pending tasks"
      task :all_up => :strake_environment do
        Strake.execute_all(trace)
      end

      (STRAKE_INDEXES + [0]).each do |i|
        desc "Go to the state just after executing the given strake, executing strakes or restoring a backup as needed"
        task :"to_#{i}" => :strake_environment do
          Strake.to(i, trace)
        end
      end

      desc "Redo the last executed strake"
      task :redo => :strake_environment do
        Strake.redo(nil, trace)
      end

      STRAKE_INDEXES.each do |i|
        task :"redo_#{i}" => :strake_environment do
          Strake.redo(i, trace)
        end
      end

    end
    if trace
      namespace :t, &defs
    else
      instance_eval &defs
    end
    
  end

  desc "Restore the backup made before the last executed strake. Use down2, down3, etc. to restore earlier backups"
  task :down => :strake_environment do
    Strake.restore_backup(1)
  end

  (2..STRAKE_COUNT).each do |i|
    task :"down#{i}" => :strake_environment do
      Strake.restore_backup(i)
    end
  end
  
  desc "Restore the backup made before any strake was executed."
  task :all_down => :strake_environment do
    Strake.restore_original_backup
  end

  # Not for public use
  task :__run__ => :strake_environment do
    n = ENV["n"] or raise "no n specified"
    n = Integer(n)
    task = Strake.tasks[n] or raise "task #{n} not found"
    task.execute
  end

  desc "Restore the first strake backup and then remove strake from the database"
  task :remove => :strake_environment do
    Strake.remove_strake
  end
  
  task :dump_plain_data => :strake_environment do
    Strake.dump_plain_data
  end

end
