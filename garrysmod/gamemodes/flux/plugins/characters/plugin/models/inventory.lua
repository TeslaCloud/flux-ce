ActiveRecord.define_model('Inventory', function(t)
  t:integer 'item_id'
  t:integer 'character_id'
end)

Inventory:belongs_to 'Character'
