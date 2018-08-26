ActiveRecord.define_model('Permission', function(t)
  t:string 'name'
  t:text 'description'
  t:integer 'user_id'
  t:integer 'role_id'
end)

Permission:belongs_to 'User'
Permission:belongs_to 'Role'
