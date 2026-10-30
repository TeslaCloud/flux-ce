--- The entity that stands for a pool character placed in the world by a gamemaster.
-- `Gamemastery.spawn_in_world` creates it and gives it the character with `set_character`,
-- which applies the model and the skin of the character; the entity plays an idle animation
-- and blocks like a person. Everyone sees it, but only gamemasters see the name of the
-- character above it. A gamemaster who presses the use key on it possesses the character
-- where the entity stands, which removes the entity.

AddCSLuaFile()

local IsValid = IsValid

ENT.Type = 'anim'
ENT.PrintName = 'Gamemaster Character'
ENT.Category = 'Flux'
ENT.Spawnable = false
ENT.AutomaticFrameAdvance = true
ENT.RenderGroup = RENDERGROUP_OPAQUE

local mins, maxs = Vector(-16, -16, 0), Vector(16, 16, 72)

if SERVER then
  --- Makes the entity solid like a standing person, usable and idle.
  function ENT:Initialize()
    self:SetSolid(SOLID_BBOX)
    self:SetMoveType(MOVETYPE_NONE)
    self:SetCollisionBounds(mins, maxs)
    self:SetUseType(SIMPLE_USE)
    self:start_idle()
  end

  --- Starts the idle animation of the model.
  function ENT:start_idle()
    self:ResetSequence(self:idle_animation())
  end

  --- Gives the entity a pool character: its model and skin, and its ID and name for the
  -- clients.
  -- @param character [Character]
  function ENT:set_character(character)
    self.gm_character_id = tonumber(character.id)

    self:SetModel(character.model or Characters.default_model)
    self:SetSkin(tonumber(character.skin) or 0)
    self:SetCollisionBounds(mins, maxs)
    self:set_nv('gm_character_id', self.gm_character_id)
    self:set_nv('gm_character_name', character.name)
    self:start_idle()
  end

  --- Keeps the animation running every tick.
  -- @return [Boolean true, which makes the engine call it again at the next tick]
  function ENT:Think()
    self:NextThink(CurTime())

    return true
  end

  --- Lets a gamemaster who presses the use key on the entity possess its character.
  -- @param activator [Entity the entity that pressed the use key, normally a Player]
  -- @param _caller [Entity]
  function ENT:Use(activator, _caller)
    if IsValid(activator) and activator:IsPlayer() then
      Gamemastery.use_entity(activator, self)
    end
  end
else
  local text_color = Color(255, 255, 255)
  local outline_color = Color(0, 0, 0)
  local name_offset = Vector(0, 0, 80)

  --- Draws the model.
  function ENT:Draw()
    self:DrawModel()
  end

  --- Draws the name of the character above the entity, with a hint about the use key, for
  -- gamemasters who look at it from up to 512 units away.
  -- @param _x [Number screen position]
  -- @param _y [Number screen position]
  -- @param distance [Number distance between the local player and the entity]
  function ENT:DrawTargetID(_x, _y, distance)
    if distance > 512 or !IsValid(PLAYER) or !PLAYER:can('gamemastery') then return end

    local name = self:get_nv('gm_character_name')

    if !isstring(name) then return end

    local screen_pos = (self:GetPos() + name_offset):ToScreen()

    if !screen_pos.visible then return end

    local name_font = Theme.get_font('tooltip_large')
    local hint_font = Theme.get_font('tooltip_small')
    local hint = t'ui.gamemastery.use_hint'
    local name_w, name_h = util.text_size(name, name_font)
    local hint_w = util.text_size(hint, hint_font)
    local x_pos, y_pos = screen_pos.x, screen_pos.y
    local hint_y = y_pos + name_h

    draw.SimpleTextOutlined(name, name_font, x_pos - name_w * 0.5, y_pos, text_color, nil, nil, 1, outline_color)
    draw.SimpleTextOutlined(hint, hint_font, x_pos - hint_w * 0.5, hint_y, text_color, nil, nil, 1, outline_color)
  end
end
