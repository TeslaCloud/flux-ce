function flAreas:OneSecond()
  local cur_time = CurTime()

  for k, v in pairs(areas.GetAll()) do
    if istable(v.polys) and isstring(v.type) then
      for k2, v2 in ipairs(v.polys) do
        for plyID, player in ipairs(_player.GetAll()) do
          local pos = player:GetPos()

          player.lastArea = player.lastArea or {}
          player.lastArea[v.id] = player.lastArea[v.id] or {}

          -- Player hasn't moved since our previous check, no need to check again.
          if pos == player.last_pos then continue end

          local z = pos.z + 16 -- Raise player's position by 16 units to compensate for player's height
          local enteredArea = false

          -- First do height checks
          if z > v2[1].z and z < v.maxH then
            if util.vector_in_poly(pos, v2) then
              -- Player entered the area
              if !table.HasValue(player.lastArea[v.id], k2) then
                Try('Areas', areas.GetCallback(v.type), player, v, true, pos, cur_time)

                netstream.Start(player, 'PlayerEnteredArea', k, pos)

                table.insert(player.lastArea[v.id], k2)
              end

              enteredArea = true
            end
          end

          if !enteredArea then
            -- Player left the area
            if table.HasValue(player.lastArea[v.id], k2) then
              Try('Areas', areas.GetCallback(v.type), player, v, false, pos, cur_time)

              netstream.Start(player, 'PlayerLeftArea', k, pos)

              table.RemoveByValue(player.lastArea[v.id], k2)
            end
          end
        end
      end
    end
  end
end

function flAreas:PlayerInitialized(player)
  netstream.Start(player, 'flLoadAreas', areas.GetAll())
end

function flAreas:LoadData()
  local loaded = data.LoadPlugin('areas', {})

  areas.SetStored(loaded)
end

function flAreas:SaveData()
  data.SavePlugin('areas', areas.GetAll())
end
