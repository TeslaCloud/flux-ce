ActiveRecord.define_model('Ammo', function(t)
  t:string 'type'
  t:integer 'amount'
  t:integer 'character_id'
end)

Ammo:belongs_to 'Character'
