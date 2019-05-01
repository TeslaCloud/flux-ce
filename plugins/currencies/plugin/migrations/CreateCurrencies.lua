ActiveRecord.define_model('currencies', function(t)
  t:integer 'character_id'
  t:string 'currency_id'
  t:integer 'amount'
end)
