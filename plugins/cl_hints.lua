--- Hints shows the player a random gameplay hint as a notification every five minutes.
-- Plugins register their own hints with `Hints:add`, optionally with a color, a sound and a
-- callback that decides whether the hint may be shown at the moment; `Hints:remove` takes a
-- hint out again, `Hints:find` looks one up and `Hints:all` lists them. A plugin that cannot
-- be sure that this one is loaded registers its hints from the `RegisterHints` hook, which
-- only this plugin runs. The plugin registers a few general hints itself.
--
-- Once a minute the plugin checks whether the interval has passed since the last hint. If it
-- has, a hint is picked at random among those that may be shown right now: the ones whose
-- callback allows them and which no `ShouldDisplayHint` handler holds back. When none may be
-- shown, the plugin tries again a minute later. The same hint is not shown twice in a row
-- as long as there is another one to show.
--
-- The interval is the `default_interval` constant at the top of this file, in seconds; a
-- schema or a plugin changes it with `Hints:set_interval`, and an interval of zero turns the
-- automatic hints off. Because the check runs once a minute, the interval is in effect
-- rounded up to whole minutes.
--
-- With the Settings plugin loaded the player can turn the hints off with the 'show_hints'
-- setting. `Hints:display` shows a hint regardless of all of the above.

PLUGIN:set_global('Hints')
PLUGIN:set_name('Hints')
PLUGIN:set_description('Adds hints that are displayed to players.')
PLUGIN:set_author('TeslaCloud Studios')

local default_interval = 300
local hint_lifetime = 15
local hint_sound = 'hl1/fvox/blip.wav'

local stored = Hints.stored or {}
Hints.stored = stored

--- Returns the time that passes between two automatic hints.
-- @return [Number interval in seconds; zero or less means that no hints are shown
--   automatically]
function Hints:get_interval()
  return self.interval or default_interval
end

--- Sets the time that passes between two automatic hints. The change applies to the hint
-- that is being waited for as well.
-- ```
-- -- A hint every ten minutes.
-- Hints:set_interval(600)
-- -- No automatic hints at all.
-- Hints:set_interval(0)
-- ```
-- @param seconds [Number interval in seconds, zero or less to turn the automatic hints off;
--   anything that is not a number restores the default of five minutes]
function Hints:set_interval(seconds)
  self.interval = tonumber(seconds)
end

--- Checks whether the player wants to see hints: the 'show_hints' setting of the Settings
-- plugin.
-- @return [Boolean false if the player has turned the hints off, true otherwise and when the
--   Settings plugin is not loaded]
function Hints:is_enabled()
  if ClientSettings then
    return ClientSettings:get('show_hints', true) != false
  end

  return true
end

--- Registers a hint that Hints:display_random can pick.
-- Registering an ID again replaces the hint and keeps its place in the list.
-- ```
-- Hints:add('forums', 'hint.forums')
-- Hints:add('inventory', 'hint.inventory', Color(255, 255, 255), true, function()
--   return PLAYER:Alive()
-- end)
--
-- -- From a plugin that does not depend on this one:
-- function MyPlugin:RegisterHints()
--   Hints:add('my_plugin', 'hint.my_plugin')
-- end
-- ```
-- @param id [String identifier of the hint]
-- @param text [String phrase id or plain text, translated when the hint is displayed]
-- @param color=nil [Color text color of the notification]
-- @param play_sound=false [Boolean play a blip sound when the hint is displayed]
-- @param callback=nil [Function called without arguments whenever a random hint is about to
--   be picked; the hint can only be picked if it returns a truthy value]
-- @return [Map the registered hint with the id, text, color, play_sound and callback
--   fields, or nil if the id or the text is not a string]
function Hints:add(id, text, color, play_sound, callback)
  if !isstring(id) or !isstring(text) then return end

  local hint = { id = id, text = text, color = color, play_sound = play_sound or false, callback = callback }

  for k, v in ipairs(stored) do
    if v.id == id then
      stored[k] = hint

      return hint
    end
  end

  table.insert(stored, hint)

  return hint
end

--- Removes a registered hint, so that it is no longer picked.
-- ```
-- -- The schema has no use for the hint about the forums.
-- Hints:remove('forums')
-- ```
-- @param id [String identifier of the hint]
-- @return [Boolean true if the hint has been removed, false if there is no such hint]
function Hints:remove(id)
  for k, v in ipairs(stored) do
    if v.id == id then
      table.remove(stored, k)

      return true
    end
  end

  return false
end

--- Returns a registered hint.
-- @param id [String identifier of the hint]
-- @return [Map the hint with the id, text, color, play_sound and callback fields, or nil if
--   there is no such hint]
function Hints:find(id)
  for k, v in ipairs(stored) do
    if v.id == id then
      return v
    end
  end
end

--- Returns every registered hint.
-- @return [List<Map> hints in the order they have been registered in]
function Hints:all()
  return stored
