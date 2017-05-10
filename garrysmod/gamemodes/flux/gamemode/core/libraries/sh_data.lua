--[[
	Flux © 2016-2017 TeslaCloud Studios
	Do not share or re-distribute before
	the framework is publicly released.
--]]

library.New "data"

if (SERVER) then
	function data.Save(key, value)
		if (!isstring(key) or !istable(value)) then return end

		if (!string.GetExtensionFromFilename(key)) then
			key = key..".pon"
		end

		fileio.Write("settings/flux/"..key, fl.Serialize(value))
	end

	function data.Load(key, failSafe)
		if (!isstring(key)) then return end

		if (!string.GetExtensionFromFilename(key)) then
			key = key..".pon"
		end

		if (file.Exists("settings/flux/"..key, "GAME")) then
			local strData = fileio.Read("settings/flux/"..key)

			return fl.Deserialize(strData)
		elseif (failSafe) then
			return failSafe
		else
			ErrorNoHalt("[Flux] Attempt to load data key that doesn't exist! ("..key..")\n")
		end
	end

	function data.Delete(key)
		if (!isstring(key)) then return end

		if (!string.GetExtensionFromFilename(key)) then
			key = key..".pon"
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

		file.Write("flux/"..key, fl.Serialize(value))
	end

	function data.Load(key, failSafe)
		if (!isstring(key)) then return end

		if (!string.GetExtensionFromFilename(key)) then
			key = key..".dat"
		end

		if (file.Exists("flux/"..key, "DATA")) then
			local strData = file.Read("flux/"..key, "DATA")

			return fl.Deserialize(strData)
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

function data.SaveSchema(key, value)
	return data.Save("schemas/"..fl.GetSchemaFolder().."/"..key, value)
end

function data.LoadSchema(key, failSafe)
	return data.Load("schemas/"..fl.GetSchemaFolder().."/"..key, failSafe)
end

function data.DeleteSchema(key)
	return data.Delete("schemas/"..fl.GetSchemaFolder().."/"..key)
end

function data.SavePlugin(key, value)
	return data.SaveSchema("plugins/"..key, value)
end

function data.LoadPlugin(key, failSafe)
	return data.LoadSchema("plugins/"..key, failSafe)
end

function data.DeletePlugin(key)
	return data.DeleteSchema("plugins/"..key)
end