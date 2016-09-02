--[[ 
	Rework © 2016 TeslaCloud Studios
	Do not share, re-distribute or sell.
--]]

hook.Remove("PostDrawEffects", "RenderWidgets");
hook.Remove("PlayerTick", "TickWidgets");
hook.Remove("PlayerInitialSpawn", "PlayerAuthSpawn");

function GM:OnReloaded()
	if (SERVER) then
		print("[Rework] OnReloaded hook called serverside.");
	else
		print("[Rework] OnReloaded hook called clientside.");
	end;
end;

local vectorAngle = FindMetaTable("Vector").Angle;
local normalizeAngle = math.NormalizeAngle;

function GM:CalcMainActivity(player, velocity)
	if (CLIENT) then
		player:SetIK(false);
	end;

	local eyeAngles = player.EyeAngles(player)

	player.SetPoseParameter(player, "move_yaw", normalizeAngle(vectorAngle(velocity)[2] - eyeAngles[2]))

	local oldSeqOverride = player.CalcSeqOverride;
	local seqIdeal, seqOverride = self.BaseClass:CalcMainActivity(player, velocity);

	return seqIdeal, oldSeqOverride or seqOverride or -1;
end;

-- Called when to translate player activities.
function GM:TranslateActivity(player, act)
	local model = player:GetModel();

	if (string.find(model, "/player/")) then
		return self.BaseClass:TranslateActivity(player, act);
	end;

	local animations = rw.anim:GetTable(model);

	if (animations) then
		if (player:InVehicle()) then
			local vehicle = player:GetVehicle();
			local vehicleClass = vehicle:GetClass();

			if (animations["vehicle"] and animations["vehicle"][vehicleClass]) then
				local anim = animations["vehicle"][vehicleClass][1];
				local position = animations["vehicle"][vehicleClass][2];

				if (position) then
					player:ManipulateBonePosition(0, position);
				end;

				if (type(anim) == "string") then
					player.CalcSeqOverride = player:LookupSequence(anim);

					return;
				else
					return anim
				end;
			else
				local anim = animations["normal"][ACT_MP_CROUCH_IDLE][1];

				if (type(anim) == "string") then
					player.CalcSeqOverride = player:LookupSequence(anim);

					return;
				end;

				return anim;
			end;
		elseif (player:OnGround()) then
			local weapon = player:GetActiveWeapon();
			local holdType = rw.anim:GetWeaponHoldType(player, weapon);

			if (animations[holdType] and animations[holdType][act]) then
				local anim = animations[holdType][act];

				-- todo: weapon raise system
				if (type(anim) == "table") then
					anim = anim[2]; -- always raised
				end;

				if (type(anim) == "string") then
					player.CalcSeqOverride = player:LookupSequence(anim);
					return;
				end;

				return anim;
			end;
		elseif (animations["normal"]["glide"]) then
			return animations["normal"]["glide"];
		end;
	end;
end;

-- todo: proper weapon anims
function GM:DoAnimationEvent(ply, event, data)
	if (event == PLAYERANIMEVENT_ATTACK_PRIMARY) then
		if ply:Crouching() then
			ply:AnimRestartGesture(GESTURE_SLOT_ATTACK_AND_RELOAD, ACT_MP_ATTACK_CROUCH_PRIMARYFIRE, true)
		else
			ply:AnimRestartGesture(GESTURE_SLOT_ATTACK_AND_RELOAD, ACT_MP_ATTACK_STAND_PRIMARYFIRE, true)
		end
		
		return ACT_VM_PRIMARYATTACK
	elseif (event == PLAYERANIMEVENT_ATTACK_SECONDARY) then
		return ACT_VM_SECONDARYATTACK
	elseif (event == PLAYERANIMEVENT_RELOAD) then
		if ply:Crouching() then
			ply:AnimRestartGesture(GESTURE_SLOT_ATTACK_AND_RELOAD, ACT_MP_RELOAD_CROUCH, true)
		else
			ply:AnimRestartGesture(GESTURE_SLOT_ATTACK_AND_RELOAD, ACT_MP_RELOAD_STAND, true)
		end
		
		return ACT_INVALID
	elseif (event == PLAYERANIMEVENT_JUMP) then
		ply.m_bJumping = true
		ply.m_bFirstJumpFrame = true
		ply.m_flJumpStartTime = CurTime()
	
		ply:AnimRestartMainSequence()
	
		return ACT_INVALID
	elseif (event == PLAYERANIMEVENT_CANCEL_RELOAD) then
		ply:AnimResetGestureSlot(GESTURE_SLOT_ATTACK_AND_RELOAD)
		
		return ACT_INVALID
	end
end