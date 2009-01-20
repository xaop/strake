require 'erb'

module Strake
  
  class Template
    
    def initialize(template, data)
      @__template__ = template
      data.each do |name, value|
        instance_variable_set(:"@#{name}", value)
      end
    end
    
    def run
      ERB.new(File.read(File.join(File.dirname(__FILE__), "templates", @__template__))).result(binding)
    end
    
    class << self
      
      def generate(template, data)
        Template.new(template, data).run
      end
      
    end
    
  end
  
end
