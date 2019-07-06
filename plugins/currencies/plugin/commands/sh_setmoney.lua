local COMMAND = Command.new('setmoney')
COMMAND.name = 'SetMoney'
COMMAND.description = 'command.setmoney.description'
COMMAND.syntax = 'command.setmoney.syntax'
COMMAND.permission = 'moderator'
COMMAND.category = 'permission.categories.character_management'
COMMAND.arguments = 2
COMMAND.player_arg = 1
COMMAND.aliases = { 'setcash', 'settokens' }

function COMMAND:get_description()
  local currencies = {}

  for k, v in pairs(Currencies:all()) do
    table.insert(currencies, k)
  end

  return t(self.description, { currencies = table.concat(currencies, ', ') })
end

function COMMAND:on_run(player, targets, amount, currency)
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

  local currency_data = Currencies:find_currency(currency)

  for k, v in ipairs(targets) do
    v:set_money(currency, amount)
    v:notify('notification.currency.set', { value = amount, currency = currency_data.name })
  end

  self:notify_staff('command.setmoney.message', {
    player = get_player_name(player),
    target = util.player_list_to_string(targets),
    value = amount,
    currency = currency_data.name
  })
end

COMMAND:register()
