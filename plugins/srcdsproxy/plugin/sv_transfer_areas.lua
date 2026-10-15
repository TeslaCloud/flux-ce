--- Server side of the server transfer areas. A player who is connected through the proxy and
-- enters a transfer area for another server than the one they are on gets a countdown of the
-- area's delay, which their client shows on the HUD. When it ends and they are still alive
-- and in the area, they are moved to the area's server with `srcdsproxy.Transfer`; if they
-- are dead or outside of it by then, nothing happens.
--
-- A player who may not enter that server, because it is whitelist-only and they are neither
-- on its whitelist nor a proxy admin, is told so once and not moved. With an addon that has
-- no `srcdsproxy.MayEnter`, every player is sent and the proxy decides.
--
-- Eight times a second the server checks the positions of the players against the transfer
-- areas itself: a player is in an area while their position is inside of one of its
-- polygons, the way the Areas API tells. That is how leaving an area is noticed, which
-- cancels its countdown, and how entering one is noticed when the Areas API has not reported
-- it yet; the Areas API's enter callback starts a countdown as well, whichever comes first.
--
-- Each entry gets one attempt: while the player stays in the area nothing is tried again,
-- also when the proxy has refused the move, for example because the server is down; leaving
-- and entering again starts anew. A player has one countdown at a time. A transfer area they
-- are in while another countdown runs waits for it: once that countdown has been cancelled or
-- has ended, the next transfer area the player is in and has not been dealt with in starts.

--- The transfer state of each player who has entered a transfer area, keyed by player:
-- `countdown` (Map with the `area_id`, the `end_time` in CurTime and whether it is `shown` on
-- the HUD, nil when none runs), `moving` (ID of the area whose move has been sent while the
-- HUD still shows it, nil otherwise) and `handled` (Map of the IDs of the areas the player has
-- been dealt with in, set while they stay in them).
local states = SrcdsProxy.transfer_states or {}

SrcdsProxy.transfer_states = states

--- Returns the transfer state of a player, creating it if needed.
-- @param actor [Player]
-- @return [Map]
local function get_state(actor)
  local state = states[actor]

  if !state then
    state = { handled = {} }
    states[actor] = state
  end

  return state
end

--- Checks whether a position is inside of one of the polygons of an area, the way the Areas
-- API checks the position of a player.
-- @param pos [Vector position of the player]
-- @param area [Map the area]
-- @return [Boolean]
local function position_in_area(pos, area)
  if !istable(area.polys) then return false end

  local z = pos.z + 16

  for _, poly in ipairs(area.polys) do
    if z > poly[1].z and z < area.maxh and util.vector_in_poly(pos, poly) then
      return true
    end
  end

  return false
end

--- Checks whether a player is on the named server of the network already. Server names are
-- compared without regard to case, as the proxy does.
-- @param actor [Player a player who is connected through the proxy]
-- @param backend [String server name]
-- @return [Boolean]
function SrcdsProxy:is_current_backend(actor, backend)
  return string.lower(srcdsproxy.BackendName(actor) or '') == string.lower(backend)
end

--- Checks whether a player may enter a server of the network on their own request: it is not
-- whitelist-only, or they are on its whitelist or a proxy admin. The proxy still decides when
-- the player is sent, and it does not know here whether the server exists or is up. With an
-- addon that has no `srcdsproxy.MayEnter`, every player who is connected through the proxy
-- may try.
-- @param actor [Player]
-- @param backend [String server name]
-- @return [Boolean]
function SrcdsProxy:may_enter(actor, backend)
  if isfunction(srcdsproxy.MayEnter) then
    return srcdsproxy.MayEnter(actor, backend) == true
  end

  return srcdsproxy.IsProxied(actor)
end

--- Takes the countdown or the pending move off the HUD of a player, if it is shown there.
-- @param actor [Player]
-- @param state [Map the transfer state of the player]
local function clear_hud(actor, state)
  local countdown = state.countdown

  if (countdown and countdown.shown) or state.moving then
    Cable.send(actor, 'fl_proxy_area_cancel')
  end

  state.moving = nil
end

--- Stops the countdown of a player, if one runs, and takes it off their HUD.
-- @param actor [Player]
-- @param state [Map the transfer state of the player]
function SrcdsProxy:cancel_transfer_countdown(actor, state)
  if !state.countdown then return end

  clear_hud(actor, state)

  state.countdown = nil
end

--- Deals with a player who has entered a transfer area. Nothing happens when the addon is
-- missing, the player is not connected through the proxy or is dead, the area names no
-- server, the player has been dealt with in this area since they entered it, or another
-- countdown of theirs runs. A player who is on the area's server already is left alone, one
-- who may not enter it is told that it is whitelist-only, and everyone else gets a countdown
-- of the area's delay, which they are told about.
-- @param actor [Player the player who has entered the area]
-- @param area [Map the transfer area]
function SrcdsProxy:enter_transfer_area(actor, area)
  if !self:available() or !IsValid(actor) or !srcdsproxy.IsProxied(actor) or !actor:Alive() then return end

  local backend = self:server_name(area.backend)

  if !backend then return end

  local state = get_state(actor)

  if state.handled[area.id] or state.countdown then return end

  state.handled[area.id] = true

  if self:is_current_backend(actor, backend) then return end

  if !self:may_enter(actor, backend) then
    actor:notify('error.proxy.area_whitelist', { server = backend })

    return
  end

  local delay = self:transfer_delay(area.delay)
  local end_time = CurTime() + delay

  state.moving = nil
  state.countdown = { area_id = area.id, end_time = end_time, shown = delay > 0 }

  if delay > 0 then
    actor:notify('notification.proxy.area_countdown', { server = backend, time = Flux.Lang:duration(delay) })

    Cable.send(actor, 'fl_proxy_area_countdown', backend, end_time)
  end
