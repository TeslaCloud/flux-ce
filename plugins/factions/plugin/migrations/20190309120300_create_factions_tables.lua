local CreateFactionsTables = ActiveRecord.Migration.new()

--- Creates the whitelists table, and adds the faction and rank columns to characters.
function CreateFactionsTables:change()
  create_table('whitelists', function(t)
    t:string 'faction_id'
    t:references('user', { foreign_key = { on_delete = 'cascade' } })
    t:timestamps()
  end)

  add_column('characters', 'faction', 'string', { default = '\'player\'' })
  add_column('characters', 'rank', 'integer', { null = true })
end

return CreateFactionsTables
