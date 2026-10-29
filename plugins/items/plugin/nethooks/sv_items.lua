--- Server-side receivers of the Items plugin for item instances: the requests of clients for
-- the data of an item entity they see, at most 64 a second for each player and one a second
-- for each entity, and the client's report that its player has looked away from the item
-- they are picking up.

local IsValid = IsValid
local request_limit = 64
local request_cooldown = 1

Cable.receive('fl_items_abort_hold_start', function(actor)
  local ent = actor:get_nv('hold_entity')

  if IsValid(ent) then
    ent:set_nv('last_activator', false)
  end

  actor:set_nv('hold_start', false)
  actor:set_nv('hold_entity', false)
end)

Cable.receive('fl_items_data_request', function(actor, ent_index)
  if !isnumber(ent_index) or ent_index < 1 or ent_index >= 8192 or ent_index % 1 != 0 then return end

  local cur_time = CurTime()

  if (actor.item_requests_reset or 0) <= cur_time then
    actor.item_requests_reset = cur_time + 1
    actor.item_requests = 0
  end

  actor.item_requests += 1

  if actor.item_requests > request_limit then return end

  local requested = actor.requested_item_entities or {}

  actor.requested_item_entities = requested

  if (requested[ent_index] or 0) > cur_time then return end

  requested[ent_index] = cur_time + request_cooldown

  local ent = Entity(ent_index)

  if !IsValid(ent) or ent:GetClass() != 'fl_item' or !ent.item then return end
  if !actor:TestPVS(ent) then return end

  local receivers = ent.item.receivers

  if receivers and receivers[actor] then
    Item.network_entity_data(actor, ent)
  else
    Item.send_entity(actor, ent)
  end
end)

Cable.receive('fl_items_menu_action', function(actor, instance_id, action, ...)
  local item_obj = Item.find_instance_by_id(instance_id)

  if !item_obj or !item_obj:has_menu_action(action) then return end

  item_obj:do_menu_action(action, actor, ...)
end)
