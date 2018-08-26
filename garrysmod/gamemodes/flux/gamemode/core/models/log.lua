ActiveRecord.define_model('Log', function(t)
  t:text 'body'
  t:string 'action'
  t:string 'object'
  t:string 'subject'
end)
