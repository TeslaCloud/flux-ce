--[[
	Rework © 2016-2017 TeslaCloud Studios
	Do not share or re-distribute before
	the framework is publicly released.
--]]

TOOL.Category = "Rework"
TOOL.Name = "Areas Tool"
TOOL.Command = nil
TOOL.ConfigName = ""

TOOL.ClientConVar["height"] = "512"
TOOL.ClientConVar["uniqueid"] = ""

function TOOL:LeftClick(trace)
	local player = self:GetOwner()
	local uniqueID = self:GetClientInfo("uniqueid")
	local height = self:GetClientNumber("height")

	if (!uniqueID or uniqueID == "") then return false end

	if (!self.area) then
		self.area = areas.Create(uniqueID, height)
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

local ConVarsDefault = TOOL:BuildConVarList()

function TOOL.BuildCPanel(CPanel)
	CPanel:AddControl("Header", { Description = "#tool.area.desc" })
	CPanel:AddControl("ComboBox", { MenuButton = 1, Folder = "area", Options = { ["#preset.default"] = ConVarsDefault }, CVars = table.GetKeys(ConVarsDefault) })
	CPanel:AddControl("TextBox", { Label = "#tool.area.text", Command = "area_uniqueid", MaxLenth = "20" })
	CPanel:AddControl("Slider", { Label = "#tool.area.height", Command = "area_height", Type = "Float", Min = -2048, Max = 2048 })
end