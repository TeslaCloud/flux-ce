AddCSLuaFile()

ENT.Type = 'anim'
ENT.print_name = 'Item'
ENT.category = 'Flux'
ENT.Spawnable = false
ENT.RenderGroup = RENDERGROUP_BOTH

if SERVER then
  function ENT:Initialize()
    self:SetSolid(SOLID_VPHYSICS)
    self:SetMoveType(MOVETYPE_VPHYSICS)
    self:PhysicsInit(SOLID_VPHYSICS)
    self:SetUseType(ONOFF_USE)

    local phys_obj = self:GetPhysicsObject()

    if IsValid(phys_obj) then
      phys_obj:EnableMotion(true)
      phys_obj:Wake()
    end
  end

  function ENT:SetItem(item_table)
    if !item_table then return false end

    hook.run('PreEntityItemSet', self, item_table)

    self:SetModel(item_table:GetModel())
    self:SetSkin(item_table.skin)
    self:SetColor(item_table:GetColor())

    self.item = item_table

    item.NetworkEntityData(nil, self)

    hook.run('OnEntityItemSet', self, item_table)
  end

  function ENT:Use(activator, caller, use_type, value)
    local last_activator = self:get_nv('last_activator')

    -- prevent minge-grabbing glitch
    if IsValid(last_activator) and last_activator != activator then return end

    local hold_start = activator:get_nv('hold_start')

    if use_type == USE_ON then
      if !hold_start then
        activator:set_nv('hold_start', CurTime())
        activator:set_nv('hold_entity', self)
        self:set_nv('last_activator', activator)
      end
    elseif use_type == USE_OFF then
      if !hold_start then return end

      if CurTime() - hold_start < 0.5 then
        if IsValid(caller) and caller:IsPlayer() then
          if self.item then
            hook.run('PlayerUseItemEntity', caller, self, self.item)
          else
            fl.dev_print('Player attempted to use an item entity without item object tied to it!')
          end
        end
      end

      activator:set_nv('hold_start', false)
      activator:set_nv('hold_entity', false)
      self:set_nv('last_activator', false)
    end
  end

  function ENT:Think()
    local last_activator = self:get_nv('last_activator')

    if !IsValid(last_activator) then return end

    local hold_start = last_activator:get_nv('hold_start')

    if hold_start and CurTime() - hold_start > 0.5 then
      if self.item then
        self.item:do_menu_action('on_take', last_activator)
      end

      last_activator:set_nv('hold_start', false)
      last_activator:set_nv('hold_entity', false)
      self:set_nv('last_activator', false)
    end
  end
else
  function ENT:Draw()
    self:DrawModel()
  end

  function ENT:DrawTargetID(x, y, distance)
    if distance > 256 then return end

    local text = 'ERROR'
    local desc = 'Meow probably broke it again'
    local alpha = self.alpha or 255

    if distance > 100 then
      local d = distance - 100
      alpha = math.Clamp(255 * (156 - d) / 156, 0, 255)
    end

    local col = Color(255, 255, 255, alpha)
    local col2 = Color(0, 0, 0, alpha)

    if self.item then
      if hook.run('PreDrawItemTargetID', self, self.item, x, y, alpha, distance) == false then
        return
      end

      text = self.item.print_name
      desc = self.item.description
    else
      if !self.dataRequested then
        cable.send('RequestItemData', self:EntIndex())
        self.dataRequested = true
      end

      fl.draw_rotating_cog(x, y - 48, 48, 48, Color(255, 255, 255))

      return
    end

    local width, height = util.text_size(text, theme.get_font('tooltip_large'))
    local width2, height2 = util.text_size(desc, theme.get_font('tooltip_small'))
    local max_width = math.max(width, width2)
    local box_x = x - max_width * 0.5 - 8
    local accent_color = ColorAlpha(theme.get_color('accent'), math.max(0, alpha - 75))
    local ent_pos = self:GetPos():ToScreen()

    draw.textured_rect(theme.get_material('gradient'), box_x, y - 8, max_width + 16, height + height2 + 16, accent_color)

    draw.line(box_x, y + height + height2 + 8, ent_pos.x, ent_pos.y, accent_color)

    draw.SimpleTextOutlined(text, theme.get_font('tooltip_large'), x - width * 0.5, y, col, nil, nil, 1, col2)
    y = y + 26

    draw.SimpleTextOutlined(desc, theme.get_font('tooltip_small'), x - width2 * 0.5, y, col, nil, nil, 1, col2)
    y = y + 20

    hook.run('PostDrawItemTargetID', self, self.item, x, y, alpha, distance)
  end
end
