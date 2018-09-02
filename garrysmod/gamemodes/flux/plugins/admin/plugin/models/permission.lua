ActiveRecord.define_model('Permission', function(t)
  t:string 'permission_id'
  t:string 'object'
  t:integer 'user_id'
end)

Permission:belongs_to 'User'
