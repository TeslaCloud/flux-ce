--- Migration that creates the `recognizes` table, which holds the characters that a
-- character recognizes and the names it knows them by.

ActiveRecord.define_model('recognizes', function(t)
  t:integer 'character_id'
  t:integer 'target_id'
  t:string  'name'
end)
