module Strake

  class Data < ActiveRecord::Base

    set_table_name "strake_data"

    def self.instance
      @instance ||= find(:first)
    end

    serialize :my_data

    def executed_tasks
      my_data[:executed_tasks] ||= []
    end
    
    def add_executed_task(task)
      executed_tasks[task.index] = task
      save!
    end
  
  end

  class AbstractTask

    attr_reader :file
    attr_reader :index
    attr_reader :name
    
    def description
      @description ||= begin
        script = self.script
        Object.new.instance_eval do
          def strake_desc(desc)
            @desc = desc
            throw :desced
          end
          catch(:desced) do
            eval script
          end
          @desc
        end
      end
    end
    
    def calculate_checksum
      # File.exist?(snapshot_location) ? %x{md5 #{snapshot_location.inspect}}[/[0-9a-f]{32}/] : nil
      require 'digest/md5'
      file = File.join(RAILS_ROOT, snapshot_location)
      File.exist?(file) ? Digest::MD5.hexdigest(File.read(file)) : nil
    end
    
    def one_line_description
      description.sub(/\n.*/m, "...")
    end
    
  end

  class Task < AbstractTask
    
    def initialize(file)
      @file = file
      @index = file[/\d+/].to_i
      @name = file[/\w+\.rake\z/][4..-6]
    end
    
    def script
      @script ||= File.read(File.join(RAILS_ROOT, file))
    end
    
    def snapshot_location
      @snapshot_location ||= "strake/snapshots/%03d_%s.sql.gz" % [@index, @name]
    end
    
    def snapshot_checksum
      @snapshot_checksum ||= calculate_checksum
    end
    
    def create_snapshot
      puts "creating database backup as #{snapshot_location}"
      user, password, database = ActiveRecord::Base.configurations[RAILS_ENV].values_at(*%w[username password database])
      command = "mysqldump -u #{user} --password=#{(password || "").inspect} --add-drop-table --add-locks --extended-insert --lock-tables #{database} | gzip > #{snapshot_location.inspect}"
      system command
    end
    
    def execute_in_separate_shell
      system "rake strake:__run__ n=#{@index} #{"--trace" if $TRACE_STRAKES}"
      unless $?.exitstatus == 0
        puts "the call to task #{@file} seems to have failed"
        exit($?.exitstatus)
      end
    end
    
    def execute
      wd = Dir.getwd
      create_snapshot
      executed_task = ExecutedTask.new(self)
      require 'strake/definitions'
      load @file
      ActiveRecord::Base.transaction do
        Rake::Task[@name].invoke
        Strake::Data.instance.add_executed_task(executed_task)
      end
    rescue Exception => e
      Dir.chdir(wd)
      begin
        executed_task.restore_backup if executed_task
      rescue Exception
      end
      raise e
    end
    
  end
  
  class ExecutedTask < Task

    attr_reader :script
    
    def initialize(task)
      @file = task.file
      @index = task.index
      @name = task.name
      @script = task.script
      @snapshot_location = task.snapshot_location
      @snapshot_checksum = task.snapshot_checksum
    end
    
    def actual_checksum
      @actual_checksum ||= calculate_checksum
    end
    
    def check_consistency(task)
      messages = []
      messages << "strake file name has changed" if task.file != self.file
      messages << "strake file has changed" if task.script.gsub(/\s+/, ' ') != self.script.gsub(/\s+/, ' ')
      messages << "snapshot location has changed" if task.snapshot_location != self.snapshot_location
      messages << (self.actual_checksumecksum ? "snapshot has changed" : "snapshot has been deleted") if self.actual_checksum != self.snapshot_checksum
      messages
    end
    
    def restore_backup
      puts "restoring database to backup #{snapshot_location}"
      raise "backup cannot be restored because it was changed behind my back" if self.actual_checksum != self.snapshot_checksum
      user, password, database = ActiveRecord::Base.configurations[RAILS_ENV].values_at(*%w[username password database])
      # I'd rather catch these and take action after the restore if needed,
      # but unless I put IGNORE I cannot keep the child process from dying.
      # Well, I don't know how anyway.
      old_int = Signal.trap("INT", "IGNORE")
      old_term = Signal.trap("TERM", "IGNORE")
      command = "echo 'drop database #{database} ; create database #{database}' | mysql -u #{user} --password=#{(password || "").inspect} #{database}"
      system command
      command = "gunzip -c #{snapshot_location.inspect} | mysql -u #{user} --password=#{(password || "").inspect} #{database}"
      system command
      Signal.trap("INT", old_int)
      Signal.trap("TERM", old_term)
    end
    
  end

  class << self

    def reload
      @tasks = nil
      Strake::Data.instance.reload
    end

    def tasks
      @tasks ||= Dir[File.join(RAILS_ROOT, 'strake/tasks/*.rake')].map { |file| Strake::Task.new(file[(RAILS_ROOT.length + 1)..-1]) }.inject([]) { |ary, task| ary[task.index] = task ; ary }
    end
    
    def each_task
      tasks.each do |task|
        yield task if task
      end
    end
    
    def executed_tasks
      Strake::Data.instance.executed_tasks
    end
    
    def each_executed_task
      executed_tasks.each do |task|
        yield task if task
      end
    end
    
    def next_task_index_to_create
      (tasks.map { |t| t ? t.index : 0 }.max || 0) + 1
    end
    
    def last_executed_task
      executed_tasks.compact.last
    end
    
    def new_task_file(name)
      "strake/tasks/%03d_%s.rake" % [next_task_index_to_create, name]
    end
    
    def cutoff
      res = last_executed_task
      res &&= res.index
      res || 0
    end
    
    def next_task
      cutoff = self.cutoff
      each_task do |task|
        return task if task.index > cutoff
      end
      nil
    end
    
    def print_list
      each_task do |task|
        puts "%03d - %s : %s" % [task.index, task.name, task.one_line_description]
      end
    end
    
    def print_status
      puts "Executed :"
      cutoff = self.cutoff
      (1..cutoff).each do |index|
        executed_task = executed_tasks[index]
        task = tasks[index]
        if executed_task
          if task
            puts "   %03d - %s : %s" % [executed_task.index, executed_task.name, executed_task.one_line_description]
            executed_task.check_consistency(task).each do |message|
              puts "    -> %s" % message
            end
          else
            puts "   %03d - %s : %s" % [executed_task.index, executed_task.name, executed_task.one_line_description]
            puts "     -> this task has been executed but has since disappeared"
          end
        elsif task
          puts "  (%03d - %s : %s)" % [task.index, task.name, task.one_line_description]
          puts "    -> this task has been inserted but was not executed on the database"
        end
      end
      puts "Not yet executed :"
      each_task do |task|
        if task.index > cutoff
          puts "   %03d - %s : %s" % [task.index, task.name, task.one_line_description]
        end
      end
    end
    
    def execute_next(number, trace)
      $TRACE_STRAKES = trace
      number.times do
        task = next_task or raise "no next task to execute"
        task.execute_in_separate_shell
        reload
      end
    end
    
    def execute_all(trace)
      $TRACE_STRAKES = trace
      while task = next_task
        task.execute_in_separate_shell
        reload
      end
    end
    
    def restore_backup(number)
      number.times do
        task = last_executed_task or raise "no backup to restore"
        task.restore_backup
        reload
      end
    end
    
    def restore_original_backup
      while task = last_executed_task
        task.restore_backup
        reload
      end
    end
    
    def redo(i, trace)
      $TRACE_STRAKES = trace
      raise "no task #{i}" unless tasks[i]
      while task = last_executed_task and task.index >= i
        task.restore_backup
        reload
      end
      while task = next_task and task.index < i
        task.execute_in_separate_shell
        reload
      end
      task = next_task
      task.execute_in_separate_shell
      reload
    end
    
    def to(i, trace)
      $TRACE_STRAKES = trace
      raise "no task #{i}" unless tasks[i] || i == 0
      while task = last_executed_task and task.index > i
        task.restore_backup
        reload
      end
      while task = next_task and task.index <= i
        task.execute_in_separate_shell
        reload
      end
    end
    
    def remove_strake
      if task = last_executed_task
        restore_original_backup
      end
      Thread.current[:strake_allow_migration] = true
      my_migration = Integer(Dir["db/migrate/*_create_strakes.rb"].select { |f| /\/\d+_create_strakes\.rb\z/ === f }[0][/[1-9]\d*/])
      migrate_to = Dir["db/migrate/*.rb"].map { |f| Integer(f[/[1-9]\d*/]) }.select { |v| v < my_migration }.max || 0
      ENV["VERSION"] = migrate_to.to_s
      Rake::Task['db:migrate'].invoke
      Thread.current[:strake_allow_migration] = false
    end
    
  end

end
