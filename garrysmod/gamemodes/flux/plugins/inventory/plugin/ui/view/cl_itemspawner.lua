--[[
  Flux © 2016-2018 TeslaCloud Studios
  Do not share or re-distribute before
  the framework is publicly released.
--]]

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

  for uniqueID, itemTable in pairs(item.GetAll()) do
    if (!categories[itemTable.Category]) then 
      categories[itemTable.Category] = {}
    end

    table.insert(categories[itemTable.Category], {id = uniqueID, itemTable = itemTable})
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
      spawnIcon:SetModel(v.itemTable.Model)

      spawnIcon.DoClick = function(btn)
        mvc.Push("SpawnMenu::SpawnItem", v.id)
      end
    end
  end
end

vgui.Register("flItemSpawner", PANEL, "flBasePanel")
