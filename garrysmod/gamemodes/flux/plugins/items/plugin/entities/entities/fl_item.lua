AddCSLuaFile()

ENT.Type = "anim"
ENT.print_name = "Item"
ENT.category = "Flux"
ENT.Spawnable = false
ENT.RenderGroup = RENDERGROUP_BOTH

if SERVER then
  function ENT:Initialize()
    self:SetSolid(SOLID_VPHYSICS)
    self:SetMoveType(MOVETYPE_VPHYSICS)
    self:PhysicsInit(SOLID_VPHYSICS)
    self:SetUseType(ONOFF_USE)

    local physObj = self:GetPhysicsObject()

    if (IsValid(physObj)) then
      physObj:EnableMotion(true)
      physObj:Wake()
    end
  end

  function ENT:SetItem(itemTable)
    if (!itemTable) then return false end

    hook.Run("PreEntityItemSet", self, itemTable)

    self:SetModel(itemTable:GetModel())
    self:SetSkin(itemTable.skin)
    self:SetColor(itemTable:GetColor())

    self.item = itemTable

    item.NetworkEntityData(nil, self)

    hook.Run("OnEntityItemSet", self, itemTable)
  end

  function ENT:Use(activator, caller, useType, value)
    local lastActivator = self:GetNetVar("LastActivator")

    -- prevent minge-grabbing glitch
    if (IsValid(lastActivator) and lastActivator != activator) then return end

    local holdStart = activator:GetNetVar("HoldStart")

    if (useType == USE_ON) then
      if (!holdStart) then
        activator:SetNetVar("HoldStart", CurTime())
        activator:SetNetVar("HoldEnt", self)
        self:SetNetVar("LastActivator", activator)
      end
    elseif (useType == USE_OFF) then
      if (!holdStart) then return end

      if (CurTime() - holdStart < 0.5) then
        if (IsValid(caller) and caller:IsPlayer()) then
          if (self.item) then
            hook.Run("PlayerUseItemEntity", caller, self, self.item)
          else
            fl.dev_print("Player attempted to use an item entity without item object tied to it!")
          end
        end
      end

      activator:SetNetVar("HoldStart", false)
      activator:SetNetVar("HoldEnt", false)
      self:SetNetVar("LastActivator", false)
    end
  end

  function ENT:Think()
    local lastActivator = self:GetNetVar("LastActivator")

    if (!IsValid(lastActivator)) then return end

    local holdStart = lastActivator:GetNetVar("HoldStart")

    if (holdStart and CurTime() - holdStart > 0.5) then
      if (self.item) then
        self.item:do_menu_action("OnTake", lastActivator)
      end

      lastActivator:SetNetVar("HoldStart", false)
      lastActivator:SetNetVar("HoldEnt", false)
      self:SetNetVar("LastActivator", false)
    end
  end
else
  function ENT:Draw()
    self:DrawModel()
  end

  function ENT:DrawTargetID(x, y, distance)
    if (distance > 370) then return end

    local text = "ERROR"
    local desc = "This item's data has failed to fetch. This is an error."
    local alpha = 255

    if (distance > 210) then
      local d = distance - 210
      alpha = math.Clamp(255 * (160 - d) / 160, 0, 255)
    end

    local col = Color(255, 255, 255, alpha)
    local col2 = Color(0, 0, 0, alpha)

    if (self.item) then
      if (hook.Run("PreDrawItemTargetID", self, self.item, x, y, alpha, distance) == false) then
        return
      end

      text = self.item.print_name
      desc = self.item.description
    else
      if (!self.dataRequested) then
        netstream.Start("RequestItemData", self:EntIndex())
        self.dataRequested = true
      end

      fl.DrawRotatingCog(x, y - 48, 48, 48, Color(255, 255, 255))

      return
    end

    local width, height = util.GetTextSize(text, theme.GetFont("Tooltip_Large"))
    local width2, height2 = util.GetTextSize(desc, theme.GetFont("Tooltip_Small"))

    draw.SimpleTextOutlined(text, theme.GetFont("Tooltip_Large"), x - width * 0.5, y, col, nil, nil, 1, col2)
    y = y + 26

    draw.SimpleTextOutlined(desc, theme.GetFont("Tooltip_Small"), x - width2 * 0.5, y, col, nil, nil, 1, col2)
    y = y + 20

    hook.Run("PostDrawItemTargetID", self, self.item, x, y, alpha, distance)
  end
end
