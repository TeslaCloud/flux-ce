ActiveRecord.define_model('attributes', function(t)
  t:string  'attribute_id'
  t:integer 'character_id'
  t:integer 'level'
  t:integer 'progress'
end)

ActiveRecord.define_model('attribute_multipliers', function(t)
  t:integer   'attribute_id'
  t:integer   'value'
  t:datetime  'expires_at'
end)

ActiveRecord.define_model('attribute_boosts', function(t)
  t:integer   'attribute_id'
  t:integer   'value'
  t:datetime  'expires_at'
end)
