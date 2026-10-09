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
-- Plugins can step in with the server hooks `PlayerCanRagdoll`, `PlayerRagdolled`,
-- `PlayerCanUnragdoll`, `PlayerUnragdolled`, `PlayerCanGetUp`, `PlayerCanRagdollDecay` and
-- `PlayerRagdollCanTakeDamage`, and with the client hook `ShouldFallenHUDPaint`.
-- `Player:is_ragdolled`, `Player:get_ragdoll_state`, `Player:get_ragdoll_entity` and
-- `Entity:get_ragdoll_owner` work on both realms.
-- @module [Ragdoll]

PLUGIN:set_global('Ragdoll')

require_relative 'sh_enums'
require_relative 'cl_hooks'
require_relative 'sv_plugin'
require_relative 'sv_hooks'

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
    local index = entity:LookupAttachment('eyes')

    if index then
      local data = entity:GetAttachment(index)

      if data then
        view.origin = data.Pos
        view.angles = data.Ang
      end

      return view
    end
  end
end

--- Registers the RagdollState and RagdollEntity data table variables on the player.
-- @param target [Player]
function Ragdoll:PlayerSetupDataTables(target)
  target:DTVar('Int', INT_RAGDOLL_STATE, 'RagdollState')
  target:DTVar('Entity', ENT_RAGDOLL, 'RagdollEntity')
end
