local CreateDefaultTables = ActiveRecord.Migration.new()

--- Creates the users and logs tables.
function CreateDefaultTables:change()
  create_table('users', function(t)
    t:string { 'steam_id', null = false }
    t:string { 'name', null = false }
    t:timestamps()
  end)

  create_table('logs', function(t)
    t:text 'body'
    t:string 'action'
    t:string 'object'
    t:string 'subject'
    t:timestamps()
  end)

  add_index('users', 'steam_id')
end

return CreateDefaultTables
