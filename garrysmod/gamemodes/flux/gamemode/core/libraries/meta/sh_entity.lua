--[[
	Flux © 2016-2018 TeslaCloud Studios
	Do not share or re-distribute before
	the framework is publicly released.
--]]

local entMeta = FindMetaTable("Entity")

--[[
	We store the original function here so we can override it from the player metaTable,
	which derives from the entity metaTable. This way we don't have to check if the entity is
	player every time the function is called.
--]]
entMeta.flSetModel = entMeta.flSetModel or entMeta.SetModel

function entMeta:IsStuck()
	local pos = self:GetPos()

	local trace = util.TraceHull({
		start = pos,
		endpos = pos,
		filter = self,
		mins = self:OBBMins(),
		maxs = self:OBBMaxs()
	})

	return trace.Entity and (trace.Entity:IsWorld() or trace.Entity:IsValid())
end
