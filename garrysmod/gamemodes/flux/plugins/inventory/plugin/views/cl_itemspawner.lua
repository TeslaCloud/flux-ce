local PANEL = {}

function PANEL:Init()
  local w, h = self:GetWide(), self:GetTall()

  self.scrollPanel = vgui.Create("DScrollPanel", self)
  self.scrollPanel:Dock(FILL)

  self.layout = vgui.Create("DListLayout", self.scrollPanel)
  self.layout:Dock(FILL)

  self:Rebuild()
end

function PANEL:Rebuild()
  local categories = {}

  self.scrollPanel:Dock(FILL)
  self.layout:Dock(FILL)

  for id, itemTable in pairs(item.GetAll()) do
    if !categories[itemTable.category] then 
      categories[itemTable.category] = {}
    end

    table.insert(categories[itemTable.category], {id = id, itemTable = itemTable})
  end

  self.layout:Clear()

  for id, category in pairs(categories) do
    local collapsible = self.layout:Add("DCollapsibleCategory")
    local list = vgui.Create("DIconLayout", self)
    collapsible:SetLabel(id)
    collapsible:SetContents(list)

    for k, v in ipairs(category) do
      local spawnIcon = list:Add("SpawnIcon")
      spawnIcon:SetSize(48, 48)
      spawnIcon:SetModel(v.itemTable.model)

      spawnIcon.DoClick = function(btn)
        mvc.push("SpawnMenu::SpawnItem", v.id)
      end
    end
  end
end

vgui.Register("flItemSpawner", PANEL, "flBasePanel")
