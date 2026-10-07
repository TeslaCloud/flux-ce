--- Sends all stored areas to the player who has just initialized.
-- @param actor [Player]
function Area:PlayerInitialized(actor)
  Cable.send(actor, 'fl_areas_load', Areas.all())
end

--- Loads the saved areas from the plugin data storage.
function Area:LoadData()
  local loaded = Data.load_plugin('areas', {})

  Areas.set_stored(loaded)
end

--- Saves all stored areas to the plugin data storage.
function Area:SaveData()
  Data.save_plugin('areas', Areas.all())
end

--- Checks every player who has moved against every area polygon. Runs the area type's
-- callback and notifies the player's client whenever a player enters or leaves an area.
function Area:OneSecond()
  local cur_time = CurTime()

  for k, v in pairs(Areas.all()) do
    if istable(v.polys) and isstring(v.type) then
      for k2, v2 in ipairs(v.polys) do
        for plyID, actor in ipairs(player.all()) do
          local pos = actor:GetPos()

          actor.last_area = actor.last_area or {}
          actor.last_area[v.id] = actor.last_area[v.id] or {}

          -- The player hasn't moved since our previous check, no need to check again.
          if pos == actor.last_pos then continue end

          local z = pos.z + 16 -- Raise the player's position by 16 units to compensate for the player's height
          local entered_area = false

          -- First do height checks
          if z > v2[1].z and z < v.maxh then
            if util.vector_in_poly(pos, v2) then
              -- The player entered the area
              if !table.HasValue(actor.last_area[v.id], k2) then
                try( Areas.get_callback(v.type), actor, v, true, pos, cur_time)

                Cable.send(actor, 'fl_player_entered_area', k, pos)

                table.insert(actor.last_area[v.id], k2)
              end

              entered_area = true
            end
          end

          if !entered_area then
            -- The player left the area
            if table.HasValue(actor.last_area[v.id], k2) then
              try(Areas.get_callback(v.type), actor, v, false, pos, cur_time)

              Cable.send(actor, 'fl_player_left_area', k, pos)

              table.RemoveByValue(actor.last_area[v.id], k2)
            end
          end
        end
      end
    end
  end
end
