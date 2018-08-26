ActiveRecord.define_model('Player', function(t)
  t:string { 'steam_id', null = false }
  t:string { 'name', null = false }
end)
