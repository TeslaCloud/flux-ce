ActiveRecord.define_model('Role', function(t)
  t:string 'name'
  t:text 'description'
  t:integer 'player_id'
end)

Role:belongs_to 'Player'
Role:has_many 'permissions'
