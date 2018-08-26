ActiveRecord.define_model('Data', function(t)
  t:string 'key'
  t:text 'value'
  t:integer 'character_id'
end)

Data:belongs_to 'Character'
