# The strake task defined belowed is what will be called. Edit it
# whatever way you want. There should only be one strake task per
# file though.

# When it is loaded, the other strake tasks are not loaded, so you
# can define methods and constants whichever way you want without
# the risk of them clashing between strake tasks. You should put
# these declarations after the strake_desc declaration to be save
# though. You can do otherwise on your own risk.

# The strake task takes a database snapshot beforehand and
# automatically executes your code in a database transaction.
# The strake task also automatically loads the Rails environment.

strake_desc "Description for strake task <%= name %>"

strake_task :<%= name %> do
  # Here goes your code.
  # You can add dependencies if you want, just know that they
  # will be executed outside the transaction.
end
