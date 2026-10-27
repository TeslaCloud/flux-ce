--- Server side of the Areas API plugin: saves and loads the areas, sends them to players,
-- and checks every second which players have entered or left an area.

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

--- Checks every player who has moved since the previous check against every area polygon.
-- Runs the area type's callback and notifies the player's client whenever a player enters or
-- leaves an area.
function Area:OneSecond()
  local cur_time = CurTime()
  local all_areas = Areas.all()

  for _, actor in player.Iterator() do
    local pos = actor:GetPos()

    if pos == actor.last_area_pos then continue end

    actor.last_area_pos = pos

    local last_area = actor.last_area or {}
    local z = pos.z + 16

    actor.last_area = last_area

    for id, area in pairs(all_areas) do
      if istable(area.polys) and isstring(area.type) then
        local area_id = area.id
        local max_height = area.maxh
        local visited = last_area[area_id] or {}

        last_area[area_id] = visited

        for poly_index, poly in ipairs(area.polys) do
          local first_vertex = poly[1]
          local entered_area = first_vertex != nil and z > first_vertex.z and z < max_height
            and util.vector_in_poly(pos, poly)

          if entered_area then
            if !table.HasValue(visited, poly_index) then
              try(Areas.get_callback(area.type), actor, area, true, pos, cur_time)

              Cable.send(actor, 'fl_player_entered_area', id, pos)

              visited[#visited + 1] = poly_index
            end
          elseif table.HasValue(visited, poly_index) then
            try(Areas.get_callback(area.type), actor, area, false, pos, cur_time)

            Cable.send(actor, 'fl_player_left_area', id, pos)

            table.RemoveByValue(visited, poly_index)
          end
        end
      end
    end
  end
end
