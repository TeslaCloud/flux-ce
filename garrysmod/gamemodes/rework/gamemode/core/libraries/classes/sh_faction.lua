Class "Faction";

function Faction:Faction(id)
	self.uniqueID = id:MakeID();
end;

function Faction:Register()
	faction.Register(self.uniqueID, self);
end;