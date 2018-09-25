ActiveRecord.define_model('attributes', function(t)
  t:string 'attr_id'
  t:integer 'character_id'
  t:integer 'value'
end)

ActiveRecord.define_model('attribute_multipliers', function(t)
  t:integer 'attribute_id'
  t:integer 'value'
  t:integer 'duration'
end)

ActiveRecord.define_model('attribute_boosts', function(t)
  t:integer 'attribute_id'
  t:integer 'value'
  t:integer 'duration'
end)
