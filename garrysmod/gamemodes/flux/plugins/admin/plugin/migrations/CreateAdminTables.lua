ActiveRecord.define_model('permissions', function(t)
  t:string 'permission_id'
  t:string 'object'
  t:integer 'user_id'
end)

ActiveRecord.define_model('bans', function(t)
  t:string 'name'
  t:string 'steam_id'
  t:text 'reason'
  t:integer 'duration'
  t:integer 'user_id'
  t:datetime 'unban_time'
end)

add_column('users', { 'role', type = 'string', default = '\'user\'' })
add_column('users', { 'banned', type = 'boolean', default = false })
