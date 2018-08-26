ActiveRecord.define_model('Whitelist', function(t)
  t:string 'faction_id'
  t:integer 'character_id'
end)

Whitelist:belongs_to 'User'
