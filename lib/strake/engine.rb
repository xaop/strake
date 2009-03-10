require 'base64'

module Strake

  REQUIRED_STRAKE_MODEL_VERSION = "0.0.1"
  LATEST_STRAKE_MODEL_VERSION = "0.0.9"

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
      self.my_data_will_change! if self.respond_to?(:my_data_will_change!)
      save!
    end
    
    before_save do |record|
      version = record.respond_to?(:version) ? record.version : "0.0.1"
      max_size = case version
      when "0.0.1" : 2 ** 16 - 1
      when "0.0.9" : 2 ** 24 - 1
      else
        raise "not yet #{version}"
      end
      if record.my_data.to_yaml.to_yaml.length > max_size
        raise "You have hit a limitation of the installed version of Strake so I cannot execute this task for you. Run 'rake strake:update_strake' to update to a newer version."
      end
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
            begin
              eval script
            rescue Exception => e
            end
          end
          @desc || "<ERROR>"
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
      Strake.create_snapshot(snapshot_location)
    end
    
    def execute_in_separate_shell
      system "rake strake:#{"v:" if $VERBOSE_STRAKES}__run__ n=#{@index} #{"--trace" if $TRACE_STRAKES}"
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
      Rake::Task[@name].invoke
      Strake::Data.instance.add_executed_task(executed_task)
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

    def initialize(task)
      @file = task.file
      @index = task.index
      @name = task.name
      @script = Base64.encode64(task.script)
      @snapshot_location = task.snapshot_location
      @snapshot_checksum = task.snapshot_checksum
    end
    
    def script
      @exploded_script ||= begin
        if @script[/strake_task/]  # This should signal Ruby code
          @script
        else
          Base64.decode64(@script)
        end
      end
    end
    
    def actual_checksum
      @actual_checksum ||= calculate_checksum
    end
    
    def check_consistency(task)
      messages = []
      messages << "strake file name has changed" if task.file != self.file
      messages << "strake file has changed" if task.script != self.script
      messages << "snapshot location has changed" if task.snapshot_location != self.snapshot_location
      messages << (self.actual_checksum ? "snapshot has changed" : "snapshot has been deleted") if self.actual_checksum != self.snapshot_checksum
      messages
    end
    
    def restore_backup
      raise "backup cannot be restored because it was changed behind my back" if self.actual_checksum != self.snapshot_checksum
      Strake.load_snapshot(snapshot_location)
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
    
    def dump_plain_data
      m = Class.new(ActiveRecord::Base) { set_table_name(:strake_data) }
      puts m.find(:first).my_data
    end
    
    def load_snapshot(filename)
      puts "restoring database to backup #{filename}"
      user, password, database = ActiveRecord::Base.configurations[RAILS_ENV].values_at(*%w[username password database])
      # I'd rather catch these and take action after the restore if needed,
      # but unless I put IGNORE I cannot keep the child process from dying.
      # Well, I don't know how anyway.
      old_int = Signal.trap("INT", "IGNORE")
      old_term = Signal.trap("TERM", "IGNORE")
      ActiveRecord::Base.connection.instance_eval { @connection }.list_tables.each do |table|
        ActiveRecord::Base.connection.execute("DROP TABLE #{table};")
      end
      command = "gunzip -c #{filename.inspect} > #{filename.sub(/\.gz\z/, "")}"
      run_command command
      run_command "mysql #{mysql_params} < #{filename.sub(/\.gz\z/, "")}"
      Signal.trap("INT", old_int)
      Signal.trap("TERM", old_term)
    end
    
    def create_snapshot(filename)
      puts "creating database backup as #{filename}"
      command = "mysqldump --add-drop-table --add-locks --extended-insert --lock-tables #{mysql_params} > #{filename.sub(/\.gz\z/, "").inspect}"
      run_command command
      run_command "gzip -f #{filename.sub(/\.gz\z/, "").inspect}"
    end
    
    def mysql_params
      user, password, database, host, socket = ActiveRecord::Base.configurations[RAILS_ENV].values_at(*%w[username password database host socket])
      extra_params = if host
        "-h #{host.inspect} "
      elsif socket
        "--socket #{socket.inspect} "
      else
        ""
      end
      extra_params + "-u #{user} --password=#{(password || "").inspect} #{database}"
    end
    
    def run_command(command)
      puts command if $VERBOSE_STRAKES
      system command
      unless $?.exitstatus == 0
        raise "command #{command.inspect} exited with an exit status of #{$?.exitstatus}"
      end
    end
    
    def update_strake(force = false)
      if current_strake_model_version == parse_version(LATEST_STRAKE_MODEL_VERSION)
        puts "Strake is up to date"
      else
        puts "Updating strake version #{LATEST_STRAKE_MODEL_VERSION}"
        snapshot_file = "strake/snapshots/strake_update.sql.gz"
        create_snapshot(snapshot_file)
        begin
          do_update_strake(force)
        rescue Exception => e
          load_snapshot(snapshot_file)
          raise
        end
      end
    end
    
    def current_strake_model_version
      if data = Strake::Data.instance
        if data.respond_to?(:version)
          parse_version(data.version)
        else
          parse_version("0.0.1")
        end
      end
    end
    
    def parse_version(version_string)
      version_string.scan(/\d+/).map { |n| n.to_i }
    end
    
    def print_current_strake_model_version
      puts current_strake_model_version.join(".")
    end
    
    def print_version
      puts File.read(File.join(File.dirname(__FILE__), "../../VERSION")).strip
    end
    
    def do_update_strake(force)
      current_version = current_strake_model_version
      case current_version
      when parse_version("0.0.1")
        data = Class.new(ActiveRecord::Base) { set_table_name "strake_data" }.find(:first)
        raw_data = data.my_data
        if !force && raw_data.length == 2 ** 16 - 1
          raise "You have been hit by a bug in Strake. You will need to run 'rake strake:down' once to be in a safe state."
        end
        require 'strake/migration'
        begin
          Thread.current[:strake_allow_migration] = true
          CreateStrakes.migrate(:down)
          CreateStrakes.migrate(:up)
        ensure
          Thread.current[:strake_allow_migration] = false
        end
        data.reload
        data.update_attributes(:my_data => raw_data)
        reload
        print_status
      when nil
        raise "Strake's migration has not run yet"
      else
        raise "not yet #{current_strake_model_version.join(".")}"
      end

    end
    
  end

end
