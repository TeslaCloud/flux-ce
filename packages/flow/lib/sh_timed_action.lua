--- Timed actions: things a player does that take a while, such as picking a lock, tying
-- someone up or searching a container. The server starts one with
-- `Flux.TimedAction:start` (or `Player:start_timed_action`), giving it an ID, a duration
-- and optionally a text, a cancel condition and a callback. While it runs the player's
-- current action (`Player:get_action`) is the ID of the timed action, so the rest of the
-- action system keeps working: `Player:is_doing_action` answers for everyone, and
-- resetting or replacing the action cancels the timed one.
--
-- The action ends in one of two ways. It succeeds when its duration has passed. It fails
-- when it is cancelled with `Flux.TimedAction:cancel`, when its condition stops holding,
-- when the player dies or leaves, or when their current action is changed by something
-- else. Either way the callback is called with the outcome and the
-- `PlayerTimedActionFinished` hook is run. `PlayerCanStartTimedAction` lets plugins veto
-- an action before it starts.
-- ```
-- actor:start_timed_action('lockpick', 5, {
--   text = 'ui.hud.bar_text.lockpick',
--   condition = Flux.TimedAction:all_of(
--     Flux.TimedAction:looking_at(door, 96),
--     Flux.TimedAction:staying_put()
--   ),
--   callback = function(actor, success)
--     if success and IsValid(door) then
--       door:Fire('unlock')
--     end
--   end
-- })
-- ```
--
-- The action is networked to its owner only. Their client draws it as a progress bar in
-- the middle of the screen through `Flux.Bars` (the bar's ID is `timed_action`, so the bar
-- hooks apply to it) and runs `PlayerTimedActionStarted` and `PlayerTimedActionFinished`
-- for the local player. On the client `Flux.TimedAction:get` therefore only knows the
-- action of the local player.
-- @module [Flux.TimedAction]

mod 'Flux::TimedAction'

