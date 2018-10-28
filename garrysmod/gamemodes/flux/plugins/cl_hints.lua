PLUGIN:set_global('flHints')
PLUGIN:set_name('Hints')
PLUGIN:set_description('Adds hints that are displayed to players.')
PLUGIN:set_author('Mr. Meow')

local stored = {}

function flHints:Add(id, text, color, play_sound, callback)
  table.insert(stored, {id = id, text = text, color = color, play_sound = play_sound or false, callback = callback})
end

function flHints:DisplayRandom()
  local hint = table.Random(stored)

  if hint.callback and hint.callback() != true then return end
  if hint.play_sound then surface.PlaySound('hl1/fvox/blip.wav') end

  fl.notification:add(hint.text, 15, hint.color)
end

function flHints:OneMinute()
  local cur_time = CurTime()

  if cur_time >= (fl.client.nextHint or 0) then
    flHints:DisplayRandom()

    fl.client.nextHint = cur_time + 300
  end
end

do
  flHints:Add(t('hint.forums'), t('hint.forums_text'))
  flHints:Add(t('hint.hints'), t('hint.hints_text'))
  flHints:Add(t('hint.tab'), t('hint.tab_text'))
  flHints:Add(t('hint.inventory'), t('hint.inventory_text'))
  flHints:Add(t('hint.commands'), t('hint.commands_text'))
  flHints:Add(t('hint.bugs'), t('hint.bugs_text'))
end
