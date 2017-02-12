--[[
	Rework © 2016-2017 TeslaCloud Studios
	Do not share or re-distribute before
	the framework is publicly released.
--]]

TOOL.Category = "Rework"
TOOL.Name = "Area Tool"
TOOL.Command = nil
TOOL.ConfigName = ""

TOOL.ClientConVar["height"] = "512"
TOOL.ClientConVar["uniqueid"] = ""
TOOL.ClientConVar["areatype"] = "area"

function TOOL:LeftClick(trace)
	local player = self:GetOwner()
	local uniqueID = self:GetClientInfo("uniqueid")
	local height = self:GetClientNumber("height")
	local areatype = self:GetClientInfo("areatype")

	if (!uniqueID or uniqueID == "") then return false end

	if (!self.area) then
		self.area = areas.Create(uniqueID, height, {type = areatype or "area"})
	end

	self.area:AddVertex(trace.HitPos)

	rw.undo:Create("Vertex")
		rw.undo:Add(function(obj, area, id)
			print("Undone area vertex #"..id)
		end, self.area, #self.area.verts)
		rw.undo:SetPlayer(player)
	rw.undo:Finish()

 	return true
end

function TOOL:RightClick(trace)
	if (self.area) then
		local player = self:GetOwner()

		local area = self.area:Register()

		rw.undo:Remove(player, "Vertex")

		rw.undo:Create("Area")
			rw.undo:Add(function(obj, areaTable)
				print("Undone area")
			end, area)
			rw.undo:SetPlayer(player)
		rw.undo:Finish()
	end

	return true
end

function TOOL.BuildCPanel(CPanel)
	local types = areas.GetTypes()
	local options = {}

	for k, v in pairs(types) do
		options[v.name] = {["area_areatype"] = k}
	end

	CPanel:AddControl("Header", { Description = "#tool.area.desc" })

	local controlPresets = CPanel:AddControl("ComboBox", { MenuButton = 1, Folder = "areatype", Options = options, CVars = {"area_areatype"} })
	controlPresets.Button:SetVisible(false)
	controlPresets.DropDown:SetValue("Simple Area")

	CPanel:AddControl("TextBox", { Label = "#tool.area.text", Command = "area_uniqueid", MaxLenth = "20" })
	CPanel:AddControl("Slider", { Label = "#tool.area.height", Command = "area_height", Type = "Float", Min = -2048, Max = 2048 })
end