--- Makes a cancel condition that holds while the player keeps looking at an entity from
-- close enough. Fails once the entity is removed.
-- @param entity [Entity the entity the player has to look at]
-- @param distance=96 [Number how far from the player's eyes the point they look at may be]
-- @return [Function condition for the options of Flux.TimedAction#start]
function Flux.TimedAction:looking_at(entity, distance)
  distance = distance or 96

  local max_distance = distance * distance

  return function(actor)
    if !IsValid(entity) then return false end

    local trace = actor:GetEyeTraceNoCursor()

    return trace.Entity == entity and trace.StartPos:DistToSqr(trace.HitPos) <= max_distance
  end
end

--- Makes a cancel condition that holds while the player stays where they were when the
-- action started. The condition remembers that position, so make a new one for every
-- action.
-- @param distance=16 [Number how far the player may move away]
-- @return [Function condition for the options of Flux.TimedAction#start]
function Flux.TimedAction:staying_put(distance)
  distance = distance or 16

  local max_distance = distance * distance
  local origin

  return function(actor)
    local pos = actor:GetPos()

    origin = origin or pos

    return pos:DistToSqr(origin) <= max_distance
  end
end

--- Combines several cancel conditions into one that holds while all of them do.
-- @param ... [Vararg condition functions]
-- @return [Function condition for the options of Flux.TimedAction#start]
function Flux.TimedAction:all_of(...)
  local conditions = { ... }

  return function(actor, action)
    for k, v in ipairs(conditions) do
      if !v(actor, action) then return false end
    end

    return true
  end
end

if SERVER then
  local active                  = Flux.TimedAction.active or {}
  Flux.TimedAction.active       = active
  Flux.TimedAction.last_serial  = Flux.TimedAction.last_serial or 0

  Cable.check_networked_string('fl_timed_action_start')
  Cable.check_networked_string('fl_timed_action_stop')

  --- Ends the timed action of a player: gives them back the action they had before, tells
  -- their client, calls the callback of the action and runs the finish hook.
  -- @param actor [Player]
  -- @param success [Boolean whether the action ran for its whole duration]
  -- @return [Boolean false if the player has no timed action]
  local function finish(actor, success)
    local action = active[actor]

    if !action then return false end

    active[actor] = nil

    if IsValid(actor) then
      if actor:is_doing_action(action.id) then
        actor:set_action(action.previous or 'none', true)
      end

      Cable.send(actor, 'fl_timed_action_stop', action.serial, success)
    end

    if isfunction(action.callback) then
      local ok, result = pcall(action.callback, actor, success, action)

      if !ok then
        error_with_traceback("Callback of the timed action '"..tostring(action.id).."' has failed to run!\n"..result)
      end
    end

    --- Called when a timed action of a player has ended, after the callback of the action.
    -- Runs on the server and, for the local player only, on the client of the owner (where
    -- the action table has no `condition`, `callback` and `options`).
    -- @param actor [Player The player who was doing the action; no longer valid on the
    --   server if they have already left]
    -- @param action [Map The action, see `Flux.TimedAction:get`]
    -- @param success [Boolean true if the action ran for its whole duration, false if it
    --   was cancelled]
    hook.Run('PlayerTimedActionFinished', actor, action, success)

    return true
  end

  --- Works out whether a running timed action is over.
  -- @param actor [Player]
  -- @param action [Map the action]
  -- @param cur_time [Number current CurTime()]
  -- @return [Boolean true if it has succeeded, false if it has failed, nil while it goes on]
  local function evaluate(actor, action, cur_time)
    if !IsValid(actor) or !actor:Alive() or !actor:is_doing_action(action.id) then
      return false
    end

    if action.condition then
      local ok, result = pcall(action.condition, actor, action)

      if !ok then
        error_with_traceback("Condition of the timed action '"..tostring(action.id).."' has failed to run!\n"..result)

        return false
      end

      if !result then return false end
    end

    if cur_time >= action.end_time then
      return true
    end
  end

  --- Starts a timed action for a player. Refused if the player is already doing something
  -- (their current action is not 'none'), unless forced; a forced start cancels the timed
  -- action that is running and puts the previous action of the player back when it ends.
  -- It gives way if the callback of the action it cancels starts another timed action.
  -- Serverside only.
  -- @param actor [Player]
  -- @param id [String action ID, which becomes the current action of the player]
  -- @param duration [Number seconds the action takes]
  -- @param options=nil [Map optional settings: text (String text or language phrase shown
  --   on the progress bar), arguments (Map values to substitute into the text), condition
  --   (Function called with the player and the action on every tick; the action is
  --   cancelled as soon as it returns false or nil), callback (Function called with the
  --   player, a success Boolean and the action when the action ends) and force (Boolean
  --   start even if the player is doing something else)]
  -- @return [Boolean true if the action has started]
  -- @see [Flux.TimedAction#looking_at]
  -- @see [Flux.TimedAction#staying_put]
  function Flux.TimedAction:start(actor, id, duration, options)
    options = options or {}
    duration = tonumber(duration) or 0

    if !IsValid(actor) or !actor:IsPlayer() or !isstring(id) or id == 'none' or duration <= 0 then
      return false
    end

    if !options.force and (active[actor] or actor:get_action() != 'none') then
      return false
    end

    --- Asks whether a player may start a timed action. Called on the server by
    -- `Flux.TimedAction:start` once the action is known to be valid and the player to be
    -- free (or the start to be forced), before anything is changed.
    -- @param actor [Player The player about to start the action]
    -- @param id [String Action ID]
    -- @param duration [Number Seconds the action takes]
    -- @param options [Map The options given to `Flux.TimedAction:start`]
    -- @return [Boolean Return false to keep the action from starting]
    if hook.Run('PlayerCanStartTimedAction', actor, id, duration, options) == false then
      return false
    end

    finish(actor, false)

    if active[actor] then return false end

    local previous = actor:get_action()
    local cur_time = CurTime()
    local serial = self.last_serial + 1

    self.last_serial = serial

    local action = {
      id          = id,
      serial      = serial,
      text        = options.text,
      arguments   = options.arguments,
      duration    = duration,
      start_time  = cur_time,
      end_time    = cur_time + duration,
      condition   = options.condition,
      callback    = options.callback,
      previous    = previous != 'none' and previous or nil,
      options     = options
    }

    active[actor] = action

    actor:set_action(id, true)

    Cable.send(actor, 'fl_timed_action_start', serial, id, cur_time, duration, action.text, action.arguments)

    --- Called when a timed action of a player has started. Runs on the server and, for the
    -- local player only, on the client of the owner (where the action table has no
    -- `condition`, `callback` and `options`).
    -- @param actor [Player The player doing the action]
    -- @param action [Map The action, see `Flux.TimedAction:get`]
    hook.Run('PlayerTimedActionStarted', actor, action)

    return true
  end

  --- Cancels the timed action of a player. The callback of the action is called with a
  -- failure. Serverside only.
  -- @param actor [Player]
  -- @param id=nil [String only cancel the action if it has this ID]
  -- @return [Boolean true if an action was cancelled]
  function Flux.TimedAction:cancel(actor, id)
    local action = active[actor]

    if !action or (id != nil and action.id != id) then return false end

    return finish(actor, false)
  end

  --- Returns the timed action a player is doing.
  -- @param actor [Player on the client only the local player has one]
  -- @return [Map the action with the id, text, arguments, duration, start_time and end_time
  --   (both CurTime() based) fields, on the server also condition, callback and options;
  --   nil if the player is not doing a timed action]
  function Flux.TimedAction:get(actor)
    return active[actor]
  end

  --- Hook handlers of the timed actions library, registered as `FLTimedActions`.
  local hooks = {}

  --- Checks the running timed actions: completes the ones whose time is up and cancels the
  -- ones whose condition no longer holds or whose player died or changed their action.
  function hooks:Think()
    if next(active) == nil then return end

    local cur_time = CurTime()
    local ended = nil

    for actor, action in pairs(active) do
      local success = evaluate(actor, action, cur_time)

      if success != nil then
        ended = ended or {}

        table.insert(ended, { actor = actor, action = action, success = success })
      end
    end

    if !ended then return end

    for k, v in ipairs(ended) do
      if active[v.actor] == v.action then
        finish(v.actor, v.success)
      end
    end
  end

  --- Cancels the timed action of a player who is leaving.
  -- @param actor [Player]
  function hooks:PlayerDisconnected(actor)
    finish(actor, false)
  end

  Plugin.add_hooks('FLTimedActions', hooks)
else
  local current = nil

  --- Returns the timed action bar, registering it the first time it is needed.
  -- @return [Map the bar]
  local function get_bar()
    return Flux.Bars:get('timed_action') or Flux.Bars:register('timed_action', {
      text = '',
      color = Color(50, 200, 50),
      max_value = 100,
      min_display = -1,
      x = ScrW() * 0.5 - Flux.Bars.default_w * 0.5,
      y = ScrH() * 0.5 - 10,
      height = 20,
      type = BAR_MANUAL
    })
  end

  --- Forgets the timed action of the local player and runs the finish hook for it.
  -- @param success [Boolean whether the action ran for its whole duration]
  local function clear(success)
    local action = current

    if !action then return end

    current = nil

    hook.Run('PlayerTimedActionFinished', LocalPlayer(), action, success)
  end

  --- Returns the timed action a player is doing.
  -- @param actor [Player on the client only the local player has one]
  -- @return [Map the action with the id, text, arguments, duration, start_time and end_time
  --   (both CurTime() based) fields, on the server also condition, callback and options;
  --   nil if the player is not doing a timed action]
  function Flux.TimedAction:get(actor)
    if actor == LocalPlayer() then
      return current
    end
  end

  Cable.receive('fl_timed_action_start', function(serial, id, start_time, duration, text, arguments)
    if current and current.serial > serial then return end

    clear(false)

    current = {
      id            = id,
      serial        = serial,
      text          = text,
      arguments     = arguments,
      duration      = duration,
      start_time    = start_time,
      end_time      = start_time + duration,
      display_text  = isstring(text) and (t(text, arguments)) or ''
    }

    hook.Run('PlayerTimedActionStarted', LocalPlayer(), current)
  end)

  Cable.receive('fl_timed_action_stop', function(serial, success)
    if current and current.serial == serial then
      clear(success == true)
    end
  end)

  --- Hook handlers of the timed actions library, registered as `FLTimedActions`.
  local hooks = {}

  --- Draws the progress bar of the local player's timed action in the middle of the screen.
  -- @param cur_time [Number current CurTime()]
  -- @param scrw [Number screen width]
  -- @param scrh [Number screen height]
  function hooks:FLHUDPaint(cur_time, scrw, scrh)
    local action = current

    if !action then return end

    local bar = get_bar()

    bar.x = scrw * 0.5 - bar.width * 0.5
    bar.y = scrh * 0.5 - bar.height * 0.5
    bar.value = math.Clamp((cur_time - action.start_time) / action.duration, 0, 1) * bar.max_value
    bar.interpolated = nil
    bar.text = action.display_text

    Flux.Bars:draw('timed_action')
  end

  Plugin.add_hooks('FLTimedActions', hooks)
end

--- Returns how far the timed action of a player has progressed.
-- @param actor [Player on the client only the local player has a timed action]
-- @return [Number fraction from 0 to 1, nil if the player is not doing a timed action]
function Flux.TimedAction:progress(actor)
  local action = self:get(actor)

  if !action then return end

  return math.Clamp((CurTime() - action.start_time) / action.duration, 0, 1)
end

local player_meta = FindMetaTable('Player')

if SERVER then
  --- Starts a timed action for the player. Serverside only.
  -- ```
  -- actor:start_timed_action('search', 3, {
  --   text = 'ui.hud.bar_text.search',
  --   condition = Flux.TimedAction:looking_at(container),
  --   callback = function(actor, success)
  --     if success then
  --       open_container(actor, container)
  --     end
  --   end
  -- })
  -- ```
  -- @param id [String action ID, which becomes the current action of the player]
  -- @param duration [Number seconds the action takes]
  -- @param options=nil [Map text, arguments, condition, callback and force, see
  --   Flux.TimedAction#start]
  -- @return [Boolean true if the action has started]
  -- @see [Flux.TimedAction#start]
  function player_meta:start_timed_action(id, duration, options)
    return Flux.TimedAction:start(self, id, duration, options)
  end

  --- Cancels the timed action of the player. The callback of the action is called with a
  -- failure. Serverside only.
  -- @param id=nil [String only cancel the action if it has this ID]
  -- @return [Boolean true if an action was cancelled]
  function player_meta:cancel_timed_action(id)
    return Flux.TimedAction:cancel(self, id)
  end
end

--- Returns the timed action the player is doing. On the client only the local player has
-- one.
-- @return [Map the action (see Flux.TimedAction#get), nil if there is none]
function player_meta:get_timed_action()
  return Flux.TimedAction:get(self)
end

--- Returns how far the timed action of the player has progressed. On the client only the
-- local player has a timed action.
-- @return [Number fraction from 0 to 1, nil if the player is not doing a timed action]
function player_meta:get_timed_action_progress()
  return Flux.TimedAction:progress(self)
end
