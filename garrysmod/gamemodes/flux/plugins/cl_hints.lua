PLUGIN:set_global('flHints')
PLUGIN:set_name('Hints')
PLUGIN:set_description('Adds hints that are displayed to players.')
PLUGIN:set_author('TeslaCloud Studios')

local stored = {}

function flHints:OneMinute()
  local cur_time = CurTime()

  if cur_time >= (Flux.client.nextHint or 0) then
    flHints:display_random()

    Flux.client.nextHint = cur_time + 300
  end
end

function flHints:add(id, text, color, play_sound, callback)
  table.insert(stored, { id = id, text = text, color = color, play_sound = play_sound or false, callback = callback })
end

function flHints:display_random()
  local hint = table.Random(stored)

  if hint.callback and hint.callback() != true then return end
  if hint.play_sound then surface.PlaySound('hl1/fvox/blip.wav') end

  Flux.Notification:add(hint.text, 15, hint.color)
end

do
  flHints:add(t('hint.forums'), t('hint.forums_text'))
  flHints:add(t('hint.hints'), t('hint.hints_text'))
  flHints:add(t('hint.tab'), t('hint.tab_text'))
  flHints:add(t('hint.inventory'), t('hint.inventory_text'))
  flHints:add(t('hint.commands'), t('hint.commands_text'))
  flHints:add(t('hint.bugs'), t('hint.bugs_text'))
end
