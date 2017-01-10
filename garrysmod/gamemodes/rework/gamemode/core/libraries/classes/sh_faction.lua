Class "CFaction";

function CFaction:CFaction(id)
	self.uniqueID = id:MakeID();
end;

function CFaction:Register()
	faction.Register(self.uniqueID, self);
end;

Faction = CFaction;