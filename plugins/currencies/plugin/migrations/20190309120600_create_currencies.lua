--- Migration that creates the `currencies` table.

local CreateCurrencies = ActiveRecord.Migration.new()

--- Creates the currencies table.
function CreateCurrencies:change()
  create_table('currencies', function(t)
    t:references('character', { foreign_key = { on_delete = 'cascade' } })
    t:string 'currency_id'
    t:integer 'amount'
    t:timestamps()
  end)
end

return CreateCurrencies
