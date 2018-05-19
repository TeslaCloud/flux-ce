--[[
  Flux © 2016-2018 TeslaCloud Studios
  Do not share or re-distribute before
  the framework is publicly released.
--]]

local PANEL = {}
PANEL.m_GridSize = {x = 1, y = 1}
PANEL.m_Docked = {}
PANEL.m_NextThink = 0

function PANEL:SetGridSize(x, y)
  if (!isnumber(x)) then return end
  if (!isnumber(y)) then
    y = x
  end

  self.m_GridSize.x = x
  self.m_GridSize.y = y
end

function PANEL:GetGridSize(bDimension)
  if (isbool(bDimension)) then
    if (bDimension) then
      return self.m_GridSize.x
    else
      return self.m_GridSize.y
    end
  end

  return self.m_GridSize
end

function PANEL:PositionPanel(obj)
  local panel = obj.panel

  if (!IsValid(panel)) then return end

  local size = self:GetGridSize()

  if (!size.x or !size.y or size.x <= 0 or size.y <= 0) then return end

  local w, h = self:GetWide(), self:GetTall()
  local unitX, unitY = w / size.x, h / size.y

  panel:SetPos(obj.pos.x * (size.x - 1) * unitX, obj.pos.y * (size.y - 1) * unitY)
  panel:SetSize(unitX * obj.pos.w, unitY * obj.pos.h)

  return obj
end

function PANEL:SetDockedPos(panel, x, y, w, h)
  panel.pos.x = panel.pos.x or x
  panel.pos.y = panel.pos.y or y
  panel.pos.w = panel.pos.w or w
  panel.pos.h = panel.pos.h or h

  return self:PositionPanel(panel)
end

function PANEL:AttachPanel(panel, x, y, w, h)
  if (!isnumber(x)) then x = 1 end
  if (!isnumber(y)) then y = 1 end
  if (!isnumber(w)) then w = 1 end
  if (!isnumber(h)) then h = 1 end

  panel:SetParent(self)

  local idx = table.insert(self.m_Docked, {panel = panel, pos = {x = x, y = y, w = w, h = h}})
  local obj = self.m_Docked[table.insert(self.m_Docked, {panel = panel, pos = {x = x, y = y, w = w, h = h}})]

  panel.m_DockedTileID = idx

  return self:PositionPanel(obj)
end

function PANEL:Think()
  local curTime = CurTime()

  if (curTime > self.m_NextThink) then
    for k, v in ipairs(self.m_Docked) do
      if (!IsValid(v.panel)) then
        table.remove(self.m_Docked, k)
      end
    end

    self.m_NextThink = curTime + 0.5
  end
end

vgui.Register("flTileBoard", PANEL, "flBasePanel")
