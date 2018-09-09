local PANEL = {}
PANEL.inventory_slots = 8
PANEL.inventory_type = 'hotbar'
PANEL.draw_inventory_slots = true

vgui.Register('fl_hotbar', PANEL, 'fl_inventory')

concommand.Add('fl_hotbar_rebuild', function()
  if IsValid(fl.client.hotbar) then
    local hotbar = fl.client.hotbar
    hotbar:SetVisible(false)
    hotbar:Remove()
    hotbar = fl_inventory:create_hotbar()
    hotbar:Rebuild()
    local w, h = hotbar:GetSize()
    local cx, cy = ScrC()
    hotbar:SetVisible(true)
    hotbar:SetPos(cx - w * 0.5, ScrH() - h - font.Scale(32))
  end
end)
