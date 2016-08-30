-- This is a test plugin to drop to plugins folder in the runtime
-- to see that live plugin including actually works.

print("plugin system kinda works prob");

local nextTick = CurTime();

function PLUGIN:Tick()
	if (nextTick < CurTime()) then
		print("tick");
		nextTick = CurTime() + 0.5;
	end;
end;