end

--- Checks whether a hint may be picked right now: its callback, if it has one, has to allow
-- it, and no ShouldDisplayHint handler may hold it back.
-- @param hint [Map registered hint]
-- @return [Boolean true if the hint may be picked]
function Hints:can_display(hint)
  if hint.callback and !hint.callback() then
    return false
  end

  --- Asks whether a hint may be picked as the random hint.
  -- Called on the client for every registered hint whose callback allows it, each time a
  -- random hint is about to be picked. Return false for every hint to keep the player from
  -- seeing random hints for the time being, in a menu or during a cutscene for example.
  -- @param hint [Map The hint: id, text, color, play_sound and callback fields]
  -- @return [Boolean Return false to keep the hint from being picked]
  return hook.Run('ShouldDisplayHint', hint) != false
end

--- Returns the hints that may be picked right now.
-- @return [List<Map> hints for which Hints:can_display is true]
function Hints:get_eligible()
  local eligible = {}

  for k, v in ipairs(stored) do
    if self:can_display(v) then
      table.insert(eligible, v)
    end
  end

  return eligible
end

--- Picks a random hint among those that may be shown right now. The hint that has been
-- displayed last is left out as long as there is another one to pick.
-- @return [Map the picked hint, or nil if no hint may be shown at the moment]
function Hints:pick_random()
  local eligible = self:get_eligible()

  if #eligible > 1 and self.last_id then
    for k, v in ipairs(eligible) do
      if v.id == self.last_id then
        table.remove(eligible, k)

        break
      end
    end
  end

  if #eligible == 0 then return end

  return eligible[math.random(#eligible)]
end

--- Shows a hint as a notification for 15 seconds, right away and whether or not it could be
-- picked at random: neither its callback nor the 'show_hints' setting is looked at.
-- ```
-- Hints:display('inventory')
-- ```
-- @param hint [String/Map identifier of a registered hint, or the hint itself]
-- @return [Boolean true if the hint has been shown, false if there is no such hint]
function Hints:display(hint)
  if isstring(hint) then
    hint = self:find(hint)
  end

  if !istable(hint) or !isstring(hint.text) then
    return false
  end

  if hint.play_sound then
    surface.PlaySound(hint_sound)
  end

  Flux.Notification:add(t(hint.text), hint_lifetime, hint.color)

  self.last_id = hint.id

  return true
end

--- Picks a random hint among those that may be shown right now and shows it as a
-- notification for 15 seconds.
-- Nothing is shown if the player has turned the hints off or if no hint may be shown at the
-- moment.
-- @return [Map the hint that has been shown, or nil if nothing has been shown]
function Hints:display_random()
  if !self:is_enabled() then return end

  local hint = self:pick_random()

  if hint and self:display(hint) then
    return hint
  end
end

--- Displays a random hint if the interval has passed since the last one. If there is no
-- hint to show, the next attempt is made a minute later.
function Hints:OneMinute()
  local interval = self:get_interval()

  if interval <= 0 then return end

  local cur_time = CurTime()

  if self.last_time and cur_time < self.last_time + interval then return end

  if self:display_random() then
    self.last_time = cur_time
  end
end

--- Lets the other plugins and the schema register their hints once all of them are loaded.
function Hints:OnSchemaLoaded()
  --- Lets plugins and the schema register their hints with `Hints:add`.
  -- Called on the client once all plugins and the schema have been loaded, and again on
  -- every code refresh. Only the Hints plugin runs it, so a handler does not have to check
  -- whether `Hints` exists. The handler of the schema runs after those of the plugins and
  -- can take their hints out with `Hints:remove`. Do not return anything from the handler,
  -- or the plugins after it are not asked.
  hook.Run('RegisterHints')
end

--- Registers the 'show_hints' setting, which lets the player turn the hints off.
function Hints:RegisterClientSettings()
  ClientSettings:register_setting('show_hints', {
    type = 'boolean',
    default = true,
    category = 'settings.categories.interface',
    name = 'hint.setting.name',
    description = 'hint.setting.desc'
  })
end

--- Tells whether the Settings plugin is loaded. The hint about turning the hints off is
-- only shown when it is.
-- @return [Boolean true if the settings menu is available]
local function has_settings()
  return ClientSettings != nil
end

--- Tells whether the inventory plugin is loaded. The hint about dropping items is only
-- shown when it is.
-- @return [Boolean true if the inventory plugin is loaded]
local function has_inventory()
  return Inventories != nil
end

Hints:add('forums', 'hint.forums')
Hints:add('hints', 'hint.hints', nil, false, has_settings)
Hints:add('tab', 'hint.tab')
Hints:add('inventory', 'hint.inventory', nil, false, has_inventory)
Hints:add('commands', 'hint.commands')
Hints:add('bugs', 'hint.bugs')