end

--- Moves a player whose countdown has ended to the server of the transfer area, unless the
-- area names no server any more, the player is not connected through the proxy or is on that
-- server already, may not enter it (they are told it is whitelist-only), or a plugin vetoes
-- the move.
-- @param actor [Player the player whose countdown has ended]
-- @param area [Map the transfer area]
-- @return [Boolean whether the player has been sent to the proxy]
function SrcdsProxy:transfer_from_area(actor, area)
  local backend = self:server_name(area.backend)

  if !backend or !srcdsproxy.IsProxied(actor) or self:is_current_backend(actor, backend) then
    return false
  end

  if !self:may_enter(actor, backend) then
    actor:notify('error.proxy.area_whitelist', { server = backend })

    return false
  end

  --- Called on the server when the countdown of a player in a server transfer area has ended,
  -- right before they are moved to the area's server. The player is in the area, alive and
  -- may enter that server as far as the proxy has told this server. Whatever is returned, the
  -- player is not moved again until they leave the area and enter it anew.
  -- @param actor [Player The player who is about to be moved]
  -- @param area [Map The transfer area, with the `backend` and `delay` fields]
  -- @param backend [String Name of the server the player is about to be moved to]
  -- @return [Boolean Return false to keep the player from being moved]
  if hook.Run('ProxyAreaShouldTransfer', actor, area, backend) == false then
    return false
  end

  actor:notify('notification.proxy.area_moving', { server = backend })

  return srcdsproxy.Transfer(actor, backend, 'area '..tostring(area.id))
end

--- Ends the countdown of a player: moves them if they are alive, which the caller has
-- checked them to be in the area too. A move that has been sent stays on the HUD while the
-- player is in the area; otherwise the countdown is taken off it.
-- @param actor [Player]
-- @param state [Map the transfer state of the player]
-- @param area [Map the transfer area of the countdown]
function SrcdsProxy:finish_transfer_countdown(actor, state, area)
  local countdown = state.countdown

  if actor:Alive() and self:transfer_from_area(actor, area) then
    state.countdown = nil
    state.moving = countdown.shown and area.id or nil

    return
  end

  self:cancel_transfer_countdown(actor, state)
end

--- Brings the transfer state of a player up to date by their position: forgets the areas
-- they are not in any more or that have been removed, cancels a countdown whose area they
-- have left, and ends a countdown whose time has come, which moves them when they are alive.
-- @param actor [Player]
-- @param state [Map the transfer state of the player]
-- @param stored [Map every area, keyed by area ID]
-- @param cur_time [Number current CurTime()]
function SrcdsProxy:update_transfer_state(actor, state, stored, cur_time)
  local handled = state.handled
  local pos = actor:GetPos()

  for area_id in pairs(handled) do
    local area = stored[area_id]

    if !area or !position_in_area(pos, area) then
      handled[area_id] = nil
    end
  end

  if state.moving and !handled[state.moving] then
    clear_hud(actor, state)
  end

  local countdown = state.countdown

  if countdown then
    if !handled[countdown.area_id] then
      self:cancel_transfer_countdown(actor, state)
    elseif cur_time >= countdown.end_time then
      self:finish_transfer_countdown(actor, state, stored[countdown.area_id])
    end
  end

  if !state.countdown and !state.moving and next(handled) == nil then
    states[actor] = nil
  end
end

--- Starts the transfer area a player is in, when no countdown of theirs runs: the first one
-- they have not been dealt with in since they entered it.
-- @param actor [Player]
-- @param areas [List<Map> the transfer areas]
function SrcdsProxy:enter_transfer_areas_at(actor, areas)
  if !srcdsproxy.IsProxied(actor) or !actor:Alive() then return end

  local state = states[actor]

  if state and state.countdown then return end

  local pos = actor:GetPos()

  for _, area in ipairs(areas) do
    local handled = state and state.handled[area.id]

    if !handled and position_in_area(pos, area) then
      self:enter_transfer_area(actor, area)

      state = states[actor]

      if state and state.countdown then return end
    end
  end
end

--- Updates the transfer states of the players eight times a second: cancels the countdowns
-- of the players who have left their area, ends those whose time has come, and starts the
-- transfer areas that players are in and have not been dealt with in.
function SrcdsProxy:LazyTick()
  if !self:available() then return end

  local stored = Areas.all()
  local cur_time = CurTime()

  for actor, state in pairs(states) do
    if IsValid(actor) then
      self:update_transfer_state(actor, state, stored, cur_time)
    else
      states[actor] = nil
    end
  end

  local areas = Areas.get_by_type(self.transfer_area_type)

  if #areas == 0 then return end

  for _, actor in player.Iterator() do
    self:enter_transfer_areas_at(actor, areas)
  end
end

--- Forgets the transfer state of a player who leaves the server.
-- @param actor [Player]
function SrcdsProxy:PlayerDisconnected(actor)
  states[actor] = nil
end
