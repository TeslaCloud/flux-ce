ActiveRecord.define_model('attributes', function(t)
  t:string 'attr_id'
  t:integer 'character_id'
  t:integer 'value'
  t:integer 'multiplier'
  t:integer 'multiplier_expires'
  t:integer 'boost'
  t:integer 'boost_expires'
end)
