local COMMAND = Command.new('givemoney')
COMMAND.name = 'GiveMoney'
COMMAND.description = 'give_money.description'
COMMAND.syntax = 'give_money.syntax'
COMMAND.category = 'categories.general'
COMMAND.arguments = 1
COMMAND.aliases = { 'givecash', 'givetokens' }

function COMMAND:get_description()
  local currencies = {}

  for k, v in pairs(Currencies:all()) do
    if !v.hidden or player:get_money(k) > 0 then
      table.insert(currencies, k)
    end
  end

  return t(self.description, table.concat(currencies, ', '))
end

function COMMAND:on_run(player, amount, currency)
  amount = tonumber(amount)

  if !amount then
    player:notify('currency.notify.invalid_amount')

    return
  end

  amount = math.max(0, amount)
  currency = currency or Config.get('default_currency')

  if !Currencies:find_currency(currency) then
    currency = Config.get('default_currency')

    if !Currencies:find_currency(currency) then
      player:notify('currency.notify.invalid_currency')

      return
    end
  end

  local success, err = player:give_money_to(nil, currency, amount)

  if success == false then
    player:notify(err)
  end
end

COMMAND:register()
