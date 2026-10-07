local CreateCurrencies = ActiveRecord.Migration.new()

function CreateCurrencies:change()
  create_table('currencies', function(t)
    t:references('character', { foreign_key = { on_delete = 'cascade' } })
    t:string 'currency_id'
    t:integer 'amount'
    t:timestamps()
  end)
end

return CreateCurrencies
