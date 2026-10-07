--- Loads the saved items once the map entities have been created.
function Items:InitPostEntity()
  Item.load()
end

--- Runs the 'PlayerThrewGrenade' hook on the next tick after a frag grenade is created.
-- @param entity [Entity]
function Items:OnEntityCreated(entity)
  if IsValid(entity) and entity:GetClass() == 'npc_grenade_frag' then
    timer.Simple(0, function()
      if IsValid(entity) then
        local owner = entity:GetOwner()

        hook.Run('PlayerThrewGrenade', owner, entity)
      end
    end)
  end
end

--- Saves the item instances and the item entities.
function Items:SaveData()
  Item.save_all()
end

--- Sends the items lying in the world to the player that has finished loading.
-- @param actor [Player]
function Items:ClientIncludedSchema(actor)
  Item.send_to_player(actor)
end

--- Tells the client of the player to open the menu of the item entity they have used.
-- @param activator [Player]
-- @param entity [Entity the fl_item entity]
-- @param item_obj [Item]
function Items:PlayerUseItemEntity(activator, entity, item_obj)
  Cable.send(activator, 'fl_player_use_item_entity', entity)
end

--- Prevents menu actions on items that the player does not have, and on items in the world
-- that are too far away from the player, obstructed or not being looked at.
-- @param actor [Player]
-- @param item_obj [Item]
-- @param action [String name of the menu action]
-- @param ... [Vararg extra arguments of the action]
-- @return [Boolean false to prevent the action, nil otherwise]
function Items:PlayerCanUseItem(actor, item_obj, action, ...)
  local item_entity = item_obj.entity

  if IsValid(item_entity) then
    local player_pos = actor:EyePos()
    local entity_pos = item_entity:GetPos()

    if player_pos:Distance(entity_pos) > 100 then
      return false
    end

    if util.vector_obstructed(player_pos, entity_pos, { item_entity, actor }) then
      return false
    end

    local entity_vector = entity_pos - actor:GetShootPos()

    if (actor:GetAimVector():Dot(entity_vector) / entity_vector:Length()) < math.pi / 8 then
      return false
    end
  else
    if !actor:has_item_by_id(item_obj.instance_id) then
      return false
    end
  end
end

--- Sends an item that is lying in the world to all clients again
-- after a menu action has been performed on it.
-- @param actor [Player]
-- @param item_obj [Item]
-- @param act [String name of the menu action]
-- @param ... [Vararg extra arguments of the action]
function Items:PlayerUsedItem(actor, item_obj, act, ...)
  if IsValid(item_obj.entity) then
    Item.network_item(nil, item_obj.instance_id)
    Item.network_entity_data(nil, item_obj.entity)
  end
end

--- Lets the on_drop callback of the item decide whether the player is able to drop it.
-- @param actor [Player]
-- @param item_obj [Item]
-- @return [Boolean false to prevent the drop, nil otherwise]
function Items:CanPlayerDropItem(actor, item_obj)
  if istable(item_obj) and item_obj.on_drop then
    if item_obj:on_drop(actor) == false then
      return false
    end
  end
end

--- Calls the on_loadout callback of every item that the player has,
-- on the next tick after they spawn with their character loaded.
-- @param actor [Player]
function Items:PostPlayerSpawn(actor)
  if actor:is_character_loaded() then
    timer.Simple(0, function()
      for k, v in pairs(actor:get_items()) do
        if v.on_loadout then
          v:on_loadout(actor)
        end
      end
    end)
  end
end

--- Calls the on_save callback of every item that the player has before their character is saved.
-- @param owner [Player]
-- @param index [Character the character that is being saved]
function Items:PreSaveCharacter(owner, index)
  for k, v in pairs(owner:get_items()) do
    if v.on_save then
      v:on_save(owner)
    end
  end
end

--- Calls the on_created callback of an item instance that has just been created.
-- @param item_obj [Item]
function Items:OnItemCreated(item_obj)
  if item_obj.on_created then
    item_obj:on_created()
  end
end

Cable.receive('fl_items_abort_hold_start', function(actor)
  local ent = actor:get_nv('hold_entity')

  if IsValid(ent) then
    ent:set_nv('last_activator', false)
  end

  actor:set_nv('hold_start', false)
  actor:set_nv('hold_entity', false)
end)
