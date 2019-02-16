local PANEL = {}
PANEL.inventory_type = 'hotbar'
PANEL.draw_inventory_slots = true

function PANEL:rebuild()
  local w, h = self:GetSize()
  local cx, cy = ScrC()
  self:SetPos(cx - w * 0.5, ScrH() - h - font.scale(32))

  self.BaseClass.rebuild(self)
end

vgui.Register('fl_hotbar', PANEL, 'fl_inventory')

concommand.Add('fl_hotbar_rebuild', function()
  if IsValid(fl.client.hotbar) then
    local hotbar = fl.client.hotbar
    hotbar:Remove()
    hotbar = Inventory:create_hotbar()
    hotbar:rebuild()
    hotbar:SetVisible(false)
  end
end)
