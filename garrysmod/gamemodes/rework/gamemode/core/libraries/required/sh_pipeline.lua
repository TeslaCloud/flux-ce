--[[ 
	Rework © 2016-2017 TeslaCloud Studios
	Do not share or re-distribute before 
	the framework is publicly released.
--]]

--[[
	Pipeline library lets you create systems that register their stuff via folders. 
	It automatically does the boring stuff like converting filenames for you,
	requiring you to write the real thing only.
	Check out sh_item and sh_admin libraries for examples.
--]]

library.New("pipeline", _G);

local stored = pipeline.stored or {};
pipeline.stored = stored;

function pipeline.Register(uniqueID, callback)
	stored[uniqueID] = {
		callback = callback,
		uniqueID = uniqueID
	};
end;

function pipeline.Find(id)
	return stored[id];
end;

function pipeline.Include(pipe, fileName)
	if (!pipe) then return; end;
	if (!isstring(fileName) or fileName:utf8len() < 7) then return; end;

	local uniqueID = (string.GetFileFromFilename(fileName) or ""):Replace(".lua", ""):MakeID();

	if (uniqueID:StartWith("cl_") or uniqueID:StartWith("sh_") or uniqueID:StartWith("sv_")) then
		uniqueID = uniqueID:utf8sub(4, uniqueID:utf8len());
	end;

	if (uniqueID == "") then return; end;

	if (isfunction(pipe.callback)) then
		pipe.callback(uniqueID, fileName, pipe);
	end;
end;

function pipeline.IncludeDirectory(uniqueID, directory)
	local pipe = stored[uniqueID];

	if (!pipe) then return; end;

	if (!directory:EndsWith("/")) then
		directory = directory.."/";
	end;

	local files, dirs = _file.Find(directory.."*", "LUA", "namedesc");

	for k, v in ipairs(files) do
		pipeline.Include(pipe, directory..v);
	end;
end;