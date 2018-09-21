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

    local physObj = self:GetPhysicsObject()

    if IsValid(physObj) then
      physObj:EnableMotion(true)
      physObj:Wake()
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

  function ENT:Use(activator, caller, useType, value)
    local lastActivator = self:get_nv('last_activator')

    -- prevent minge-grabbing glitch
    if IsValid(lastActivator) and lastActivator != activator then return end

    local holdStart = activator:get_nv('hold_start')

    if useType == USE_ON then
      if !holdStart then
        activator:set_nv('hold_start', CurTime())
        activator:set_nv('hold_entity', self)
        self:set_nv('last_activator', activator)
      end
    elseif useType == USE_OFF then
      if !holdStart then return end

      if CurTime() - holdStart < 0.5 then
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
    local lastActivator = self:get_nv('last_activator')

    if !IsValid(lastActivator) then return end

    local holdStart = lastActivator:get_nv('hold_start')

    if holdStart and CurTime() - holdStart > 0.5 then
      if self.item then
        self.item:do_menu_action('on_take', lastActivator)
      end

      lastActivator:set_nv('hold_start', false)
      lastActivator:set_nv('hold_entity', false)
      self:set_nv('last_activator', false)
    end
  end
else
  function ENT:Draw()
    self:DrawModel()
  end

  function ENT:DrawTargetID(x, y, distance)
    if distance > 370 then return end

    local text = 'ERROR'
    local desc = "This item's data has failed to fetch. This is an error."
    local alpha = 255

    if distance > 210 then
      local d = distance - 210
      alpha = math.Clamp(255 * (160 - d) / 160, 0, 255)
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
        netstream.Start('RequestItemData', self:EntIndex())
        self.dataRequested = true
      end

      fl.draw_rotating_cog(x, y - 48, 48, 48, Color(255, 255, 255))

      return
    end

    local width, height = util.text_size(text, theme.GetFont('Tooltip_Large'))
    local width2, height2 = util.text_size(desc, theme.GetFont('Tooltip_Small'))

    draw.SimpleTextOutlined(text, theme.GetFont('Tooltip_Large'), x - width * 0.5, y, col, nil, nil, 1, col2)
    y = y + 26

    draw.SimpleTextOutlined(desc, theme.GetFont('Tooltip_Small'), x - width2 * 0.5, y, col, nil, nil, 1, col2)
    y = y + 20

    hook.run('PostDrawItemTargetID', self, self.item, x, y, alpha, distance)
  end
end
