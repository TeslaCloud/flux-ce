local COMMAND = Command.new('setmoney')
COMMAND.name = 'SetMoney'
COMMAND.description = 'set_money.description'
COMMAND.syntax = 'set_money.syntax'
COMMAND.permission = 'moderator'
COMMAND.category = 'categories.character_management'
COMMAND.arguments = 3
COMMAND.player_arg = 1
COMMAND.aliases = { 'setcash', 'settokens' }

function COMMAND:on_run(player, targets, amount, currency)
  amount = tonumber(amount)

  if !amount then
    player:notify('currency.notify.invalid_amount')

    return
  end

  amount = math.max(0, amount)

  local currency_data = Currencies:find_currency(currency)

  if !currency_data then
    currency_data = Currencies:find_currency(Config.get('default_currency'))

    if !currency_data then
      player:notify('currency.notify.invalid_currency')

      return
    end
  end


  player:notify('set_money.message', { util.player_list_to_string(targets), amount, currency_data.name })

  for k, v in ipairs(targets) do
    v:set_money(currency, amount)

    if player != v then
      v:notify('currency.notify.set', { amount, currency })
    end
  end
end

COMMAND:register()
