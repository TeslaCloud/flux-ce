--- Server-side receivers of the Currencies plugin: the requests of the money panel to give,
-- drop and take money. Money can only be taken from an entity that has an inventory open for
-- the player who asks: a container, or another player whose inventories are being viewed.

local IsValid = IsValid
local pairs = pairs
local cable_send = Cable.send

--- Finds an inventory of an entity that is open for a player, which is what entitles the
-- player to take the money of that entity.
-- @param actor [Player the player who wants the money]
-- @param entity [Entity the container or the player that holds the money]
-- @return [Inventory the open inventory, or nil if the entity has none open for the player]
local function find_open_inventory(actor, entity)
  if entity:IsPlayer() then
    for _, inventory in pairs(entity:get_inventories()) do
      if inventory:has_receiver(actor) then
        return inventory
      end
    end
  elseif entity.inventory and entity.inventory:has_receiver(actor) then
    return entity.inventory
  end
end

Cable.receive('fl_currency_give', function(actor, amount, currency, target)
  local success, err = actor:give_money_to(target, currency, amount)

  if success == false then
    actor:notify(err)
  end

  cable_send(actor, 'fl_rebuild_currency_panel')
end)

Cable.receive('fl_currency_drop', function(actor, amount, currency)
  local success, err = actor:drop_money(currency, amount)

  if success == false then
    actor:notify(err)
  end

  cable_send(actor, 'fl_rebuild_currency_panel')
end)

Cable.receive('fl_currency_take', function(actor, entity, amount, currency)
  if !IsValid(entity) or entity == actor then return end

  local inventory = find_open_inventory(actor, entity)

  if !inventory then return end

  local success, err = entity:give_money_to(actor, currency, amount)

  if success == false then
    actor:notify(err)
  end

  cable_send(inventory.receivers, 'fl_rebuild_currency_panel')
end)
