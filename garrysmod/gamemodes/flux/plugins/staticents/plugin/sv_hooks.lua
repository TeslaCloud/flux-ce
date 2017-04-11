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

local blacklistedEntities = {
	["fl_item"] = true
}

function flStaticEnts:PlayerMakeStatic(player, bIsStatic)
	local trace = player:GetEyeTraceNoCursor()
	local entity = trace.Entity

	if (!IsValid(entity)) then
		fl.player:Notify(player, "This is not a valid entity!")

		return
	end

	if (blacklistedEntities[entity:GetClass()]) then
		fl.player:Notify(player, "You cannot static this entity!")

		return
	end

	local isStatic = entity:GetPersistent()

	if (bIsStatic and isStatic) then
		fl.player:Notify(player, "This entity is already static!")

		return
	elseif (!bIsStatic and !isStatic) then
		fl.player:Notify(player, "This entity is not static!")

		return
	end

	entity:SetPersistent(bIsStatic)

	fl.player:Notify(player, (bIsStatic and "You have added a static entity!") or "You have removed this static entity!")
end

function flStaticEnts:ShutDown()
	hook.Run("PersistenceSave")
end

function flStaticEnts:PersistenceSave()
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

function flStaticEnts:PersistenceLoad()
	local loaded = data.LoadPlugin("static")

	if (!istable(loaded)) then return end
	if (!loaded.Entities) then return end
	if (!loaded.Constraints) then return end

	local entities, constraints = duplicator.Paste(nil, loaded.Entities, loaded.Constraints)

	for k, v in pairs(entities) do
		v:SetPersistent(true)
	end
end

function flStaticEnts:InitPostEntity()
	hook.Run("PersistenceLoad")
end