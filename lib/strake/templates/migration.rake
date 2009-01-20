# The same really as a regular migration, except that it is
# subject to the general rules of strakes.

# Just substitute the version you want to migrate to for <version>.

# This has the added advantage that if the migration fails for some
# reason, that the database is rolled back and that you can never
# have a half-executed migration.
strake_desc "Migrate the database to version <%= @version %>"

strake_task :<%= @name %> do
  migrate_to(<%= @version %>)
end
