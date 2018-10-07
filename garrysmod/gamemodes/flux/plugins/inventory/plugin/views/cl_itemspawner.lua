local PANEL = {}

function PANEL:Init()
  local w, h = self:GetWide(), self:GetTall()

  self.scroll_panel = vgui.Create('DScrollPanel', self)
  self.scroll_panel:Dock(FILL)

  self.layout = vgui.Create('DListLayout', self.scroll_panel)
  self.layout:Dock(FILL)

  self:Rebuild()
end

function PANEL:Rebuild()
  local categories = {}

  self.scroll_panel:Dock(FILL)
  self.layout:Dock(FILL)

  for id, item_table in pairs(item.GetAll()) do
    if !categories[item_table.category] then 
      categories[item_table.category] = {}
    end

    table.insert(categories[item_table.category], {id = id, item_table = item_table})
  end

  self.layout:Clear()

  for id, category in pairs(categories) do
    local collapsible = self.layout:Add('DCollapsibleCategory')
    local list = vgui.Create('DIconLayout', self)
    collapsible:SetLabel(id)
    collapsible:SetContents(list)

    for k, v in ipairs(category) do
      local spawnIcon = list:Add('SpawnIcon')
      spawnIcon:SetSize(48, 48)
      spawnIcon:SetModel(v.item_table.model)

      spawnIcon.DoClick = function(btn)
        mvc.push('SpawnMenu::SpawnItem', v.id)
      end
    end
  end
end

vgui.Register('flItemSpawner', PANEL, 'fl_base_panel')
