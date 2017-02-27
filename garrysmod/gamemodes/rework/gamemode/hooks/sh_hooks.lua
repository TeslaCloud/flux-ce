--[[
	Rework © 2016-2017 TeslaCloud Studios
	Do not share or re-distribute before
	the framework is publicly released.
--]]

hook.Remove("PostDrawEffects", "RenderWidgets")
hook.Remove("PlayerTick", "TickWidgets")
hook.Remove("PlayerInitialSpawn", "PlayerAuthSpawn")

do
	local vectorAngle = FindMetaTable("Vector").Angle
	local normalizeAngle = math.NormalizeAngle

	function GM:CalcMainActivity(player, velocity)
		player:SetPoseParameter("move_yaw", normalizeAngle(vectorAngle(velocity)[2] - player:EyeAngles()[2]))

		player.CalcIdeal = ACT_MP_STAND_IDLE

		local baseClass = self.BaseClass

		if (baseClass:HandlePlayerNoClipping(player, velocity) or
			baseClass:HandlePlayerDriving(player) or
			baseClass:HandlePlayerVaulting(player, velocity) or
			baseClass:HandlePlayerJumping(player, velocity) or
			baseClass:HandlePlayerSwimming(player, velocity) or
			baseClass:HandlePlayerDucking(player, velocity)) then
		else
			local len2D = velocity:Length2D()

			if (len2D > 150) then
				player.CalcIdeal = ACT_MP_RUN;
			elseif (len2D > 0.5) then
				player.CalcIdeal = ACT_MP_WALK;
			end
		end

		player.m_bWasOnGround = player:IsOnGround()
		player.m_bWasNoclipping = (player:GetMoveType() == MOVETYPE_NOCLIP and !player:InVehicle())

		return player.CalcIdeal, (player.CalcSeqOverride or -1)
	end
end

do
	local getWeaponHoldtype = rw.anim.GetWeaponHoldType

	-- Called when to translate player activities.
	function GM:TranslateActivity(player, act)
		local animations = player.rwAnimTable

		if (!animations) then
			return self.BaseClass:TranslateActivity(player, act)
		end

		player.CalcSeqOverride = -1

		if (player:InVehicle()) then
			local vehicle = player:GetVehicle()
			local vehicleClass = vehicle:GetClass()

			if (animations["vehicle"] and animations["vehicle"][vehicleClass]) then
				local anim = animations["vehicle"][vehicleClass][1]
				local position = animations["vehicle"][vehicleClass][2]

				if (position) then
					player:ManipulateBonePosition(0, position)
					player.shouldUndoBones = true
				end

				if (isstring(anim)) then
					player.CalcSeqOverride = player:LookupSequence(anim)

					-- Cache the result of LookupSequence for added performance.
					player.rwAnimTable["vehicle"][vehicleClass][1] = player.CalcSeqOverride

					return
				end

				return anim
			else
				local anim = animations["normal"][ACT_MP_CROUCH_IDLE][1]

				if (isstring(anim)) then
					player.CalcSeqOverride = player:LookupSequence(anim)

					player.rwAnimTable["normal"][ACT_MP_CROUCH_IDLE][1] = player.CalcSeqOverride

					return
				end

				return anim
			end
		elseif (player:OnGround()) then
			local weapon = player:GetActiveWeapon()
			local holdType = getWeaponHoldtype(player, weapon)

			if (player.shouldUndoBones) then
				player:ManipulateBonePosition(0, Vector(0, 0, 0))
				player.shouldUndoBones = false
			end

			if (animations[holdType] and animations[holdType][act]) then
				local anim = animations[holdType][act]

				if (istable(anim)) then
					if (hook.Call("ModelWeaponRaised", nil, player, model)) then
						anim = anim[2]
					else
						anim = anim[1]
					end
				elseif (isstring(anim)) then
					player.CalcSeqOverride = player:LookupSequence(anim)

					player.rwAnimTable[holdType][act] = player.CalcSeqOverride

					return
				end

				return anim
			end
		elseif (animations["normal"]["glide"]) then
			return animations["normal"]["glide"]
		end
	end
end

-- todo: proper weapon anims
function GM:DoAnimationEvent(player, event, data)
	if (event == PLAYERANIMEVENT_ATTACK_PRIMARY) then
		if (player:Crouching()) then
			player:AnimRestartGesture(GESTURE_SLOT_ATTACK_AND_RELOAD, ACT_MP_ATTACK_CROUCH_PRIMARYFIRE, true)
		else
			player:AnimRestartGesture(GESTURE_SLOT_ATTACK_AND_RELOAD, ACT_MP_ATTACK_STAND_PRIMARYFIRE, true)
		end

		return ACT_VM_PRIMARYATTACK
	elseif (event == PLAYERANIMEVENT_ATTACK_SECONDARY) then
		return ACT_VM_SECONDARYATTACK
	elseif (event == PLAYERANIMEVENT_RELOAD) then
		if (player:Crouching()) then
			player:AnimRestartGesture(GESTURE_SLOT_ATTACK_AND_RELOAD, ACT_MP_RELOAD_CROUCH, true)
		else
			player:AnimRestartGesture(GESTURE_SLOT_ATTACK_AND_RELOAD, ACT_MP_RELOAD_STAND, true)
		end

		return ACT_INVALID
	elseif (event == PLAYERANIMEVENT_JUMP) then
		player.m_bJumping = true
		player.m_bFirstJumpFrame = true
		player.m_flJumpStartTime = CurTime()

		player:AnimRestartMainSequence()

		return ACT_INVALID
	elseif (event == PLAYERANIMEVENT_CANCEL_RELOAD) then
		player:AnimResetGestureSlot(GESTURE_SLOT_ATTACK_AND_RELOAD)

		return ACT_INVALID
	end
end

do
	local animCache = {}

	function GM:PlayerModelChanged(player, strNewModel, strOldModel)
		if (!strNewModel) then return end

		if (CLIENT) then
			player:SetIK(false)
		end

		if (!animCache[strNewModel]) then
			animCache[strNewModel] = rw.anim:GetTable(strNewModel)
		end

		player.rwAnimTable = animCache[strNewModel]
	end
end

function GM:OnReloaded()
	-- Reload the tools.
	local toolGun = weapons.GetStored("gmod_tool")

	for k, v in pairs(rw.tool:GetAll()) do
		toolGun.Tool[v.Mode] = v
	end

	if (rw.Devmode) then
		for k, v in ipairs(_player.GetAll()) do
			self:PlayerModelChanged(v, v:GetModel(), v:GetModel())
		end
	end
end

-- Utility timers to call hooks that should be executed every once in a while.
timer.Create("OneMinute", 60, 0, function()
	hook.Run("OneMinute")
end)

timer.Create("OneSecond", 1, 0, function()
	hook.Run("OneSecond")
end)

timer.Create("HalfSecond", 1 / 2, 0, function()
	hook.Run("HalfSecond")
end)

timer.Create("LazyTick", 1 / 8, 0, function()
	hook.Run("LazyTick")
end);