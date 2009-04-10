STRAKE_INDEXES = Dir["strake/tasks/*.rake"].map { |f| f[/\d+/].to_i }
STRAKE_COUNT = STRAKE_INDEXES.length

def strake_no_descriptions
  old = Thread.current[:block_strake_descriptions]
  Thread.current[:block_strake_descriptions] = true
  yield
  Thread.current[:block_strake_descriptions] = old
end

def strake_trace_or_not(trace, &blk)
  if trace
    strake_no_descriptions do
      namespace :t, &blk
    end
  else
    yield
  end
end

def strake_verbose_or_not(verbose, &blk)
  if verbose
    strake_no_descriptions do
      namespace :v, &blk
    end
  else
    yield
  end
end

def strake_desc(*a)
  unless Thread.current[:block_strake_descriptions]
    desc(*a)
  end
end

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

  [true, false].each do |verbose|

    strake_verbose_or_not(verbose) do

      # Not for public use
      task :__run__ => :strake_environment do
        n = ENV["n"] or raise "no n specified"
        n = Integer(n)
        $DEBUG = $VERBOSE_STRAKES = verbose
        task = Strake.tasks[n] or raise "task #{n} not found"
        task.execute
      end

      [true, false].each do |trace|

        strake_trace_or_not(trace) do # This is somewhat weird, but that is because 1.8.6 doesn't have instance_exec

          strake_desc "Execute the next pending task. Use up2, up3, etc. to execute the next few tasks."
          task :up => :strake_environment do
            $DEBUG = $VERBOSE_STRAKES = verbose
            Strake.execute_next(1, trace)
          end

          (2..STRAKE_COUNT).each do |i|
            task :"up#{i}" => :strake_environment do
              $DEBUG = $VERBOSE_STRAKES = verbose
              Strake.execute_next(i, trace)
            end
          end

          strake_desc "Execute 'rake strake:up' count times"
          task :"up<count>" => :strake_environment do
            puts "Please replace <count> with a number of tasks"
          end

          strake_desc "Execute all the pending tasks"
          task :all_up => :strake_environment do
            $DEBUG = $VERBOSE_STRAKES = verbose
            Strake.execute_all(trace)
          end

          (STRAKE_INDEXES + [0]).each do |i|
            task :"to_#{i}" => :strake_environment do
              $DEBUG = $VERBOSE_STRAKES = verbose
              Strake.to(i, trace)
            end
          end

          strake_desc "Go to the state just after executing strake <index>, executing strakes or restoring a backup as needed"
          task :"to_<index>" => :strake_environment do
            puts "Please replace <index> with the number of a strake task"
          end

          strake_desc "Redo the last executed strake"
          task :redo => :strake_environment do
            $DEBUG = $VERBOSE_STRAKES = verbose
            Strake.redo(nil, trace)
          end

          STRAKE_INDEXES.each do |i|
            task :"redo_#{i}" => :strake_environment do
              $DEBUG = $VERBOSE_STRAKES = verbose
              Strake.redo(i, trace)
            end
          end

          strake_desc "Reexecute strake <index>, executing strakes or restoring a backup as needed to get to the state before strake <index>"
          task :"redo_<index>" => :strake_environment do
            puts "Please replace <index> with the number of a strake task"
          end

        end

      end

      strake_desc "Restore the backup made before the last executed strake. Use down2, down3, etc. to restore earlier backups"
      task :down => :strake_environment do
        $DEBUG = $VERBOSE_STRAKES = verbose
        Strake.restore_backup(1)
      end

      (2..STRAKE_COUNT).each do |i|
        task :"down#{i}" => :strake_environment do
          $DEBUG = $VERBOSE_STRAKES = verbose
          Strake.restore_backup(i)
        end
      end

      strake_desc "Execute 'rake strake:down' count times"
      task :"down<count>" => :strake_environment do
        puts "Please replace <count> with a number of tasks"
      end
  
      strake_desc "Restore the backup made before any strake was executed."
      task :all_down => :strake_environment do
        $DEBUG = $VERBOSE_STRAKES = verbose
        Strake.restore_original_backup
      end

      strake_desc "Restore the first strake backup and then remove strake from the database"
      task :remove => :strake_environment do
        $DEBUG = $VERBOSE_STRAKES = verbose
        Strake.remove_strake
      end
  
      strake_desc "Load a specific snapshot file"
      task :load_snapshot => :strake_environment do
        file = ENV['f'] or raise "no file (f) specified"
        $DEBUG = $VERBOSE_STRAKES = verbose
        Strake.load_snapshot(file)
      end

      strake_desc "Create a specific snapshot file"
      task :create_snapshot => :strake_environment do
        file = ENV['f'] or raise "no file (f) specified"
        $DEBUG = $VERBOSE_STRAKES = verbose
        Strake.create_snapshot(file)
      end
  
      strake_desc "Update strake database model to the latest version"
      task :update_strake => :strake_environment do
        $DEBUG = $VERBOSE_STRAKES = verbose
        Strake.update_strake
      end
  
      strake_desc "Update strake database model to the latest version without checking that it is in a state where corruption can occur"
      task :force_update_strake => :strake_environment do
        $DEBUG = $VERBOSE_STRAKES = verbose
        Strake.update_strake(true)
      end
  
    end
  
  end

  task :dump_plain_data => :strake_environment do
    Strake.dump_plain_data
  end

  task :print_current_strake_model_version => :strake_environment do
    Strake.print_current_strake_model_version
  end

  strake_desc "Print the version of strake being used"
  task :version => :strake_environment do
    Strake.print_version
  end

end

# Clean up the helper methods
undef strake_no_descriptions
undef strake_trace_or_not
undef strake_verbose_or_not
undef strake_desc
