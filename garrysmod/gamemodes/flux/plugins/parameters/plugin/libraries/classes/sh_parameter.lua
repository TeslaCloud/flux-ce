--[[
	Flux © 2016-2017 TeslaCloud Studios
	Do not share or re-distribute before
	the framework is publicly released.
--]]

class "CParameter"

function CParameter:CParameter(uniqueID)
	if (!isstring(uniqueID)) then return end

	self.uniqueID = uniqueID
end

function CParameter:Register()
	return parameters.Register(self.uniqueID, self)
end

function CParameter:GetBar()
	return self.BarData
end

function CParameter:PlayerHas(player)
	return true
end

function CParameter:OnReduce(player)
	self.value = math.Clamp(self.value - 1, self.Min, self.Max)
end

Parameter = CParameter