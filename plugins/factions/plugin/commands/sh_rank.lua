--- Command that changes the ranks of players in their factions. `/rank promote <target>` and
-- `/rank demote <target>` move players one rank up or down: staff with the 'manage_ranks'
-- permission may do that to anyone, other players only to those whom their own rank lets them
-- promote or demote (see `Factions.can_promote` and `Factions.can_demote`). `/rank set <target>
-- <rank>` puts players into a rank of their faction, named by its index, its ID or its name;
-- it has a permission of its own, 'rank_set', for staff. A rank is changed where the
-- membership comes from: on the item that grants the faction, or in the record of the
-- character for the default faction of its species (see `Player:set_rank`).

CMD.name = 'Rank'
CMD.description = 'command.rank.description'
CMD.category = 'permission.categories.character_management'

--- Finds a rank of a faction by what was typed for it: its index, else its whole ID, else its
-- whole name, ignoring letter case.
-- @param faction_table [Faction]
-- @param word [String the typed rank]
-- @return [Number rank index and Map rank table, or nothing if the faction has no such rank]
local function find_rank(faction_table, word)
  local index = tonumber(word)

  if index and faction_table:get_rank(index) then
    return index, faction_table:get_rank(index)
  end

  local found_index, rank_table = faction_table:find_rank(word)

  if found_index then
    return found_index, rank_table
  end

  local lowered = word:utf8lower()

  for rank_index, rank_data in ipairs(faction_table:get_ranks()) do
    if isstring(rank_data.name) and rank_data.name:utf8lower() == lowered then
      return rank_index, rank_data
    end
  end
end

--- Returns the ID of the rank a player holds after their rank has been changed.
-- @param target [Player]
-- @param fallback [String what to return when the player holds no rank]
-- @return [String]
local function rank_id(target, fallback)
  return target:get_rank_table()?.id ?? fallback
end

--- Tells the targets, the staff and the actor who has been moved in rank. A player who is not
-- staff hears about it as well, since their rank allowed them to do it.
-- @param cmd [Command the subcommand that ran]
-- @param actor [Player the player who ran the command]
-- @param phrase [String language phrase of the message]
-- @param changed [List<Player> the players whose rank has changed]
local function announce(cmd, actor, phrase, changed)
  local arguments = {
    player = get_player_name(actor),
    target = util.player_list_to_string(changed)
  }

  cmd:notify_staff(phrase, arguments)

  if IsValid(actor) and !actor:can('staff') then
    actor:notify(phrase, arguments)
  end
end

local set = CMD:subcommand('set')
set.description = 'command.rank.set.description'
set.syntax = 'command.rank.set.syntax'
set.permission_id = 'rank_set'
set.arguments = 2
set.arg_types = { 'player', 'rank' }

--- Puts every target into the rank of their faction that the second argument names, and
-- notifies the targets and staff. The membership of each target is refreshed first (see
-- `Factions.refresh_membership`), so that the rank is looked up in the faction it is written
-- to. Targets without a character, targets whose faction has no such rank and targets whose
-- items are still loading (see `Player:set_rank`) are left as they are; the actor is told when
-- that is the case for every target.
-- @param actor [Player the player who ran the command]
-- @param targets [List<Player> players matched by the first command argument]
-- @param rank [String rank index, ID or name]
function set:on_run(actor, targets, rank)
  local changed = {}

  for _, target in ipairs(targets) do
    Factions.refresh_membership(target)

    local faction_table = (target:IsBot() or target:is_character_loaded()) and target:get_faction()
    local index, rank_table

    if faction_table then
      index, rank_table = find_rank(faction_table, rank)
    end

    if index and target:set_rank(index) then
      target:notify('notification.rank_changed', { rank = rank_id(target, rank_table.id) })

      table.insert(changed, target)
    end
  end

  if #changed == 0 then
    Flux.Player:notify(actor, 'error.rank.not_found', { rank = rank })

    return
  end

  self:notify_staff('command.rank.set.message', {
    player = get_player_name(actor),
    target = util.player_list_to_string(changed),
    rank = rank
  })
end

local promote = CMD:subcommand('promote')
promote.description = 'command.rank.promote.description'
promote.syntax = 'command.rank.promote.syntax'
promote.arguments = 1
promote.arg_types = { 'player' }

--- Moves every target that the actor may promote one rank up in their faction, and notifies
-- the targets, staff and the actor. The memberships of the targets and of an actor who is not
-- staff are refreshed first (see `Factions.refresh_membership`), so that the check sees the
-- membership the promotion is written to. The actor is told when nobody could be promoted.
-- @param actor [Player the player who ran the command]
-- @param targets [List<Player> players matched by the first command argument]
function promote:on_run(actor, targets)
  local is_staff = !IsValid(actor) or actor:can('manage_ranks')
  local promoted = {}

  if !is_staff then
    Factions.refresh_membership(actor)
  end

  for _, target in ipairs(targets) do
    Factions.refresh_membership(target)

    if (is_staff or Factions.can_promote(actor, target)) and target:promote_rank() then
      table.insert(promoted, target)

      target:notify('notification.promote_rank', { rank = rank_id(target, '') }, Color('lightgreen'))
    end
  end

  if #promoted == 0 then
    Flux.Player:notify(actor, 'error.rank.cannot_promote')

    return
  end

  announce(self, actor, 'command.rank.promote.message', promoted)
end

local demote = CMD:subcommand('demote')
demote.description = 'command.rank.demote.description'
demote.syntax = 'command.rank.demote.syntax'
demote.arguments = 1
demote.arg_types = { 'player' }

--- Moves every target that the actor may demote one rank down in their faction, and notifies
-- the targets, staff and the actor. The memberships of the targets and of an actor who is not
-- staff are refreshed first (see `Factions.refresh_membership`), so that the check sees the
-- membership the demotion is written to. The actor is told when nobody could be demoted.
-- @param actor [Player the player who ran the command]
-- @param targets [List<Player> players matched by the first command argument]
function demote:on_run(actor, targets)
  local is_staff = !IsValid(actor) or actor:can('manage_ranks')
  local demoted = {}

  if !is_staff then
    Factions.refresh_membership(actor)
  end

  for _, target in ipairs(targets) do
    Factions.refresh_membership(target)

    if (is_staff or Factions.can_demote(actor, target)) and target:demote_rank() then
      table.insert(demoted, target)

      target:notify('notification.demote_rank', { rank = rank_id(target, '') }, Color('salmon'))
    end
  end

  if #demoted == 0 then
    Flux.Player:notify(actor, 'error.rank.cannot_demote')

    return
  end

  announce(self, actor, 'command.rank.demote.message', demoted)
end
