PLUGIN:set_global('Currencies')

local stored = Currencies.stored or {}
Currencies.stored = stored

do
  function Currencies:register_currency(id, data)
    stored[id] = data
  end

  function Currencies:all()
    return stored
  end

  function Currencies:find_currency(id)
    return stored[id:lower()]
  end
end

require_relative 'cl_hooks'
require_relative 'sv_hooks'
