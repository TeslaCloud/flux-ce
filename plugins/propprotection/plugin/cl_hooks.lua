--- Client side of the Prop Protection plugin: shows who owns the entity the local player is
-- looking at and registers the client setting that hides it.

local t = t

--- Color of the owner line on the entities of the local player.
local own_color = Color('lightgreen')

--- Colors that the owner line is drawn with, faded by distance; filled in every frame rather
-- than allocated.
local text_color = Color(255, 255, 255)
local outline_color = Color(0, 0, 0)

--- Copies a color into one of the reusable colors with another alpha.
-- @param target [Color the color that is written to]
-- @param source [Color the color to copy]
-- @param alpha [Number alpha from 0 to 255]
-- @return [Color the target]
local function fade(target, source, alpha)
  target.r = source.r
  target.g = source.g
  target.b = source.b
  target.a = alpha

  return target
end

--- Registers the setting that shows or hides the owner line of entities.
function PropProtection:RegisterClientSettings()
  ClientSettings:register_setting('show_prop_owners', {
    type = 'boolean',
    default = true,
    category = 'settings.categories.interface',
    name = 'settings.prop_protection.show_owners.name',
    description = 'settings.prop_protection.show_owners.desc'
  })
end

--- Draws the owner of the entity that the local player is looking at above its target ID:
-- a note on their own entities, and the name of the owner on those of others. The line can
-- be switched off with the 'show_prop_owners' client setting. Other players' entities only
-- show their owner if the prop_owner_display config is on or the local player is exempt
-- from prop protection.
-- @param entity [Entity]
-- @param x [Number screen x of the horizontal center of the target ID]
-- @param y [Number screen y of the first line of the target ID]
-- @param dist [Number distance between the local player and the entity]
function PropProtection:DrawEntityTargetID(entity, x, y, dist)
  if dist >= 300 then return end

  local key = entity:get_nv('fl_prop_owner')

  if !key then return end
  if ClientSettings and ClientSettings:get('show_prop_owners', true) == false then return end

  local client = PLAYER
  local text
  local color = color_white

  if key == self:get_key(client) then
    text = t'ui.prop_protection.owner_you'
    color = own_color
  elseif Config.get('prop_owner_display') or self:can_bypass(client) then
    local owner = self:find_owner(key)

    if owner then
      text = t('ui.prop_protection.owner', { name = owner:name() })
    else
      text = t'ui.prop_protection.owner_away'
    end
  else
    return
  end

  local alpha = 255 - 255 * (dist / 300)
  local font = Theme.get_font('tooltip_small')
  local text_w, text_h = util.text_size(text, font)

  draw.SimpleTextOutlined(
    text,
    font,
    x - text_w * 0.5,
    y - text_h - 4,
    fade(text_color, color, alpha),
    nil,
    nil,
    1,
    fade(outline_color, color_black, alpha)
  )
end
