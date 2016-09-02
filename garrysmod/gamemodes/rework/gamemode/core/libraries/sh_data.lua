--[[ 
	Rework © 2016 TeslaCloud Studios
	Do not share, re-distribute or sell.
--]]

library.New("data", _G);

if (SERVER) then
	function data.Save(key, value)
		if (typeof(key) != "string" or typeof(value) != "table") then return; end;

		if (!string.GetExtensionFromFilename(key)) then
			key = key..".rw";
		end;

		fileio.Write("settings/rework/"..key, rw.core:Serialize(value));
	end;

	function data.Load(key, failSafe)
		if (typeof(key) != "string") then return; end;

		if (!string.GetExtensionFromFilename(key)) then
			key = key..".rw";
		end;

		if (file.Exists("settings/rework/"..key, "GAME")) then
			local strData = fileio.Read("settings/rework/"..key);

			return rw.core:Deserialize(strData);
		elseif (failsafe) then
			return failSafe;
		else
			ErrorNoHalt("[Rework] Attempt to load data key that doesn't exist! ("..key..")\n");
		end;
	end;
else
	function data.Save(key, value)
		if (typeof(key) != "string" or typeof(value) != "table") then return; end;

		if (!string.GetExtensionFromFilename(key)) then
			key = key..".rw";
		end;

		file.Write("rework/"..key, rw.core:Serialize(value));
	end;

	function data.Load(key, failSafe)
		if (typeof(key) != "string") then return; end;

		if (!string.GetExtensionFromFilename(key)) then
			key = key..".rw";
		end;

		if (file.Exists("rework/"..key, "DATA")) then
			local strData = file.Read("rework/"..key, "DATA");

			return rw.core:Deserialize(strData);
		elseif (failsafe) then
			return failSafe;
		else
			ErrorNoHalt("[Rework] Attempt to load data key that doesn't exist! ("..key..")\n");
		end;
	end;
end;

function data.SaveSchemaData(key, value)
	return data.Save("schemas/"..rw.core:GetSchemaFolder().."/"..key, value);
end;

function data.LoadSchemaData(key, failSafe)
	return data.Load("schemas/"..rw.core:GetSchemaFolder().."/"..key, failSafe);
end;

function data.SavePluginData(key, value)
	return data.SaveSchemaData("plugins/"..key, value);
end;

function data.LoadPluginData(key, failSafe)
	return data.LoadSchemaData("plugins/"..key, failSafe);
end;