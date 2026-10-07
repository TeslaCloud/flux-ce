local CreateAdminTables = ActiveRecord.Migration.new()

--- Creates the permissions, temp_permissions and bans tables, and adds the role and
-- banned columns to users.
function CreateAdminTables:change()
  create_table('permissions', function(t)
    t:string 'permission_id'
    t:integer 'object'
    t:references('user', { foreign_key = { on_delete = 'cascade' } })
    t:timestamps()
  end)

  create_table('temp_permissions', function(t)
    t:string 'permission_id'
    t:integer 'object'
    t:references('user', { foreign_key = { on_delete = 'cascade' } })
    t:timestamp 'expires'
    t:timestamps()
  end)

  create_table('bans', function(t)
    t:string 'name'
    t:string 'steam_id'
    t:text 'reason'
    t:integer 'duration'
    t:datetime 'unban_time'
    t:timestamps()
  end)

  add_column('users', 'role', 'string', { default = '\'user\'' })
  add_column('users', 'banned', 'boolean', { default = false })
end

return CreateAdminTables
