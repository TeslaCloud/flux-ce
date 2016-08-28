--[[ 
	Rework © 2016 Mr. Meow and NightAngel
	Do not share, re-distribute or sell.
--]]

function GM:OnReloaded()
	if (SERVER) then
		print("[Rework] OnReloaded hook called serverside.");
	else
		print("[Rework] OnReloaded hook called clientside.");
	end;
end;