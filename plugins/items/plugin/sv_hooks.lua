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

function Items:PlayerUseItemEntity(player, entity, item_table)
  Cable.send(player, 'fl_player_use_item_entity', entity)
end

function Items:PlayerCanUseItem(player, item_table, action, ...)
  local item_entity = item_table.entity

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
    if !player:has_item_by_id(item_table.instance_id) then
      return false
    end
  end
end

function Items:CanPlayerDropItem(player, item_table)
  if istable(item_table) and item_table.on_drop then
    if item_table:on_drop(player) == false then
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

function Items:OnItemCreated(item_table)
  if item_table.on_created then
    item_table:on_created()
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
