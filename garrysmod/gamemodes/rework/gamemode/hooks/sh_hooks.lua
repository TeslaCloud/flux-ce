--[[ 
	Rework © 2016-2017 TeslaCloud Studios
	Do not share or re-distribute before 
	the framework is publicly released.
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

do
	local vectorAngle = FindMetaTable("Vector").Angle;
	local normalizeAngle = math.NormalizeAngle;

	function GM:CalcMainActivity(player, velocity)
		player:SetPoseParameter("move_yaw", normalizeAngle(vectorAngle(velocity)[2] - player:EyeAngles()[2]))

		player.CalcIdeal = ACT_MP_STAND_IDLE
		player.CalcSeqOverride = -1

		local baseClass = self.BaseClass;

		if (baseClass:HandlePlayerNoClipping(player, velocity) or
			baseClass:HandlePlayerDriving(player) or
			baseClass:HandlePlayerVaulting(player, velocity) or
			baseClass:HandlePlayerJumping(player, velocity) or
			baseClass:HandlePlayerSwimming(player, velocity) or
			baseClass:HandlePlayerDucking(player, velocity)) then
		else
			local len2D = velocity:Length2D();

			if (len2D > 150) then 
				player.CalcIdeal = ACT_MP_RUN; 
			elseif (len2D > 0.5) then 
				player.CalcIdeal = ACT_MP_WALK; 
			end;
		end;

		player.m_bWasOnGround = player:IsOnGround();
		player.m_bWasNoclipping = (player:GetMoveType() == MOVETYPE_NOCLIP && !player:InVehicle());

		return player.CalcIdeal, player.CalcSeqOverride;
	end;
end;

do
	-- Called when to translate player activities.
	function GM:TranslateActivity(player, act)
		local animations = player.rwAnimTable;

		if (!animations) then
			return self.BaseClass:TranslateActivity(player, act);
		end;

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
					return anim;
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

				if (type(anim) == "table") then
					if (hook.Run("ModelWeaponRaised", player, model)) then
						anim = anim[2];
					else
						anim = anim[1];
					end;
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
function GM:DoAnimationEvent(player, event, data)
	if (event == PLAYERANIMEVENT_ATTACK_PRIMARY) then
		if (player:Crouching()) then
			player:AnimRestartGesture(GESTURE_SLOT_ATTACK_AND_RELOAD, ACT_MP_ATTACK_CROUCH_PRIMARYFIRE, true);
		else
			player:AnimRestartGesture(GESTURE_SLOT_ATTACK_AND_RELOAD, ACT_MP_ATTACK_STAND_PRIMARYFIRE, true);
		end;

		return ACT_VM_PRIMARYATTACK;
	elseif (event == PLAYERANIMEVENT_ATTACK_SECONDARY) then
		return ACT_VM_SECONDARYATTACK;
	elseif (event == PLAYERANIMEVENT_RELOAD) then
		if (player:Crouching()) then
			player:AnimRestartGesture(GESTURE_SLOT_ATTACK_AND_RELOAD, ACT_MP_RELOAD_CROUCH, true);
		else
			player:AnimRestartGesture(GESTURE_SLOT_ATTACK_AND_RELOAD, ACT_MP_RELOAD_STAND, true);
		end;

		return ACT_INVALID;
	elseif (event == PLAYERANIMEVENT_JUMP) then
		player.m_bJumping = true;
		player.m_bFirstJumpFrame = true;
		player.m_flJumpStartTime = CurTime();

		player:AnimRestartMainSequence();

		return ACT_INVALID;
	elseif (event == PLAYERANIMEVENT_CANCEL_RELOAD) then
		player:AnimResetGestureSlot(GESTURE_SLOT_ATTACK_AND_RELOAD);

		return ACT_INVALID;
	end;
end;

do
	local animCache = {};

	function GM:PlayerModelChanged(player, sNewModel, sOldModel)
		if (CLIENT) then
			player:SetIK(false);
		end;

		if (!animCache[sNewModel]) then
			animCache[sNewModel] = rw.anim:GetTable(sNewModel);
		end;

		player.rwAnimTable = animCache[sNewModel];
	end;
end;

-- Utility timers to call hooks that should be executed every once in a while.
timer.Create("OneMinute", 60, 0, function()
	hook.Run("OneMinute");
end);

timer.Create("OneSecond", 1, 0, function()
	hook.Run("OneSecond");
end);

timer.Create("HalfSecond", 1 / 2, 0, function()
	hook.Run("HalfSecond");
end);

timer.Create("LazyTick", 1 / 8, 0, function()
	hook.Run("LazyTick");
end);