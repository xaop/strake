require 'fileutils'

module Strake
  
  class Installer
  
    def initialize(rails_dir)
      @rails_dir = File.expand_path(rails_dir)
    end

    def create_rails_dir_structure
      create_dir("strake")
      create_dir("strake/tasks")
      create_dir("strake/snapshots")
    end
  
    def create_model
      Dir.chdir(@rails_dir) do
        output = `script/generate migration create_strakes`
        migration_file = output[/db\/migrate\/\d+_create_strakes.rb/]
        edit_file(migration_file) do |data|
          data.replace("require 'strake/migration'")
        end
        system 'rake db:migrate'
      end
    end

    def adapt_environment
      environment_file = "config/environment.rb"
      edit_file(environment_file) do |data|
        require_line = "require 'strake/environment'\n"
        data[/#{Regexp.escape(require_line)}|\z/] = require_line
      end
    end

    def create_tasks
      rake_file = 'lib/tasks/strake.rake'
      create_file(rake_file, 'require "strake/tasks"')
    end

    def create_plugin
      create_dir('vendor/plugins/strake')
      create_dir('vendor/plugins/strake/generators')
      create_dir('vendor/plugins/strake/generators/strake')
      create_dir('vendor/plugins/strake/generators/strake/templates')
      create_file('vendor/plugins/strake/generators/strake/strake_generator.rb', 'require "strake/strake_generator"')
      create_file('vendor/plugins/strake/init.rb', '')
      create_file('vendor/plugins/strake/generators/strake/templates/strake.rake', get_file_content('templates/strake.rake'))
    end

  private
  
    def edit_file(file)
      file = relative(file)
      puts "editing #{file}"
      data = File.read(file)
      yield data
      File.open(file, "w") { |f| f << data }
    end
  
    def relative(dir)
      File.join(@rails_dir, dir)
    end
  
    def relative_to_source(dir)
      File.join(File.dirname(__FILE__), dir)
    end
  
    def create_dir(dir)
      dir = relative(dir)
      puts "creating #{dir}/"
      FileUtils.mkdir_p dir
    end
    
    def create_file(file, data)
      file = relative(file)
      puts "creating #{file}"
      File.open(file, "w") { |f| f << data }
    end
    
    def get_file_content(file)
      File.read(relative_to_source(file))
    end

  end
  
end
