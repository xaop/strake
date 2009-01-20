class Object

  def strake_desc(*a)
    # Throw it all down the garbage bin
  end
  
  def strake_task(*a, &blk)
    name, args, deps = Rake.application.resolve_args(a)
    task name => deps do |*a|
      blk.call(*a)
    end
  end
  
end
