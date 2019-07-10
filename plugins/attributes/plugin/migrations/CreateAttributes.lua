ActiveRecord.define_model('attributes', function(t)
  t:string  'attribute_id'
  t:integer 'character_id'
  t:integer 'level'
  t:integer 'progress'
end)
