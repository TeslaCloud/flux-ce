--- Command that changes the ranks of players in their factions. `/rank promote <target>` and
-- `/rank demote <target>` move players one rank up or down: staff with the 'manage_ranks'
-- permission may do that to anyone, other players only to those whom their own rank lets them
-- promote or demote (see `Factions.can_promote` and `Factions.can_demote`). `/rank set <target>
-- <rank>` puts players into a rank of their faction, named by its index, its ID or its name;
-- it has a permission of its own, 'rank_set', for staff.

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

  for k, v in ipairs(faction_table:get_ranks()) do
    if isstring(v.name) and v.name:utf8lower() == lowered then
      return k, v
    end
  end
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
-- notifies the targets and staff. Targets whose faction has no such rank are left as they
-- are; the actor is told when that is the case for every target.
-- @param actor [Player the player who ran the command]
-- @param targets [List<Player> players matched by the first command argument]
-- @param rank [String rank index, ID or name]
function set:on_run(actor, targets, rank)
  local changed = {}

  for _, v in ipairs(targets) do
    local faction_table = v:get_faction()
    local index, rank_table

    if faction_table then
      index, rank_table = find_rank(faction_table, rank)
    end

    if index then
      v:set_rank(index)
      v:notify('notification.rank_changed', { rank = rank_table.id })

      table.insert(changed, v)
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
-- the targets, staff and the actor. The actor is told when nobody could be promoted.
-- @param actor [Player the player who ran the command]
-- @param targets [List<Player> players matched by the first command argument]
function promote:on_run(actor, targets)
  local is_staff = !IsValid(actor) or actor:can('manage_ranks')
  local promoted = {}

  for _, v in ipairs(targets) do
    if (is_staff or Factions.can_promote(actor, v)) and v:promote_rank() then
      table.insert(promoted, v)

      v:notify('notification.promote_rank', { rank = v:get_rank_name() }, Color('lightgreen'))
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
-- the targets, staff and the actor. The actor is told when nobody could be demoted.
-- @param actor [Player the player who ran the command]
-- @param targets [List<Player> players matched by the first command argument]
function demote:on_run(actor, targets)
  local is_staff = !IsValid(actor) or actor:can('manage_ranks')
  local demoted = {}

  for _, v in ipairs(targets) do
    if (is_staff or Factions.can_demote(actor, v)) and v:demote_rank() then
      table.insert(demoted, v)

      v:notify('notification.demote_rank', { rank = v:get_rank_name() }, Color('salmon'))
    end
  end

  if #demoted == 0 then
    Flux.Player:notify(actor, 'error.rank.cannot_demote')

    return
  end

  announce(self, actor, 'command.rank.demote.message', demoted)
end
