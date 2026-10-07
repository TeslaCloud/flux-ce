local CreateCharactersTables = ActiveRecord.Migration.new()

function CreateCharactersTables:change()
  create_table('characters', function(t)
    t:references('user', { foreign_key = { on_delete = 'cascade' } })
    t:string { 'steam_id', null = false }
    t:string { 'name', null = false }
    t:integer 'gender'
    t:text 'phys_desc'
    t:string 'model'
    t:integer 'skin'
    t:integer 'health'
    t:timestamps()
  end)

  create_table('ammunitions', function(t)
    t:string 'type'
    t:integer 'amount'
    t:references('character', { foreign_key = { on_delete = 'cascade' } })
    t:timestamps()
  end)
end

return CreateCharactersTables
