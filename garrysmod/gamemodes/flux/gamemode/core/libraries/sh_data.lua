--[[
	Flux © 2016-2017 TeslaCloud Studios
	Do not share or re-distribute before
	the framework is publicly released.
--]]

library.New("data", _G)

if (SERVER) then
	function data.Save(key, value)
		if (!isstring(key) or !istable(value)) then return end

		if (!string.GetExtensionFromFilename(key)) then
			key = key..".flux"
		end

		fileio.Write("settings/flux/"..key, fl.core:Serialize(value))
	end

	function data.Load(key, failSafe)
		if (!isstring(key)) then return end

		if (!string.GetExtensionFromFilename(key)) then
			key = key..".flux"
		end

		if (file.Exists("settings/flux/"..key, "GAME")) then
			local strData = fileio.Read("settings/flux/"..key)

			return fl.core:Deserialize(strData)
		elseif (failSafe) then
			return failSafe
		else
			ErrorNoHalt("[Flux] Attempt to load data key that doesn't exist! ("..key..")\n")
		end
	end

	function data.Delete(key)
		if (!isstring(key)) then return end

		if (!string.GetExtensionFromFilename(key)) then
			key = key..".flux"
		end

		if (file.Exists("settings/flux/"..key, "GAME")) then
			fileio.Delete("settings/flux/"..key)
		end
	end
else
	function data.Save(key, value)
		if (!isstring(key) or !istable(value)) then return end

		if (!string.GetExtensionFromFilename(key)) then
			key = key..".dat"
		end

		file.Write("flux/"..key, fl.core:Serialize(value))
	end

	function data.Load(key, failSafe)
		if (!isstring(key)) then return end

		if (!string.GetExtensionFromFilename(key)) then
			key = key..".dat"
		end

		if (file.Exists("flux/"..key, "DATA")) then
			local strData = file.Read("flux/"..key, "DATA")

			return fl.core:Deserialize(strData)
		elseif (failSafe) then
			return failSafe
		else
			ErrorNoHalt("[Flux] Attempt to load data key that doesn't exist! ("..key..")\n")
		end
	end

	function data.Delete(key)
		if (!isstring(key)) then return end

		if (!string.GetExtensionFromFilename(key)) then
			key = key..".dat"
		end

		if (file.Exists("flux/"..key, "DATA")) then
			file.Delete("flux/"..key)
		end
	end
end

function data.SaveSchemaData(key, value)
	return data.Save("schemas/"..fl.core:GetSchemaFolder().."/"..key, value)
end

function data.LoadSchemaData(key, failSafe)
	return data.Load("schemas/"..fl.core:GetSchemaFolder().."/"..key, failSafe)
end

function data.DeleteSchemaData(key)
	return data.Delete("schemas/"..fl.core:GetSchemaFolder().."/"..key)
end

function data.SavePluginData(key, value)
	return data.SaveSchemaData("plugins/"..key, value)
end

function data.LoadPluginData(key, failSafe)
	return data.LoadSchemaData("plugins/"..key, failSafe)
end

function data.DeletePluginData(key)
	return data.DeleteSchemaData("plugins/"..key)
end