local PANEL = {}
PANEL.grid_size = { x = 1, y = 1 }
PANEL.docked = {}
PANEL.next_think = 0

function PANEL:Think()
  local cur_time = CurTime()

  if cur_time > self.next_think then
    for k, v in ipairs(self.docked) do
      if !IsValid(v.panel) then
        table.remove(self.docked, k)
      end
    end

    self.next_think = cur_time + 0.5
  end
end

function PANEL:set_grid_size(x, y)
  if !isnumber(x) then return end
  if !isnumber(y) then
    y = x
  end

  self.grid_size.x = x
  self.grid_size.y = y
end

function PANEL:get_grid_size(dimension)
  if isbool(dimension) then
    if dimension then
      return self.grid_size.x
    else
      return self.grid_size.y
    end
  end

  return self.grid_size
end

function PANEL:position_panel(obj)
  local panel = obj.panel

  if !IsValid(panel) then return end

  local size = self:get_grid_size()

  if !size.x or !size.y or size.x <= 0 or size.y <= 0 then return end

  local w, h = self:GetWide(), self:GetTall()
  local unit_x, unit_y = w / size.x, h / size.y

  panel:SetPos(obj.pos.x * (size.x - 1) * unit_x, obj.pos.y * (size.y - 1) * unit_y)
  panel:SetSize(unit_x * obj.pos.w, unit_y * obj.pos.h)

  return obj
end

function PANEL:set_docked_pos(panel, x, y, w, h)
  panel.pos.x = panel.pos.x or x
  panel.pos.y = panel.pos.y or y
  panel.pos.w = panel.pos.w or w
  panel.pos.h = panel.pos.h or h

  return self:position_panel(panel)
end

function PANEL:attach_panel(panel, x, y, w, h)
  if !isnumber(x) then x = 1 end
  if !isnumber(y) then y = 1 end
  if !isnumber(w) then w = 1 end
  if !isnumber(h) then h = 1 end

  panel:SetParent(self)

  local idx = table.insert(self.docked, { panel = panel, pos = { x = x, y = y, w = w, h = h } })
  local obj = self.docked[table.insert(self.docked, { panel = panel, pos = { x = x, y = y, w = w, h = h } })]

  panel.m_DockedTileID = idx

  return self:position_panel(obj)
end

vgui.Register('fl_tile_board', PANEL, 'fl_base_panel')
