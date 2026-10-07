local CreateAttributes = ActiveRecord.Migration.new()

function CreateAttributes:change()
  create_table('attributes', function(t)
    t:string  'attribute_id'
    t:references('character', { foreign_key = { on_delete = 'cascade' } })
    t:integer 'level'
    t:integer 'progress'
    t:timestamps()
  end)

  create_table('attribute_multipliers', function(t)
    t:references('attribute', { foreign_key = { on_delete = 'cascade' } })
    t:integer   'value'
    t:datetime  'expires_at'
    t:timestamps()
  end)

  create_table('attribute_boosts', function(t)
    t:references('attribute', { foreign_key = { on_delete = 'cascade' } })
    t:integer   'value'
    t:datetime  'expires_at'
    t:timestamps()
  end)
end

return CreateAttributes
