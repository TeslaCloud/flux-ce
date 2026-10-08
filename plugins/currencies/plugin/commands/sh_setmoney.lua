--- Staff command that sets how much of a currency one or more players have.

CMD.name = 'SetMoney'
CMD.description = 'command.setmoney.description'
CMD.syntax = 'command.setmoney.syntax'
CMD.permission = 'moderator'
CMD.category = 'permission.categories.character_management'
CMD.arguments = 2
CMD.player_arg = 1
CMD.aliases = { 'setcash', 'settokens' }

--- Returns the translated command description with every registered currency ID listed.
-- @return [String]
function CMD:get_description()
  local currencies = {}

  for k, v in pairs(Currencies:all()) do
    table.insert(currencies, k)
  end

  return t(self.description, { currencies = table.concat(currencies, ', ') })
end

--- Sets the balance of a currency for every target and notifies the targets and staff.
-- @param actor [Player the player who ran the command]
-- @param targets [List<Player> players matched by the first command argument]
-- @param amount [String new balance, parsed with tonumber; negative values become 0]
-- @param currency=nil [String currency ID; the default_currency config is used when it is
--   omitted or unknown]
function CMD:on_run(actor, targets, amount, currency)
  amount = tonumber(amount)

  if !amount then
    actor:notify('error.invalid_value')

    return
  end

  amount = math.max(0, amount)
  currency = currency or Config.get('default_currency')

  if !Currencies:find_currency(currency) then
    currency = Config.get('default_currency')

    if !Currencies:find_currency(currency) then
      actor:notify('error.currency.invalid_currency')

      return
    end
  end

  local currency_data = Currencies:find_currency(currency)

  for k, v in ipairs(targets) do
    v:set_money(currency, amount)
    v:notify('notification.currency.set', { value = amount, currency = currency_data.name })
  end

  self:notify_staff('command.setmoney.message', {
    player = get_player_name(actor),
    target = util.player_list_to_string(targets),
    value = amount,
    currency = currency_data.name
  })
end
