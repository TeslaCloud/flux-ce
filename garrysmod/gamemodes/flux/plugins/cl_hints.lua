PLUGIN:set_alias("flHints")
PLUGIN:set_name("Hints")
PLUGIN:set_description("Adds hints that are displayed to players.")
PLUGIN:set_author("Mr. Meow")

local stored = {}

function flHints:Add(id, text, color, bPlaySound, callback)
  table.insert(stored, {id = id, text = text, color = color, playSound = bPlaySound or false, callback = callback})
end

function flHints:DisplayRandom()
  local hint = table.Random(stored)

  if (hint.callback and hint.callback() != true) then return end
  if (hint.playSound) then surface.PlaySound("hl1/fvox/blip.wav") end

  fl.notification:Add(hint.text, 15, hint.color)
end

function flHints:OneMinute()
  local curTime = CurTime()

  if (curTime >= (fl.client.nextHint or 0)) then
    flHints:DisplayRandom()

    fl.client.nextHint = curTime + 300
  end
end

do
  flHints:Add(t('hint.forums'), t('hint.forums'))
  flHints:Add(t('hint.hints'), t('hint.hints'))
  flHints:Add(t('hint.tab'), t('hint.tab'))
  flHints:Add(t('hint.inventory'), t('hint.inventory'))
  flHints:Add(t('hint.commands'), t('hint.commands'))
  flHints:Add(t('hint.bugs'), t('hint.bugs'))
end
