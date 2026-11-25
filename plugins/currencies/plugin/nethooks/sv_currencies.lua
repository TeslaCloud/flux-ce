--- Server-side receivers of the Currencies plugin: the requests of the money panel to give,
-- drop and take money, and to be sent the balances of another player. Money can only be
-- taken from, and the balances of a player only be seen of, an entity that has an inventory
-- open for the player who asks: a container, or another player whose inventories are being
-- viewed.

local IsValid = IsValid
local CurTime = CurTime
local cable_send = Cable.send

local give_interval = 0.5

Cable.receive('fl_currency_give', function(actor, amount, currency, target)
  local cur_time = CurTime()

  if actor.next_money_give and actor.next_money_give > cur_time then
    actor:notify('error.wait')

    return
  end

  actor.next_money_give = cur_time + give_interval

  local success, err = actor:give_money_to(target, currency, amount)

  if success == false and err then
    actor:notify(err)
  end

  cable_send(actor, 'fl_rebuild_currency_panel')
end)

Cable.receive('fl_currency_drop', function(actor, amount, currency)
  local success, err = actor:drop_money(currency, amount)

  if success == false and err then
    actor:notify(err)
  end

  cable_send(actor, 'fl_rebuild_currency_panel')
end)

Cable.receive('fl_currency_take', function(actor, entity, amount, currency)
  if !isentity(entity) or !IsValid(entity) or entity == actor then return end

  local inventory = Currencies:find_open_inventory(actor, entity)

  if !inventory then return end

  local success, err = entity:give_money_to(actor, currency, amount)

  if success == false and err then
    actor:notify(err)
  end

  cable_send(inventory.receivers, 'fl_rebuild_currency_panel')
end)

Cable.receive('fl_currency_watch', function(actor, target)
  if !isentity(target) or !IsValid(target) or !target:IsPlayer() or target == actor then return end
  if !Currencies:find_open_inventory(actor, target) then return end

  Currencies:update_balance_recipients(target)
end)
