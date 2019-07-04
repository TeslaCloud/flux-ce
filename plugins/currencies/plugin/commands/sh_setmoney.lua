local COMMAND = Command.new('setmoney')
COMMAND.name = 'SetMoney'
COMMAND.description = 'command.set_money.description'
COMMAND.syntax = 'command.set_money.syntax'
COMMAND.permission = 'moderator'
COMMAND.category = 'perm.categories.character_management'
COMMAND.arguments = 2
COMMAND.player_arg = 1
COMMAND.aliases = { 'setcash', 'settokens' }

function COMMAND:get_description()
  local currencies = {}

  for k, v in pairs(Currencies:all()) do
    table.insert(currencies, k)
  end

  return t(self.description, table.concat(currencies, ', '))
end

function COMMAND:on_run(player, targets, amount, currency)
  amount = tonumber(amount)

  if !amount then
    player:notify('notification.currency.invalid_amount')

    return
  end

  amount = math.max(0, amount)
  currency = currency or Config.get('default_currency')

  if !Currencies:find_currency(currency) then
    currency = Config.get('default_currency')

    if !Currencies:find_currency(currency) then
      player:notify('notification.currency.invalid_currency')

      return
    end
  end

  local currency_data = Currencies:find_currency(currency)

  player:notify('set_money.message', { util.player_list_to_string(targets), amount, currency_data.name })

  for k, v in ipairs(targets) do
    v:set_money(currency, amount)

    if player != v then
      v:notify('notification.currency.set', { amount, currency })
    end
  end
end

COMMAND:register()
