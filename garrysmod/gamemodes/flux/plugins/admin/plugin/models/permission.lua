ActiveRecord.define_model('Permission', function(t)
  t:string 'name'
  t:text 'description'
  t:integer 'player_id'
  t:integer 'role_id'
end)

Permission:belongs_to 'Player'
Permission:belongs_to 'Role'
