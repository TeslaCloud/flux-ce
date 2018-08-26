ActiveRecord.define_model('Role', function(t)
  t:string 'name'
  t:text 'description'
  t:integer 'user_id'
end)

Role:belongs_to 'User'
Role:has_many 'permissions'
