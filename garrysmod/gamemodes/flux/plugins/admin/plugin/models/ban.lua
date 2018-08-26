ActiveRecord.define_model('Ban', function(t)
  t:string 'name'
  t:string 'steam_id'
  t:text 'reason'
  t:integer 'duration'
  t:datetime 'unban_time'
end)
