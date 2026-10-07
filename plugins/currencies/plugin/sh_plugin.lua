PLUGIN:set_global('Currencies')

local stored = Currencies.stored or {}
Currencies.stored = stored

do
  --- Registers a currency. Characters created afterward get a balance record for it.
  -- ```
  -- Currencies:register_currency('tokens', {
  --   name = 'currency.tokens.name',
  --   symbol = 'T',
  --   decimals = 0,
  --   hidden = false,
  --   -- Model of dropped money, and optionally models for larger amounts.
  --   model = 'models/props_lab/box01a.mdl',
  --   model_table = { [500] = 'models/props_c17/briefcase001a.mdl' }
  -- })
  -- ```
  -- @param id [String currency ID; use lower case, lookups lower-case the ID they are given]
  -- @param data [Map currency definition: name, symbol, decimals, hidden, model, model_table]
  function Currencies:register_currency(id, data)
    stored[id] = data
  end

  --- Returns every registered currency.
  -- @return [Map currency definitions keyed by currency ID]
  function Currencies:all()
    return stored
  end

  --- Returns the definition of a registered currency.
  -- @param id [String currency ID, letter case is ignored]
  -- @return [Map currency definition, or nil if it is not registered]
  function Currencies:find_currency(id)
    return stored[id:lower()]
  end
end

require_relative 'cl_hooks'
require_relative 'sv_hooks'
