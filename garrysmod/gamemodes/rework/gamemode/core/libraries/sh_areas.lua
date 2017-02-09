--[[
	Rework © 2016-2017 TeslaCloud Studios
	Do not share or re-distribute before
	the framework is publicly released.
--]]

library.New("areas", _G)

local stored = areas.stored or {}
areas.stored = stored

local callbacks = areas.callbacks or {}
areas.callbacks = callbacks

function areas.GetAll()
	return stored
end

function areas.GetCallbacks()
	return callbacks
end

function areas.Create(uniqueID, height, data)
	local area = {}
	area.uniqueID = uniqueID
	area.minH = 0
	area.maxH = 0
	area.height = height or 0
	area.verts = {}
	area.polys = {}
	area.type = data.type or "area"

	if (data) then
		table.Merge(area, data)
	end

	function area:AddVertex(vect)
		if (#self.verts == 0) then
			self.minH = vect.z
			self.maxH = self.minH + self.height
		else
			vect.z = self.minH
		end

		table.insert(self.verts, vect)
	end

	function area:FinishPoly()
		table.insert(self.polys, self.verts)
		self.verts = {}
	end

	function area:Register()
		return areas.Register(uniqueID, self)
	end

	return area
end

function areas.Register(id, data)
	if (!id or !data) then return end
	if (#data.polys < 1) then return end

	stored[id] = data
end

-- callback(player, area, poly, bHasEntered, curPos, curTime)
function areas.SetCallback(areaType, callback)
	callbacks[areaType] = callback
end

function areas.GetCallback(areaType)
	return callbacks[areaType] or function() rw.core:DevPrint("Callback for area type '"..areaType.."' could not be found!") end
end