ActiveRecord.define_model('ammo', function(t)
  t:string 'type'
  t:integer 'amount'
  t:integer 'character_id'
end)

ActiveRecord.define_model('characters', function(t)
  t:integer 'user_id'
  t:string { 'steam_id', null = false }
  t:string { 'name', null = false }
  t:integer 'gender'
  t:text 'phys_desc'
  t:string 'model'
  t:integer 'skin'
  t:integer 'health'
end)
