--- Server-side functions of the Classes plugin: the payment of wages through the Currencies
-- plugin, and the handler of the class menu's request to switch classes.

--- Pays a player the wage of their class in the currency of the default_currency config.
-- Nothing is paid when the Currencies plugin is not loaded, when the player is dead, has no
-- active character or cannot hold money, when the wage is not positive after the
-- AdjustPlayerWage hook, or when the CanPlayerEarnWage hook refuses it. The player is
-- notified of the payment. The currency ID is lower-cased, as the Currencies plugin looks
-- currencies up in lower case but keeps balances under the ID it is given.
-- @param target [Player]
-- @return [Boolean whether the wage was paid, Number the amount that was paid, String the ID
--   of the currency it was paid in]
function Classes.pay_wage(target)
  if !Currencies or !IsValid(target) or !target:Alive() then return false end
  if !target:is_character_loaded() or !target:can_contain_money() then return false end

  local wage = {
    amount = target:get_wage(),
    currency = Config.get('default_currency'),
    class_table = target:get_class()
  }

  --- Lets plugins change the wage a player is about to be paid. Called on the server for
  -- every living player with an active character each time wages are paid, before the
  -- CanPlayerEarnWage hook. Every handler may change the table, so a handler should return
  -- nothing to let the others run.
  -- @param target [Player the player who is about to be paid]
  -- @param wage [Map the wage, modified in place: amount (Number the wage of the player's
  --   class, 0 without a class), currency (String currency ID, the default_currency config)
  --   and class_table (CharacterClass the class of the player, nil if they have none)]
  hook.Run('AdjustPlayerWage', target, wage)

  local amount = tonumber(wage.amount)
  local currency = isstring(wage.currency) and wage.currency:lower()
  local currency_data = currency and Currencies:find_currency(currency)

  if !amount or amount != amount or !currency_data then return false end

  amount = math.round(amount, currency_data.decimals or 0)

  if amount <= 0 then return false end

  --- Decides whether a player is paid their wage. Called on the server after the
  -- AdjustPlayerWage hook, only when the amount is positive and the currency exists.
  -- @param target [Player the player who is about to be paid]
  -- @param amount [Number the amount, rounded to the decimals of the currency]
  -- @param currency [String currency ID]
  -- @return [Boolean return false to withhold the wage]
  if hook.Run('CanPlayerEarnWage', target, amount, currency) == false then return false end

  target:give_money(currency, amount)
  target:notify('notification.wage', { value = amount, currency = currency_data.name }, Color('lightgreen'))

  --- Called on the server after a player has been paid their wage and notified of it.
  -- @param target [Player the player who was paid]
  -- @param amount [Number the amount that was added to their balance]
  -- @param currency [String currency ID]
  hook.Run('PlayerEarnedWage', target, amount, currency)

  return true, amount, currency
end

--- Pays every connected player their wage. The plugin calls it every wages_interval
-- seconds. Does nothing when the Currencies plugin is not loaded.
-- @see [Classes.pay_wage]
function Classes.distribute_wages()
  if !Currencies then return end

  for k, v in player.Iterator() do
    Classes.pay_wage(v)
  end
end

Cable.receive('fl_class_join', function(actor, class_id)
  local success, err, err_args = actor:join_class(class_id)

  if success then
    local class_table = actor:get_class()

    actor:notify('notification.class_joined', { class = class_table.name }, class_table:get_color())
  elseif err then
    actor:notify(err, err_args)
  end
end)
