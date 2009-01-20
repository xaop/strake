namespace :strake do

  task :strake_environment => :environment do
    require 'strake/engine'
  end

  desc "List strake tasks"
  task :list => :strake_environment do
    Strake.print_list
  end
  
  desc "Print a status report"
  task :status => :strake_environment do
    Strake.print_status
  end

  desc "Execute the next pending task. Use up2, up3, etc. to execute the next few tasks."
  task :up => :strake_environment do
    Strake.execute_next
  end

  (2..20).each do |i|
    task :"up#{i}" => :strake_environment do
      Strake.execute_next(i)
    end
  end

  desc "Execute the next pending task. Use up2, up3, etc. to execute the next few tasks."
  task :down => :strake_environment do
    Strake.restore_backup
  end

  (2..20).each do |i|
    task :"down#{i}" => :strake_environment do
      Strake.restore_backup(i)
    end
  end

  # Not for public use
  task :__run__ => :strake_environment do
    n = ENV["n"] or raise "no n specified"
    n = Integer(n)
    task = Strake.tasks[n] or raise "task #{n} not found"
    task.execute
  end

end
