--- Ragdoll lets players fall over, be knocked out and get back up, and leaves a ragdoll
-- behind when they die.
-- A player who is down is replaced by a ragdoll of their model and sees through its eyes.
-- Their state is one of the `RAGDOLL_` enums and is changed with `Player:set_ragdoll_state`:
-- a fallen player (`RAGDOLL_FALLENOVER`) gets up with the jump key, a knocked out one
-- (`RAGDOLL_KNOCKEDOUT`) stays down until the state ends, and a dead one (`RAGDOLL_DUMMY`)
-- leaves a corpse that stays for a while after they respawn. Either of the first two can be
-- given a timer that gets the player up by itself, which can be paused and resumed
-- (`Player:set_getup_time`, `Player:pause_getup_time`, `Player:resume_getup_time`); it is a
-- timed action called 'getup', so the player sees it as a progress bar. Damage dealt to
-- the ragdoll is passed on to the player, except for a moment after they have fallen.
--
-- Players use the `fall` and `getup` commands on themselves, staff use `forcefall`,
-- `knockout` and `forcegetup` on others. With the `ragdoll_fall_damage` and
-- `ragdoll_hit_damage` configs, hard falls and heavy hits make players fall over too.
--
-- A knockout is what a stunstick does: `Player:knock_out` puts a player out for a while
-- and `Player:wake_up` brings them to. A knocked out player cannot get up, is not heard
-- over voice chat, cannot switch characters and has no weapons, as nobody on the ground
-- has. With the `ragdoll_knockout_on_damage` config a melee hit (DMG_CLUB) that leaves a
-- player at or below `ragdoll_knockout_health` knocks them out for
-- `ragdoll_knockout_time` seconds, so a schema only has to turn it on. The hooks
-- `PlayerCanKnockOut`, `PlayerKnockedOut` and `PlayerWokeUp` go with it, and
-- `Player:get_knockout_remaining` tells HUDs how long the player stays out.
--
-- Plugins can step in with the server hooks `PlayerCanRagdoll`, `PlayerRagdolled`,
-- `PlayerCanUnragdoll`, `PlayerUnragdolled`, `PlayerCanGetUp`, `PlayerCanRagdollDecay` and
-- `PlayerRagdollCanTakeDamage`, and with the client hook `ShouldFallenHUDPaint`.
-- `Player:is_ragdolled`, `Player:get_ragdoll_state`, `Player:get_ragdoll_entity`,
-- `Player:is_knocked_out`, `Player:get_knockout_remaining` and `Entity:get_ragdoll_owner`
-- work on both realms.
-- @module [Ragdoll]

PLUGIN:set_global('Ragdoll')

require_relative 'sh_enums'
require_relative 'cl_hooks'
require_relative 'sv_plugin'
require_relative 'sv_hooks'

--- Name of the head bone that the view falls back to on models without an 'eyes'
-- attachment.
local head_bone = 'ValveBiped.Bip01_Head1'

--- Finds where the eyes of a ragdoll are: its 'eyes' attachment, or the head bone of
-- models that have no such attachment.
-- @param entity [Entity the ragdoll]
-- @return [Vector position, Angle direction; nothing if neither is found]
local function find_eyes(entity)
  local index = entity:LookupAttachment('eyes')

  if index > 0 then
    local data = entity:GetAttachment(index)

    if data then
      return data.Pos, data.Ang
    end
  end

  local bone = entity:LookupBone(head_bone)

  if bone then
    return entity:GetBonePosition(bone)
  end
end

--- Moves the view to the eyes of the player's ragdoll while they have one and are not
-- drawn in third person.
-- @param client [Player]
-- @param origin [Vector]
-- @param angles [Angle]
-- @param fov [Number]
-- @return [Map view table, or nil if the view is left alone]
function Ragdoll:CalcView(client, origin, angles, fov)
  local view = GAMEMODE.BaseClass:CalcView(client, origin, angles, fov) or {}
  local entity = client:GetDTEntity(ENT_RAGDOLL)

  if !client:ShouldDrawLocalPlayer() and IsValid(entity) and entity:IsRagdoll() then
    local pos, ang = find_eyes(entity)

    if pos then
      view.origin = pos
      view.angles = ang
    end

    return view
  end
end

--- Registers the RagdollState and RagdollEntity data table variables on the player.
-- @param target [Player]
function Ragdoll:PlayerSetupDataTables(target)
  target:DTVar('Int', INT_RAGDOLL_STATE, 'RagdollState')
  target:DTVar('Entity', ENT_RAGDOLL, 'RagdollEntity')
end
