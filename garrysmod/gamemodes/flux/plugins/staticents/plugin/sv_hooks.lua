--[[
	Flux © 2016-2017 TeslaCloud Studios
	Do not share or re-distribute before
	the framework is publicly released.
--]]

-- Disable default Sandbox persistence.
hook.Remove("ShutDown", "SavePersistenceOnShutdown")
hook.Remove("PersistenceSave", "PersistenceSave")
hook.Remove("PersistenceLoad", "PersistenceLoad")
hook.Remove("InitPostEntity", "PersistenceInit")

function PLUGIN:ShutDown()
	hook.Run("PersistenceSave")
end

function PLUGIN:PersistenceSave()
	local entities = {}

	for k, v in ipairs(ents.GetAll()) do
		if (v:GetPersistent()) then
			table.insert(entities, v)
		end
	end

	local toSave = duplicator.CopyEnts(entities)

	if (!istable(toSave)) then return end

	data.SavePlugin("static", toSave)
end

function PLUGIN:PersistenceLoad()
	local loaded = data.LoadPlugin("static")

	if (!istable(loaded)) then return end
	if (!loaded.Entities) then return end
	if (!loaded.Constraints) then return end

	local entities, constraints = duplicator.Paste(nil, loaded.Entities, loaded.Constraints)

	for k, v in pairs(entities) do
		v:SetPersistent(true)
	end
end

function PLUGIN:InitPostEntity()
	hook.Run("PersistenceLoad")
end