PLUGIN:set_global('Hints')
PLUGIN:set_name('Hints')
PLUGIN:set_description('Adds hints that are displayed to players.')
PLUGIN:set_author('TeslaCloud Studios')

local stored = {}

--- Displays a random hint if at least five minutes have passed since the last one.
function Hints:OneMinute()
  local cur_time = CurTime()

  if cur_time >= (PLAYER.next_hint or 0) then
    self:display_random()

    PLAYER.next_hint = cur_time + 300
  end
end

--- Registers a hint that Hints:display_random can pick.
-- ```
-- Hints:add('forums', 'hint.forums')
-- Hints:add('inventory', 'hint.inventory', Color(255, 255, 255), true, function()
--   return PLAYER:Alive()
-- end)
-- ```
-- @param id [String identifier of the hint]
-- @param text [String phrase id or plain text, translated when the hint is displayed]
-- @param color=nil [Color text color of the notification]
-- @param play_sound=false [Boolean play a blip sound when the hint is displayed]
-- @param callback=nil [Function called without arguments when the hint is picked; the hint
--   is only shown if it returns true]
function Hints:add(id, text, color, play_sound, callback)
  table.insert(stored, { id = id, text = text, color = color, play_sound = play_sound or false, callback = callback })
end

--- Picks a random registered hint and shows it as a notification for 15 seconds.
-- Nothing is shown if the picked hint has a callback that does not return true.
function Hints:display_random()
  local hint = table.Random(stored)

  if hint.callback and hint.callback() != true then return end

  if hint.play_sound then surface.PlaySound('hl1/fvox/blip.wav') end

  Flux.Notification:add(t(hint.text), 15, hint.color)
end

do
  Hints:add('forums', 'hint.forums')
  Hints:add('hints', 'hint.hints')
  Hints:add('tab', 'hint.tab')
  Hints:add('inventory', 'hint.inventory')
  Hints:add('commands', 'hint.commands')
  Hints:add('bugs', 'hint.bugs')
end
