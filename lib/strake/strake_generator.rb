class StrakeGenerator < Rails::Generator::Base
  
  def initialize(runtime_args, runtime_options = {})
    require 'strake/engine'

    super
    if args.length == 2 && args.first == "migration"
      @template = "migration.rake"
      version = Integer(args.last) rescue usage
      @name = "migrate_to_#{version}"
      @data = { :version => version, :name => @name }
    elsif args.length == 1 && args.first == "migration"
      @template = "migration.rake"
      version = Dir["db/migrate/*.rb"].map { |f| f[/\Adb\/migrate\/(\d+)/, 1].to_i }.max
      @name = "migrate_to_#{version}"
      @data = { :version => version, :name => @name }
    elsif args.length == 1
      @template = "strake.rake"
      @name = args.last
      @data = { :name => @name }
    else
      usage
    end
  end

  def manifest
    record do |m|
      file = Strake.new_task_file(@name)
      template_file = 'strake.erb'
      m.template(template_file, file, :assigns => { :template => @template, :data => @data})
    end
  end
  
protected

  def banner
    <<-END
Usage: #{$0} strake NAME
       #{$0} strake migration
       #{$0} strake migration VERSION
END
  end
  
end
