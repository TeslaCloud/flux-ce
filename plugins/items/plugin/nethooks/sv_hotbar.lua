--- Server-side receivers of the Items plugin for the hotbar: the requests of the hotbar panel
-- to put an item of the storage of the player on a slot, to move an entry to another slot and
-- to take an entry off, and the pin option of the item menu. A player's requests are taken at
-- most once every tenth of a second, only while they are alive and not lying on the ground as
-- a ragdoll, and are carried out by the checked functions of the Hotbar library, which tell
-- why a request is refused; the player is notified of it.

const request_delay = 0.1

--- Checks whether a player may change their hotbar again, and makes them wait before the next
-- request if they may.
-- @param actor [Player]
-- @return [Boolean false if the player has asked too recently or may not handle items now]
local function take_turn(actor)
  if !IsValid(actor) or !actor:can_handle_items() then return false end

  local cur_time = CurTime()

  if (actor.fl_next_hotbar_request or 0) > cur_time then return false end

  actor.fl_next_hotbar_request = cur_time + request_delay

  return true
end

--- Notifies a player of the reason why their request has been refused, if there is one.
-- @param actor [Player]
-- @param changed [Boolean whether the hotbar has changed]
-- @param error_text [String error phrase]
-- @param arguments [Map arguments of the phrase]
local function answer(actor, changed, error_text, arguments)
  if !changed and isstring(error_text) then
    actor:notify(error_text, arguments)
  end
end

Cable.receive('fl_hotbar_place', function(actor, slot, instance_id)
  if !isnumber(slot) or !isnumber(instance_id) or !take_turn(actor) then return end

  answer(actor, Hotbar.place(actor, slot, Item.find_instance_by_id(instance_id)))
end)

Cable.receive('fl_hotbar_move', function(actor, from, to)
  if !isnumber(from) or !isnumber(to) or !take_turn(actor) then return end

  Hotbar.move(actor, from, to)
end)

Cable.receive('fl_hotbar_clear', function(actor, slot)
  if !isnumber(slot) or !take_turn(actor) then return end

  answer(actor, Hotbar.clear(actor, slot))
end)

Cable.receive('fl_hotbar_pin', function(actor, instance_id)
  if !isnumber(instance_id) or !take_turn(actor) then return end

  local item_obj = Item.find_instance_by_id(instance_id)

  if !item_obj or !Hotbar.is_in_storage(actor, item_obj) then return end

  answer(actor, Hotbar.toggle_pin(actor, item_obj))
end)
