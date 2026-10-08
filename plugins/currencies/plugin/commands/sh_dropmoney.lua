--- Command that drops an amount of the player's money in front of them.

CMD.name = 'DropMoney'
CMD.description = 'command.dropmoney.description'
CMD.syntax = 'command.dropmoney.syntax'
CMD.category = 'permission.categories.general'
CMD.arguments = 1
CMD.aliases = { 'dropcash', 'droptokens' }

--- Returns the translated command description with the available currency IDs listed.
-- @return [String]
function CMD:get_description()
  local currencies = {}

  for k, v in pairs(Currencies:all()) do
    if !v.hidden or PLAYER:get_money(k) > 0 then
      table.insert(currencies, k)
    end
  end

  return t(self.description, { currencies = table.concat(currencies, ', ') })
end

--- Drops money in front of the player, or hands it to the player they are looking at.
-- @param actor [Player the player who ran the command]
-- @param amount [String amount to drop, parsed with tonumber]
-- @param currency=nil [String currency ID; the default_currency config is used when it is
--   omitted or unknown]
function CMD:on_run(actor, amount, currency)
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

  local success, err = actor:drop_money(currency, amount)

  if success == false then
    actor:notify(err)
  end
end
