--- Command that drops an amount of the player's money in front of them.

CMD.name = 'DropMoney'
CMD.description = 'command.dropmoney.description'
CMD.syntax = 'command.dropmoney.syntax'
CMD.category = 'permission.categories.general'
CMD.arguments = 1
CMD.arg_types = { 'number', 'currency' }
CMD.aliases = { 'dropcash', 'droptokens' }

--- Returns the translated command description with the available currency IDs listed.
-- @return [String]
function CMD:get_description()
  return t(self.description, { currencies = table.concat(Currencies:get_visible(PLAYER), ', ') })
end

--- Drops money in front of the player, or hands it to the player they are looking at.
-- @param actor [Player the player who ran the command]
-- @param amount [Number amount to drop]
-- @param currency=nil [String currency ID; the default currency is used when it is
--   omitted, see `Currencies:get_default_currency`]
function CMD:on_run(actor, amount, currency)
  currency = Currencies:resolve_currency(currency)

  if !currency then
    actor:notify('error.invalid_currency')

    return
  end

  local success, err = actor:drop_money(currency, amount)

  if success == false and err then
    actor:notify(err)
  end
end
