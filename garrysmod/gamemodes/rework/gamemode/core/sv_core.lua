--[[ 
	Rework © 2016-2017 TeslaCloud Studios
	Do not share or re-distribute before 
	the framework is publicly released.
--]]

DeriveGamemode("sandbox");

oldFileioWrite = oldFileioWrite or fileio.Write;

function fileio.Write(fileName, content)
	local exploded = string.Explode("/", fileName);
	local curPath = "";

	for k, v in ipairs(exploded) do
		if (string.GetExtensionFromFilename(v) != nil) then
			break;
		end;

		curPath = curPath..v.."/";

		if (!file.Exists(curPath, "GAME")) then
			fileio.MakeDirectory(curPath);
		end;
	end;

	oldFileioWrite(fileName, content);
end;

oldServerLog = oldServerLog or ServerLog;

function ServerLog(...)
	oldServerLog(...);
	print("");
end;