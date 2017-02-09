TOOL.Category = "Rework"
TOOL.Name = "Areas Tool"
TOOL.Command = nil
TOOL.ConfigName = ""

function TOOL:LeftClick(trace)
	local player = self:GetOwner()

	if (!self.area) then
		self.area = areas.Create("test", 512)
	end

	self.area:AddVertex(trace.HitPos)

	rw.undo:Create("Area")
		rw.undo:Add(function(obj, area) 
			print("Undone area")
		end, self.area)
		rw.undo:SetPlayer(player)
	rw.undo:Finish()

 	return true
end

function TOOL:RightClick(trace)
	if (self.area) then
		self.area:Register()
	end

	return true
end