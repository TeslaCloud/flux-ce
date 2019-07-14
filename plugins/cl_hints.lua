PLUGIN:set_global('Hints')
PLUGIN:set_name('Hints')
PLUGIN:set_description('Adds hints that are displayed to players.')
PLUGIN:set_author('TeslaCloud Studios')

local stored = {}

function Hints:OneMinute()
  local cur_time = CurTime()

  if cur_time >= (PLAYER.next_hint or 0) then
    self:display_random()

    PLAYER.next_hint = cur_time + 300
  end
end

function Hints:add(id, text, color, play_sound, callback)
  table.insert(stored, { id = id, text = text, color = color, play_sound = play_sound or false, callback = callback })
end

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
