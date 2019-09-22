CMD.name = 'DropMoney'
CMD.description = 'command.dropmoney.description'
CMD.syntax = 'command.dropmoney.syntax'
CMD.category = 'permission.categories.general'
CMD.arguments = 1
CMD.aliases = { 'dropcash', 'droptokens' }

function CMD:get_description()
  local currencies = {}

  for k, v in pairs(Currencies:all()) do
    if !v.hidden or player:get_money(k) > 0 then
      table.insert(currencies, k)
    end
  end

  return t(self.description, { currencies = table.concat(currencies, ', ') })
end

function CMD:on_run(player, amount, currency)
  amount = tonumber(amount)

  if !amount then
    player:notify('error.invalid_value')

    return
  end

  amount = math.max(0, amount)
  currency = currency or Config.get('default_currency')

  if !Currencies:find_currency(currency) then
    currency = Config.get('default_currency')

    if !Currencies:find_currency(currency) then
      player:notify('error.currency.invalid_currency')

      return
    end
  end

  local success, err = player:drop_money(currency, amount)

  if success == false then
    player:notify(err)
  end
end
