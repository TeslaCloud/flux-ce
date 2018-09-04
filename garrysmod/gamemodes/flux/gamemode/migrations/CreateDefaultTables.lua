ActiveRecord.define_model('users', function(t)
  t:string { 'steam_id', null = false }
  t:string { 'name', null = false }
end)

ActiveRecord.define_model('logs', function(t)
  t:text 'body'
  t:string 'action'
  t:string 'object'
  t:string 'subject'
end)
