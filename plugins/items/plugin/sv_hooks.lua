function Items:InitPostEntity()
  Item.load()
end

function Items:OnEntityCreated(entity)
  if IsValid(entity) and entity:GetClass() == 'npc_grenade_frag' then
    timer.simple(0, function()
      if IsValid(entity) then
        local player = entity:GetOwner()

        hook.run('PlayerThrewGrenade', player, entity)
      end
    end)
  end
end

function Items:SaveData()
  Item.save_all()
end

function Items:ClientIncludedSchema(player)
  Item.send_to_player(player)
end

function Items:PlayerUseItemEntity(player, entity, item_obj)
  Cable.send(player, 'fl_player_use_item_entity', entity)
end

function Items:PlayerCanUseItem(player, item_obj, action, ...)
  local item_entity = item_obj.entity

  if IsValid(item_entity) then
    local player_pos = player:EyePos()
    local entity_pos = item_entity:GetPos()

    if player_pos:Distance(entity_pos) > 100 then
      return false
    end

    if util.vector_obstructed(player_pos, entity_pos, { item_entity, player }) then
      return false
    end

    local entity_vector = entity_pos - player:GetShootPos()

    if (player:GetAimVector():Dot(entity_vector) / entity_vector:Length()) < math.pi / 8 then
      return false
    end
  else
    if !player:has_item_by_id(item_obj.instance_id) then
      return false
    end
  end
end

function Items:PlayerUsedItem(player, item_obj, act, ...)
  if IsValid(item_obj.entity) then
    Item.network_item(nil, item_obj.instance_id)
    Item.network_entity_data(nil, item_obj.entity)
  end
end

function Items:CanPlayerDropItem(player, item_obj)
  if istable(item_obj) and item_obj.on_drop then
    if item_obj:on_drop(player) == false then
      return false
    end
  end
end

function Items:PostPlayerSpawn(player)
  if player:is_character_loaded() then
    timer.Simple(0, function()
      for k, v in pairs(player:get_items()) do
        if v.on_loadout then
          v:on_loadout(player)
        end
      end
    end)
  end
end

function Items:PreSaveCharacter(player, index)
  for k, v in pairs(player:get_items()) do
    if v.on_save then
      v:on_save(player)
    end
  end
end

function Items:OnItemCreated(item_obj)
  if item_obj.on_created then
    item_obj:on_created()
  end
end

Cable.receive('fl_items_abort_hold_start', function(player)
  local ent = player:get_nv('hold_entity')

  if IsValid(ent) then
    ent:set_nv('last_activator', false)
  end

  player:set_nv('hold_start', false)
  player:set_nv('hold_entity', false)
end)
