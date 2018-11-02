function Area:PlayerInitialized(player)
  cable.send(player, 'fl_areas_load', areas.get_all())
end

function Area:LoadData()
  local loaded = data.load_plugin('areas', {})

  areas.set_stored(loaded)
end

function Area:SaveData()
  data.save_plugin('areas', areas.get_all())
end

function Area:OneSecond()
  local cur_time = CurTime()

  for k, v in pairs(areas.get_all()) do
    if istable(v.polys) and isstring(v.type) then
      for k2, v2 in ipairs(v.polys) do
        for plyID, player in ipairs(_player.GetAll()) do
          local pos = player:GetPos()

          player.last_area = player.last_area or {}
          player.last_area[v.id] = player.last_area[v.id] or {}

          -- Player hasn't moved since our previous check, no need to check again.
          if pos == player.last_pos then continue end

          local z = pos.z + 16 -- Raise player's position by 16 units to compensate for player's height
          local entered_area = false

          -- First do height checks
          if z > v2[1].z and z < v.maxh then
            if util.vector_in_poly(pos, v2) then
              -- Player entered the area
              if !table.HasValue(player.last_area[v.id], k2) then
                Try('Areas', areas.get_callback(v.type), player, v, true, pos, cur_time)

                cable.send(player, 'fl_player_entered_area', k, pos)

                table.insert(player.last_area[v.id], k2)
              end

              entered_area = true
            end
          end

          if !entered_area then
            -- Player left the area
            if table.HasValue(player.last_area[v.id], k2) then
              Try('Areas', areas.get_callback(v.type), player, v, false, pos, cur_time)

              cable.send(player, 'fl_player_left_area', k, pos)

              table.RemoveByValue(player.last_area[v.id], k2)
            end
          end
        end
      end
    end
  end
end
