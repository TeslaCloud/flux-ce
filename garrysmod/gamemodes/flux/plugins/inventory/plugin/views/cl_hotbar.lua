local PANEL = {}
PANEL.inventory_slots = 8
PANEL.inventory_type = 'hotbar'
PANEL.draw_inventory_slots = true

function PANEL:Rebuild()
  local w, h = self:GetSize()
  local cx, cy = ScrC()
  self:SetPos(cx - w * 0.5, ScrH() - h - font.scale(32))

  self.BaseClass.Rebuild(self)
end

vgui.Register('fl_hotbar', PANEL, 'fl_inventory')

concommand.Add('fl_hotbar_rebuild', function()
  if IsValid(fl.client.hotbar) then
    local hotbar = fl.client.hotbar
    hotbar:Remove()
    hotbar = fl_inventory:create_hotbar()
    hotbar:Rebuild()
    hotbar:SetVisible(false)
  end
end)
