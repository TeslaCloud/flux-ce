--[[ 
	Rework © 2016-2017 TeslaCloud Studios
	Do not share or re-distribute before 
	the framework is publicly released.
--]]

Class "CFaction";

function CFaction:CFaction(id)
	self.uniqueID = id:MakeID();
end;

function CFaction:Register()
	faction.Register(self.uniqueID, self);
end;

Faction = CFaction;