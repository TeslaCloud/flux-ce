--- Server side of the Areas library: saves the areas and keeps track of the areas each player
-- is in. A player is inside of an area or not; the callback of the area's type runs, and the
-- player's client is told, only when that changes.

--- Saves all stored areas to the plugin data storage.
function Areas.save()
  Data.save_plugin('areas', Areas.all())
end

--- Sets whether a player is inside of an area. When that changes, runs the callback of the
-- area's type and tells the player's client.
-- @param actor [Player]
-- @param id [String id the area is stored under]
-- @param area [Map the area]
-- @param inside [Boolean whether the player is inside of the area]
-- @param pos [Vector position of the player]
-- @param cur_time [Number CurTime() of the check]
function Areas.set_inside(actor, id, area, inside, pos, cur_time)
  local inside_areas = actor.fl_areas_inside

  if !inside_areas then
    inside_areas = {}
    actor.fl_areas_inside = inside_areas
  end

  if (inside_areas[id] == true) == inside then return end

  inside_areas[id] = inside or nil

  try(Areas.get_callback(area.type), actor, area, inside, pos, cur_time)

  Cable.send(actor, inside ? 'fl_player_entered_area' : 'fl_player_left_area', id, pos)
end

--- Checks a player against every area and runs the enter and leave callbacks of the areas
-- the player has entered or left. A player who has not moved since the previous check is
-- skipped unless an area has been registered since.
-- @param actor [Player]
-- @param cur_time [Number CurTime() of the check]
function Areas.update_player(actor, cur_time)
  local pos = actor:GetPos()
  local revision = Areas.get_count()

  if pos == actor.fl_area_pos and actor.fl_area_revision == revision then return end

  actor.fl_area_pos = pos
  actor.fl_area_revision = revision

  for id, area in pairs(Areas.all()) do
    if istable(area) and isstring(area.type) then
      Areas.set_inside(actor, id, area, Areas.contains(area, pos), pos, cur_time)
    end
  end
end

--- Makes every player who is inside of an area leave it.
-- @param id [String id the area is stored under]
-- @param area [Map the area]
function Areas.leave_area(id, area)
  local cur_time = CurTime()

  for _, actor in player.Iterator() do
    local inside_areas = actor.fl_areas_inside

    if inside_areas and inside_areas[id] then
      Areas.set_inside(actor, id, area, false, actor:GetPos(), cur_time)
    end
  end
end

--- Makes a player leave every area they are inside of.
-- @param actor [Player]
function Areas.leave_all(actor)
  local inside_areas = actor.fl_areas_inside

  if !inside_areas then return end

  local all_areas = Areas.all()
  local pos = actor:GetPos()
  local cur_time = CurTime()

  for id in pairs(inside_areas) do
    local area = all_areas[id]

    if istable(area) then
      Areas.set_inside(actor, id, area, false, pos, cur_time)
    else
      inside_areas[id] = nil
    end
  end
end
