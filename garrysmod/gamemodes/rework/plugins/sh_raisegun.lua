--[[ 
	Rework © 2016 TeslaCloud Studios
	Do not share, re-distribute or sell.
--]]

PLUGIN:SetName("Raise Weapon");
PLUGIN:SetAuthor("Mr. Meow");
PLUGIN:SetDescription("Allows weapons to be lowered and raised by holding R key.");

local playerMeta = FindMetaTable("Player");
local blockedWeapons = {
	"weapon_physgun",
	"gmod_tool",
	"gmod_camera",
	"weapon_physcannon"
}

function playerMeta:SetWeaponRaised(bIsRaised)
	print("Weapon raised: "..tostring(bIsRaised));

	if (SERVER) then
		self:SetNetVar("WeaponRaised", bIsRaised);
	end;
end;

function playerMeta:IsWeaponRaised()
	local weapon = self:GetActiveWeapon();

	if (!IsValid(weapon)) then
		return false;
	end;

	if (table.HasValue(blockedWeapons, weapon:GetClass())) then
		return true;
	end;

	local shouldRaise = plugin.Call("ShouldWeaponBeRaised", self, weapon);

	if (shouldRaise) then
		return shouldRaise;
	end;

	return self:GetNetVar("WeaponRaised", false);
end;

function playerMeta:ToggleWeaponRaised()
	if (self:IsWeaponRaised()) then
		self:SetWeaponRaised(false);
	else
		self:SetWeaponRaised(true);
	end
end;

function PLUGIN:KeyPress(player, key)
	if (key == IN_RELOAD) then
		timer.Create("WeaponRaise"..player:SteamID(), 1, 1, function()
			player:ToggleWeaponRaised();
		end);
	end;
end;

function PLUGIN:KeyRelease(player, key)
	if (key == IN_RELOAD) then
		timer.Remove("WeaponRaise"..player:SteamID());
	end;
end;

function PLUGIN:StartCommand(player, cmd)
	if (!player:IsWeaponRaised()) then
		cmd:RemoveKey(IN_ATTACK + IN_ATTACK2);
	end;
end;

function PLUGIN:ModelWeaponRaised(player, model)
	return player:IsWeaponRaised();
end;

function PLUGIN:PlayerSwitchWeapon(player, oldWeapon, newWeapon)
	player:SetWeaponRaised(false);
end;

if (CLIENT) then
	-- Taken from NutScript. Rewriting needed, duh.
	function PLUGIN:CalcViewModelView(weapon, viewModel, oldEyePos, oldEyeAngles, eyePos, eyeAngles)
		if (!IsValid(weapon)) then
			return;
		end;

		local targetVal = 0

		if (!rw.client:IsWeaponRaised()) then
			targetVal = 100
		end

		local fraction = (rw.client.curRaisedVal or 0) / 100;
		local rotation = Angle(30, -30, -25);
		
		eyeAngles:RotateAroundAxis(eyeAngles:Up(), rotation.p * fraction);
		eyeAngles:RotateAroundAxis(eyeAngles:Forward(), rotation.y * fraction);
		eyeAngles:RotateAroundAxis(eyeAngles:Right(), rotation.r * fraction);

		rw.client.curRaisedVal = Lerp(FrameTime() * 2, rw.client.curRaisedVal or 0, targetVal)

		viewModel:SetAngles(eyeAngles)

		if (weapon.GetViewModelPosition) then
			local position, angles = weapon:GetViewModelPosition(eyePos, eyeAngles)

			oldEyePos = position or oldEyePos
			eyeAngles = angles or eyeAngles
		end
		
		if (weapon.CalcViewModelView) then
			local position, angles = weapon:CalcViewModelView(viewModel, oldEyePos, oldEyeAngles, eyePos, eyeAngles)

			oldEyePos = position or oldEyePos
			eyeAngles = angles or eyeAngles
		end

		return oldEyePos, eyeAngles
	end;
end;