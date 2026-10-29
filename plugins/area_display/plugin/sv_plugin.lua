--- Server side of the Area Display plugin: sends area notices to the clients and remembers
-- which one-time areas a player has already been shown.
-- The one-time areas a player has seen are kept in the 'seen_areas' value of the data table
-- of the player (`Player:set_player_data`), by map and area ID. What is stored for an area is
-- the time the area was created at, so an area that is removed and made anew is shown again.

local data_key = 'seen_areas'

--- Returns what is stored for a one-time area that a player has seen: the time the area was
-- created at, or true for an area that does not have one.
-- @param area [Map the area]
-- @return [Number/Boolean]
local function get_stamp(area)
  return area.created_at or true
end

--- Shows an area notice to one player, several players or everyone. Clients that have the
-- notices turned off, or whose player cannot see them at the moment, ignore it.
-- ```
-- AreaDisplay:show(nil, 'The curfew has begun.')
-- AreaDisplay:show(target, { text = 'Sector 7', style = 'typewriter', duration = 4 })
-- ```
-- @param targets [Player/List<Player> who to show the notice to; everyone if nil. Players
--   that are not valid any more are left out]
-- @param info [String/Map text or language phrase of the notice, or a table with the fields
--   that `AreaDisplay:add` takes on the client: text, style, color and duration]
-- @return [Boolean true if the notice has been sent, false if it has no text]
-- @see [AreaDisplay:add]
function AreaDisplay:show(targets, info)
  if isstring(info) then
    info = { text = info }
  end

  if !istable(info) or !isstring(info.text) or info.text == '' then return false end

  Cable.send(targets, 'fl_area_display_show', info)

  return true
end

--- Announces a text area to one player, several players or everyone, as if they had just
-- entered it, but regardless of the cooldown and of the area being a one-time one.
-- @param targets [Player/List<Player> who to announce the area to; everyone if nil. Players
--   that are not valid any more are left out]
-- @param area [Map the text area]
-- @return [Boolean true if the request has been sent, false if the area is not valid]
function AreaDisplay:show_area(targets, area)
  if !istable(area) or area.id == nil then return false end

  Cable.send(targets, 'fl_area_display_show', nil, tostring(area.id))

  return true
end

--- Checks whether a player has already been shown a one-time area.
-- @param actor [Player]
-- @param area [Map the area]
-- @return [Boolean]
function AreaDisplay:has_seen(actor, area)
  local seen = actor:get_player_data(data_key)
  local map_seen = istable(seen) and seen[game.GetMap()]

  return istable(map_seen) and map_seen[area.id] == get_stamp(area)
end

--- Sets whether a player has already been shown a one-time area. It is kept in the data
-- table of the player, which is saved with their database record.
-- @param actor [Player]
-- @param area [Map the area]
-- @param seen=true [Boolean false to have the area shown to the player again]
function AreaDisplay:set_seen(actor, area, seen)
  local all_seen = actor:get_player_data(data_key)
  local map_name = game.GetMap()

  if !istable(all_seen) then
    all_seen = {}
  end

  local map_seen = all_seen[map_name]

  if !istable(map_seen) then
    map_seen = {}
  end

  if seen == false then
    map_seen[area.id] = nil
  else
    map_seen[area.id] = get_stamp(area)
  end

  all_seen[map_name] = next(map_seen) != nil and map_seen or nil

  actor:set_player_data(data_key, next(all_seen) != nil and all_seen or nil)
end

Cable.receive('fl_area_display_request', function(actor, area_id)
  if !actor.record then return end

  local area = AreaDisplay:find_text_area(area_id)

  if !area or !area.once or AreaDisplay:has_seen(actor, area) then return end

  AreaDisplay:set_seen(actor, area)
  AreaDisplay:show_area(actor, area)
end)
