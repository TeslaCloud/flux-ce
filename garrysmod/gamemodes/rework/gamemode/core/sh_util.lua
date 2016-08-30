--[[ 
	Rework © 2016 Mr. Meow and NightAngel
	Do not share, re-distribute or sell.
--]]

-- Enumerations
-- DTVars
BOOL_INITIALIZED = 0;

-- End enumerations

function Try(id, func, ...)
	id = id or "Try";
	local result = {pcall(func, ...)};
	local success = result[1];
	table.remove(result, 1);

	if (!success) then
		ErrorNoHalt("[Rework:"..id.."] Failed to run the function!\n");
		ErrorNoHalt(unpack(result), "\n");
	elseif (result[1] != nil) then
		return unpack[result];
	end;
end;