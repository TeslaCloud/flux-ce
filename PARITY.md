# Flux ↔ Catwork feature parity

What the Catwork framework has that the Flux framework does not, as of 2026-10-09
(Flux `6ddd3be6`, Catwork `dd0ae9a`), with a note on each item the Flux `hl2rp` schema
(`64bce22`) already covers.

## Scope and method

- **Compared:** `Catwork/gamemodes/catwork` (framework and its bundled plugins) against this
  repository (`lib`, `gamemode`, `config`, `packages`, `plugins`).
- **Not compared:** the `cwhl2rp` schema on the Catwork side and the `reborn` schema on the Flux
  side.
- **hl2rp:** the list was drawn up against the Flux framework alone, then every item was checked
  against the Flux `hl2rp` schema and its plugins. Where the schema provides the feature the item
  carries an *hl2rp:* note. These features still live in a schema, so another schema does not get
  them.
- **Method:** static reading of both codebases, slice by slice. Nothing was run in game. Every
  "missing" entry was confirmed by searching Flux for the feature under several names; the larger
  ones were re-checked by hand. Entries marked *(unverified)* rest on reading alone where engine
  behaviour matters.
- **Direction:** this is one-way. Things Flux has and Catwork lacks (grid inventories, ActiveRecord,
  roles and permissions, target selectors, multiple currencies, conditions, areas, …) are not listed.

Catwork paths are relative to `gamemodes/catwork/gamemode/` unless they start with `plugins/`.
Flux paths are relative to the repository root.

Each item is tagged **missing** (nothing in the Flux framework) or **partial** (something exists;
the entry says what is lacking). A ticked box means `hl2rp` covers the item; an unticked box with an
*hl2rp:* note means it covers part of it or does not cover it.

## The biggest gaps

1. **Roleplay chat** *(largely covered by hl2rp)*. The framework ships the chatbox machinery but
   no IC/OOC/LOOC classes, no talk radius, and none of `/me`, `/it`, `/w`, `/y`, `/pm`, `/radio`,
   `/roll`, `/event`; on its own every typed line goes to everyone. `hl2rp` adds nearly all of it.
2. **Classes.** Jobs within a faction (wages, limits, loadout, model, class menu) do not exist;
   only dead stubs do.
3. **Recognition** *(largely covered by hl2rp)*. Nothing in the framework; `hl2rp` has a
   recognition plugin with an introduce menu and false names.
4. **Door ownership.** No buying, selling, access lists, parent/child doors or keys weapon.
   `hl2rp` substitutes staff-issued key items.
5. **Damage model.** No limb damage, health regeneration, drowning or prop-kill protection, and
   nothing is dropped on death. Hitgroup scaling and pain sounds exist only in `hl2rp`, hard-coded.
6. **Economy beyond a wallet.** No wages, salesmen, shipments, prop cost or starting cash.
7. **Per-character state.** No generic character data blob, no character flags, no character bans,
   no character limit, no saved position; health and ammo are loaded but never saved.
8. **Client settings.** No per-player settings registry or menu, so nothing is user-toggleable
   (hints, language, theme, HUD options).
9. **Timed actions.** No generic "do X for N seconds with a progress bar and a cancel condition".
10. **Help/directory and quick menu.** No browsable command list, no directory pages, no F1 info
    menu, no contextual quick menu.
11. **Prop protection and sandbox rules.** Physgun, tool and property checks are permission-only;
    there is no entity ownership.
12. **Bundled plugins.** Spawn points, spawn saver, map cleaning, entry quiz and the container tool
    have no counterpart. Emote animations exist in `hl2rp` as a one-animation start.

## What hl2rp already covers

| Feature | hl2rp | Still lacking |
|---|---|---|
| IC, OOC and LOOC chat with a talk radius | `plugins/rpcommands` | cooldowns, IC veto for dead players, an editable `talk_radius` key |
| Whisper and yell | `rpcommands` (volume levels) | nothing of note |
| `/me`, `/it`, `/roll`, `/event`, PM, staff report | `rpcommands`, `enhancedadmin` | `/eventlocal`, `/announce`, `/su`, voicemail, versus rolls |
| Radio with frequencies and eavesdropping | `plugins/radios` | hooks; changing frequency looks broken |
| Proximity voice | `rpcommands` | toggles, dead-player exclusion, voice ban |
| Typing states by chat class | `rpcommands` | radioing, typing noises |
| Recognition, introduce menu, false names | `plugins/recognize` | forgetting, voice panel, on/off switch |
| Attribute points at creation | `plugins/stats` | per-faction bonuses, an attributes tab in the menu |
| Player-to-player search | `plugins/playersearch` | a staff search command |
| Door access by key items | `plugins/doorkeys` | ownership, buying, parent/child doors |
| Hitgroup and weapon damage scaling | `schema/sv_hooks.lua` | config keys, limb damage |
| Pain and death sounds | `schema/sv_hooks.lua` | citizen death sound |
| Hit logging to staff | `plugins/logging` | kills, weapon, remaining health |
| `/sethealth`, `/setarmor`, OOC mute | `enhancedadmin`, `rpcommands` | slay, mutes that survive a reconnect |
| Default currency | `schema/sh_schema.lua` | starting cash |
| Animation classes for CP, Overwatch, vortigaunt, zombie | `schema/sh_animations.lua` | female CP class |
| Emote animations | `plugins/animations` | more than one animation, commands, wall checks |
| Static vignette and colour grade | `schema/cl_hooks.lua` | dynamic vignette, a toggle |

Everything else in this file is absent from `hl2rp` as well. In particular it has no classes, wages,
door ownership, limb damage, character limits or bans, client settings, spawn points, quiz,
salesmen, prop protection, or voice lines (the data file `schema/voicelines.yml` is shipped but
never loaded).

---

## Chat and communication

Flux: `plugins/chatbox`, `plugins/sh_prefixes.lua`, `plugins/displaytyping`.

**Missing**

- [x] **IC / OOC / LOOC chat classes.** Plain text as in-character speech within `talk_radius`,
  `//` global OOC, `.//` and `[[` local OOC, each with its own colour, icon and rules.
  `Chatbox.player_say` sends everything globally. CW: `core/libraries/sv_chatbox.lua:123-223`,
  `core/libraries/cl_chatbox.lua:233-353`.
  *hl2rp:* covered by `rpcommands`: typed text is IC speech within `talk_radius`; `//` and `/ooc`
  are global OOC; `.//`, `[[` and `/looc` are local OOC.
- [x] **Talk radius and per-class ranges.** `talk_radius` config driving IC, LOOC, `/me`, `/it`,
  whisper (a third), yell (double) and local voice.
  *hl2rp:* covered. `talk_radius` is set in code (350), not registered as an editable config key.
  Whisper and yell are volume levels written as `(text)` and `text!!`, scaling both radius and font
  size.
- [ ] **OOC / LOOC cooldowns** (`ooc_interval`, `looc_interval`), staff exempt.
  *hl2rp:* not covered. It has a timed OOC mute (`/gag`) instead.
- [ ] **Speaking veto hooks:** `PlayerCanSayIC` (dead or fallen players cannot speak),
  `PlayerCanSayOOC`, `PlayerCanSayLOOC`.
  *hl2rp:* partly. Only `PlayerCanUseOOC`; dead players can still speak in character.
- [ ] **Roleplay chat commands:** `/me`, `/it`, `/w`, `/y`, `/pm`, `/radio`, `/roll`, `/event`,
  `/eventlocal`, `/announce`, `/su`, `/arequest`, `/setvoicemail`. See the command table below.
  *hl2rp:* mostly covered: `/me`, `/it`, `/whisper`, `/yell`, `/roll`, `/event`, `/message` (alias
  `pm`), `/report` (the `/arequest` equivalent), plus `/its` static scene text. Still missing:
  `/eventlocal`, `/announce`, `/su`, `/setvoicemail`.
- [ ] **Radio pipeline.** `SayRadio` with listeners from `PlayerAdjustRadioInfo`, eavesdroppers in
  talk radius, `PlayerCanRadio`, `PlayerRadioUsed`. CW: `core/libraries/sv_player.lua:1945`.
  *hl2rp:* mostly covered by `radios`: radio items with a frequency, `/r`, `/radio` and `;`, nearby
  eavesdropping. No radio hooks. The frequency dialog sends the old value back to the server
  (`plugins/radios/plugin/cl_hooks.lua`), so changing frequency looks broken.
- [ ] **Voicemail.** Per-character auto-reply returned to anyone who PMs them.
- [ ] **Dice roll** with a player-versus-player mode and the `AdjustRollNumber` hook.
  *hl2rp:* partly. `/roll [max]` exists; no player-versus-player mode or adjust hook.
- [ ] **Voice lines.** Voice groups per faction; an IC message matching a line is replaced by its
  phrase and plays the sound, with a cooldown. CW: `core/libraries/sh_voices.lua`.
  *hl2rp:* not covered. `schema/voicelines.yml` holds the data and no code loads it.
- [ ] **Built-in prefixes:** `//`, `.//`, `[[`, `@` (staff chat), `<sys>` (speak as server),
  `/?` (silent admin command). The prefix registry exists but nothing registers a prefix.
  *hl2rp:* partly. `//`, `.//` and `[[` are registered; `@`, `<sys>` and `/?` are not.
- [ ] **Server-side flood guard** (0.2 s between submissions) and **server-side length limit.**
  `max_message_length` is enforced by the client text entry only.
- [ ] **Message timestamps.**
- [ ] **BB-code colour tags** in rich classes (`[color=…]`, with a tag registry).
- [ ] **Steam avatar inline** on OOC and staff lines.
- [ ] **Post-send hook** with the final listener list (`ChatboxMessageSent`) and a cancellable
  pre-send hook. `AdjustMessageData` runs per listener and cannot cancel.
- [ ] **Console `say`** shown in chat. `CHudChat` is hidden and nothing handles `OnPlayerChat`.
- [ ] **Line-of-sight hearing** (`messages_must_see_player`) and the "looking near the speaker"
  allowance. `Chatbox.can_hear` is distance-only.
  *hl2rp:* partly. `/it` and `/roll` reach players looking near the speaker (`hear_when_look`);
  nothing requires line of sight.
- [ ] **Proximity voice.** `local_voice`, `voice_enabled`, dead and unconscious players excluded,
  per-player voice ban. Flux only checks the `voice` permission.
  *hl2rp:* partly. Voice is cut beyond `talk_radius`; no toggles, no exclusion of dead players, no
  voice ban.

**Partial**

- [ ] **Listener filters.** `Chatbox.add_filter` stores data nothing reads; `PlayerCanHear` can
  force a message through but cannot block one.
- [ ] **Staff chat.** `/staff` exists; there is no superadmin-only channel, no player-to-staff
  request and no `@` shortcut.
  *hl2rp:* adds `/report` for player-to-staff messages. Still no superadmin channel or `@`.
- [x] **Per-class text size.** Small/big font configs exist and nothing uses them.
  *hl2rp:* covered: font size follows the volume level. The small/big font configs are still unused.
- [ ] **Chat icons.** The role icon is supplied by a hook; there is no per-SteamID or per-group
  registry and no whitelisted-faction icon.
- [ ] **Typing indicator.** Flux shows the typed text or a generic label at a fixed range. Lacking:
  per-class states (talking, whispering, yelling, radioing, performing), range matched to the
  class, faction typing noises, suppression for dead or noclipping typists.
  *hl2rp:* mostly covered: talking, whispering, yelling and performing labels with matching ranges.
  Still lacking: radioing, typing noises, suppression for dead or noclipping typists.
- [ ] **Chatbox position and size.** Read from the theme at creation; no runtime move/resize API.
- [ ] **Join/leave announcements.** Shown as popups, not chat lines.

---

## Characters

Flux: `plugins/characters`.

**Missing**

- [ ] **Generic character data.** An arbitrary key/value blob saved with the character
  (`SetCharacterData`). In Flux a value persists only if a migration adds a column.
  CW: `core/libraries/sv_player.lua:4059-4136`.
- [ ] **Generic player data.** `set_player_data` writes a netvar that is never saved and has no
  callers.
- [ ] **Character limit.** One per joinable faction plus `additional_characters`, enforced on both
  sides. `CHAR_ERR_LIMIT` is declared and never returned.
- [ ] **Unique names.** `CHAR_ERR_EXISTS` is declared and never returned.
- [ ] **Character bans.** `/CharBan`, `/CharUnban` (online or offline), "banned" card on the
  selection screen, refusal to load.
- [ ] **Veto hooks on use, switch and delete** (`PlayerCanUseCharacter`,
  `PlayerCanSwitchCharacter`, `PlayerCanDeleteCharacter`, `PlayerCanInteractCharacter`), the block
  on deleting the active character, a request cooldown, and no switching while dead. The select and
  delete receivers call straight through.
- [ ] **Custom buttons and options on character cards.**
- [ ] **Declarative extra creation fields** (`GetPersuasionChoices`): combo or text fields added by
  plugins, validated and stored server-side.
- [ ] **Saved position** (the `spawnsaver` plugin): position, angles and map saved on unload and
  restored on the same map; `spawn_where_left`.
- [ ] **Server-forced character menu** (reopen it for a player from the server).

**Partial**

- [ ] **Health, armor and ammo persistence.** `character.health` and `character.ammo` are applied on
  load but nothing writes them; the `ammunitions` table is never filled; armor has no column.
- [ ] **Name entry and validation.** One free-text name with a length check. Lacking: forename and
  surname fields, no-digits/no-punctuation/vowel rules, auto-capitalisation.
- [ ] **Self-service description.** Editable from the inventory menu; no `/CharPhysDesc` command
  (the `physdesc` alias points at the staff-only `CharSetDesc`), no default description chain or
  override hook.
- [ ] **Creation stages.** Stages are collected once when the panel opens. Lacking: per-stage
  conditions evaluated against the choices so far, and a removal API.
- [ ] **Selection screen.** Lacking: grouping and labels by faction, a details tooltip, label and
  tooltip hooks. The networked character payload carries no faction.
- [ ] **Bots.** They get a faction and a model but no character.

---

## Factions, ranks and classes

Flux: `plugins/factions`.

**Missing**

- [ ] **Class system.** Classes bound to factions with colour, model, scaled limit, wages, default
  weapons and ammo, granted flags, default class, team per class. Flux has only
  `Faction.default_class` (never read), `char.char_class` (no column) and `CHAR_ERR_CLASS`
  (unused). CW: `core/libraries/sh_class.lua`.
  *hl2rp:* not covered. Its factions set `default_class`, which nothing reads.
- [ ] **Class menu, `/SetClass`, change cooldown** (`change_class_interval`) and limit enforcement.
- [ ] **Class stage in character creation.**
- [ ] **Faction and rank population limits** (`limit`, `playerLimit`, scaled to player count), and
  the per-player per-faction character maximum.
- [ ] **Faction NPC relationships** (`entRelationship`: like, fear, hate per NPC class).
- [ ] **Faction/rank maximum health and armor** applied on spawn.
- [ ] **Faction respawn inventory** (`respawnInv` topped up on each spawn).

**Partial**

- [ ] **Ranks.** Ordered ranks with a name prefix exist. Lacking: per-rank model, weapons, class and
  limit; a default-rank flag; in-faction promote/demote authority (`canPromote`, `canDemote`).
  Promotion is a staff command only.
- [ ] **Faction fields.** Lacking: `weapons` loadout, `GetModel` callback, `OnCreation` veto at
  creation, explicit single-gender factions, default citizen model lists. `Faction.phys_desc` is
  defined and never applied.
- [ ] **Faction transfer.** `/SetFaction` works; the target faction cannot veto it and there is no
  data argument.

---

## Flags and per-character permissions

Flux: `plugins/admin` (roles and permissions on the user).

- [ ] **missing — Per-character flags.** Permissions stored on the character rather than the
  player, plus flags granted by class. No `/CharGiveFlags`, `/CharTakeFlags`, `/CharSetFlags`,
  `/CharCheckFlags`.
- [ ] **partial — Granting permissions by command.** Per-user and temporary permissions exist but
  only through the permission editor UI. No equivalent of `/PlyGiveFlags`, `/PlyTakeFlags`,
  `/PlySetFlags`, `/PlyGiveAccess`, `/PlyTakeAccess`.
- [ ] **missing — Default flags** for new characters (`default_flags`).
- [ ] **missing — Universal door access** (flag `D`).
- [ ] **partial — `spawn_chairs`.** Registered as a permission and never checked.
- [ ] **missing — Player-facing flag list** (a directory page of flags and what they do).

---

## Attributes

Flux: `plugins/attributes` (models, levels, progress, boosts; no views).

- [ ] **missing — Attributes UI.** No menu tab, bar or readout anywhere.
  CW: `core/derma/cl_attributes.lua`.
- [x] **partial — Attribute points at creation.** The server accepts and clamps
  `char_data.attributes`. Lacking: the creation stage, a point budget
  (`default_attribute_points`), per-faction scaling, an "on creation screen" flag.
  *hl2rp:* covered by `stats`: a creation stage with a point budget, re-validated on the server.
  `FACTION.stats` bonuses are declared and unused.
- [ ] **partial — Boosts.** Timed boosts and multipliers exist. Lacking: identifiers, manual
  removal or clear, indefinite boosts, the `Fraction` scaling helper.
- [ ] **partial — Hooks and access.** Only `AttributeRegistered` is fired. Lacking: progress and
  update hooks, gradual progress, per-faction or per-class attribute access.
- [ ] **missing — `/CharCheckAtts`.**
- [ ] **missing — Config:** `scale_attribute_progress`, `save_attribute_boosts`.

---

## Recognition

Nothing in the Flux framework beyond the `GetPlayerName` hook, which is also called without a
viewer argument when formatting notifications. `hl2rp` implements that hook in its `recognize`
plugin.

- [x] **Recognition levels per character**, viewer-dependent names, and the unrecognised fallback
  (description or `unrecognised_name`). CW: `core/libraries/sv_player.lua:2090-2483`,
  `core/libraries/cl_player.lua:207-512`.
  *hl2rp:* covered by `recognize`: one level, saved per character, with optional false names.
  Strangers show as "stranger" on the target ID and as a description snippet in chat.
- [x] **Introduce menu** (recognise by look, whisper, talk or yell range).
  *hl2rp:* covered: F2 menu for the looked-at player or whisper, talk and yell range, plus an entry
  in the player interaction menu.
- [ ] **Saved versus session recognition**, forget on death, clear in both directions.
  *hl2rp:* partly. Always saved. No forgetting on death; `remove_recognize` exists and nothing calls
  it.
- [ ] **Consumers:** target ID, chat names, scoreboard sorting and anonymised entries, voice panel.
  *hl2rp:* mostly covered: target ID, IC chat names and the scoreboard. The voice panel is not.
- [ ] **Config:** `recognise_system`, `save_recognised_names`, `unrecognised_name`.
  *hl2rp:* partly. Only `recog_must_see`; no on/off switch.

---

## Damage, death and health

Flux: `GM:EntityTakeDamage` only forwards a notification; `GM:DoPlayerDeath` is empty.

**Missing**

- [ ] **Hitgroup damage scaling** (`scale_head_dmg`, `scale_chest_dmg`, `scale_limb_dmg`), head-hit
  sound muffling and view punch. CW: `hooks/sv_hooks.lua:4617`.
  *hl2rp:* partly. Hard-coded: every non-torso hit is doubled and each HL2 weapon has a fixed
  multiplier. No config keys, no head-hit effects.
- [ ] **Limb damage.** Per-hitgroup damage stored on the character and networked; leg damage slows
  movement, arm damage slows lock/unlock and misfires weapons, a leg shot can knock the player over,
  healing heals limbs; the body diagram on the HUD. CW: `core/libraries/sh_limb.lua`.
  *hl2rp:* not covered. It only names limbs in combat messages.
- [ ] **Armor rules** (absorption, `armor_chest_only`).
- [x] **Pain and death sounds** by gender and hitgroup.
  *hl2rp:* covered: gendered citizen pain lines by hitgroup, Civil Protection and Overwatch pain and
  death sounds, moaning at low health. Citizens have no death sound.
- [ ] **Health regeneration** (`health_regeneration_enabled`).
- [ ] **Drowning** (stamina drain when submerged, then damage).
- [ ] **Prop-kill protection** (`prop_kill_protection`): no damage from recently spawned, held or
  dropped props.
- [ ] **Damage pipeline extras:** view punch on damage, crush-damage threshold, blood effects and
  decals, vehicle damage scaling.
- [ ] **Damage and kill logging.**
  *hl2rp:* partly. `logging` prints each hit to staff consoles; no kills, weapon or remaining
  health.
- [ ] **Weapons dropped on death** as items, ammo cleared, frags and deaths counted.
- [ ] **Belongings.** A lootable entity left when a corpse holding items or cash is removed.
  (Catwork's framework never flags a corpse for this itself; a schema has to.)
- [ ] **Per-death respawn adjustment** (`PlayerAdjustDeathInfo`) and "stay dead" conditions.
- [ ] **Fake death** (`SetFakingDeath`).
- [ ] **Hooks to veto or modify damage.** `PlayerTakeDamage` ignores its return value.

**Partial**

- [ ] **Fall damage.** A formula and `FLGetFallDamage` exist. Lacking: `scale_fall_damage`,
  wood-breaks-fall, fall-over on a hard landing, damage to the legs.
- [ ] **Spawn reset.** Lacking: weapon-raise reset, flashlight off, forced-animation clear,
  re-applying worn items beyond `on_loadout`.
- [ ] **Hit position lookup.** `Entity:get_hitgroup_from_pos` returns a hitbox index, not a
  `HITGROUP_*`, has no nearest-bone fallback, and has no callers.

---

## Ragdoll and knockout

Flux: `plugins/ragdoll`.

- [ ] **missing — Knocked-out state** (`RAGDOLL_KNOCKEDOUT`): no hearing, speaking, switching
  character or standing up.
- [ ] **missing — Auto get-up timer** with pause and resume.
- [ ] **missing — Veto and notify hooks:** `PlayerCanRagdoll`, `PlayerCanUnragdoll`,
  `PlayerRagdolled`, `PlayerUnragdolled`, `PlayerCanGetUp`, `PlayerCanRagdollDecay`.
- [ ] **missing — Damage immunity** after ragdolling (`ragdoll_immunity_time`).
- [ ] **missing — State carried through the ragdoll:** health, armor, eye angles, move type, active
  weapon, bodygroups; leaving a vehicle; fire transfer.
- [ ] **missing — Decay for ragdolls of disconnected players** and a configurable
  `body_decay_time` (Flux uses a fixed 120 s).
- [ ] **missing — Ragdoll kept in the owner's PVS.**
- [ ] **missing — Fall-over from damage or falls**, a `/fall` cooldown, refusal in vehicles.
- [ ] **missing — Ragdoll dragging** with its protections (see pickup objects).
- [ ] **partial — Client accessors.** `is_ragdolled` and `get_ragdoll_entity` are server-only.
- [ ] **partial — Ragdoll view.** Lacking: mouse-look while down and the fade/blur treatment.

---

## Weapons and loadout

- [ ] **missing — Hands weapon.** Flux gives stock `weapon_fists`. Lacking: door knocking, punch
  knockout, punch stamina cost, and the punch hooks. CW: `core/entities/weapons/cw_hands`.
  *hl2rp:* has only `fl_punch`, a console command that lets Overwatch knock a player over.
- [ ] **missing — Keys weapon** with timed lock and unlock. CW: `core/entities/weapons/cw_keys`.
  *hl2rp:* uses key items instead (see doors).
- [ ] **missing — Faction, rank and class loadouts**; `give_hands`, `give_keys`; temporary spawn
  weapons and ammo tracked per player.
- [ ] **missing — Fire gating** (`PlayerCanFireWeapon`): melee stamina, shoot-after-raise delay,
  arm-damage misfire.
- [ ] **missing — Weapon pickup rule** (look at it and hold USE), and the dropped-weapon hint.
- [ ] **missing — Weapon and ammo snapshot/restore** (`GetWeapons`/`SetWeapons`, `SetAmmo`) and
  **light spawn** (respawn in place keeping state).
- [ ] **missing — Gear on body.** Holstered weapons and accessories shown on a bone, hidden while
  in hand, following the ragdoll. CW: `core/entities/entities/cw_gear`.
- [ ] **missing — Engine-method hooks:** `PlayerGivenWeapon`, `PlayerCanBeGivenWeapon`,
  `PlayerFireWeapon`, `PlayerAdjustBulletInfo`, `PlayerHealthSet`, `PlayerArmorSet`.
- [ ] **missing — Gravity gun rules** (punt toggle, what non-staff may pick up).
- [ ] **missing — Third-party weapon-base compatibility** (FAS2, CW2.0, SXBASE).
- [ ] **partial — Weapon raise.** Lacking: sprint lowers the weapon, auto-raise for scoped weapons,
  always-raised weapons, a quick-raise key, a global on/off switch, per-item lowered position.
- [ ] **partial — Weapon select.** Lacking the info box (item description, clip and reserve ammo,
  SWEP instructions).
- [ ] **partial — Weapon items.** Lacking: unloading a weapon lying in the world, melee/throwable
  classification, holster and drop hooks, ammo type discovery, clip counts in the tooltip, weapon
  print name taken from the item.
- [ ] **partial — Ammo items.** Always gives ammo. Lacking: the compatible-weapon check and partial
  boxes.
- [ ] **partial — Hands view model.** Lacking a per-model override registry and presets.

---

## Items and inventory

Flux: `plugins/items`, `plugins/inventory`. The grid inventory is a deliberate redesign; weight is
listed because items define it and nothing enforces it.

- [ ] **missing — Destroy action** with confirmation, `OnDestroy` and veto hooks.
- [ ] **missing — Destructible item and cash entities** (health, destroy effect, hooks, cleanup
  when out of the world).
- [ ] **missing — Drop ownership by character.** Dropped items and cash remember the owning
  character; another character of the same player cannot take them.
- [ ] **missing — Alcohol base and drunk state** (stacking timer, attribute boosts, view sway).
  *hl2rp:* not covered. Its vodka, gin, rum and whiskey are plain consumables.
- [ ] **missing — `/DropWeapon`, `/InvAction`.** Both are UI-only in Flux.
- [ ] **missing — Admin search** (`/PlySearch`). `Player:open_player_inventory` exists and nothing
  calls it.
  *hl2rp:* partly. `playersearch` lets a player search another from behind through
  `open_player_inventory`; the target is asked and may allow or resist. There is still no staff
  command.
- [ ] **partial — Carrying capacity by weight.** `weight` and `get_weight` exist; nothing reads
  them. No weight or space limit, bars or tooltips.
- [ ] **partial — Item entity callbacks.** Lacking per-item think, draw, spawn and remove callbacks,
  and bodygroups on the dropped entity.
- [ ] **partial — Item data networking.** Whole `data` table sent, new instances broadcast to all.
  Lacking per-field privacy, observers and batching.
- [ ] **partial — Accessories.** Equip slots exist; nothing is shown on the body.
- [ ] **partial — Bags.** Bag items hold items only, not money.
- [ ] **partial — Storage flags on items** (`allowStorage`, `allowGive`, …). Achievable through
  `can_transfer`; no declarative flags.
- [ ] **missing — Item `cost`.** Registered and never read.

---

## Storage and world containers

Flux: `plugins/containers`.

- [ ] **missing — Passwords and breaching.**
- [ ] **missing — Custom name and message per container.**
- [ ] **missing — Loot fill** (random items by category and scale) and the rare-item flag.
- [ ] **missing — Container tool** (fill, message, name, password).
- [ ] **missing — Contents spilled** when a container is removed. Flux unregisters the inventory;
  the item instances appear to be orphaned *(unverified)*.
- [ ] **missing — One-sided (take-only) storage.**
- [ ] **missing — Commands:** `/ContFill`, `/ContSetName`, `/ContTakeName`, `/ContSetMessage`,
  `/ContSetPassword`, `/ContTakePassword`.
- [ ] **partial — Model table.** About 40 models against Catwork's 70.

---

## Economy

Flux: `plugins/currencies`.

- [ ] **missing — Wages.** Periodic pay by class with five adjust and veto hooks;
  `wages_interval`, `wages_name`. CW: `core/sv_kernel.lua:806`.
- [ ] **missing — Salesmen.** Placeable NPC vendors: buy and sell lists, price overrides, stock,
  cash pool, faction/class/flag restrictions, response lines, editor UI, persistence.
  CW: `plugins/salesmen` (about 2,200 lines).
- [ ] **missing — Shipments.** A crate of several instances of one item.
- [ ] **missing — Starting cash** (`default_cash`). Records start at 0.
- [ ] **missing — Dropped money persistence** (the `savecash` plugin). `fl_money` is never saved.
- [ ] **missing — Prop cost** (`scale_prop_cost`) with refund on quick removal.
- [x] **missing — `default_currency`.** The three money commands read this config key; the
  framework neither defines it nor registers a currency.
  *hl2rp:* covered: the schema registers `tokens` and sets it as the default.
- [ ] **missing — Money in the placeholder system** (`ParseData` cash formatting).

---

## Doors

Flux: `plugins/doors` (staff-edited properties and a condition tree for who may lock).

**Missing**

- [ ] **Ownership.** Buy, sell with refund, `door_cost`, `max_doors`, unsellable doors.
  CW: `hooks/sv_nethooks.lua:214-326`, `core/libraries/sv_player.lua:1897-2655`.
- [ ] **Access lists.** Per-character basic and complete access granted by the owner.
  *hl2rp:* partly, by a different mechanism. `doorkeys` adds key items bound to doors; whoever
  carries a key may lock and unlock, and keys can be copied and handed over. Keys are issued by
  staff from the door menu.
- [ ] **Ownable, unownable, hidden and false doors**, `default_doors_hidden`.
- [ ] **Parent/child doors.** Shared access and text, buying the group, double-door detection.
- [ ] **Owner door menu** (F2): text, sharing, sell, player access list.
- [ ] **Second text line and status text** ("can be purchased", owner text).
- [ ] **Breach helpers:** blast down, bash in, open away from a position, door state queries.
- [ ] **Use-to-open at range** with a `PlayerCanUseDoor` veto.
- [ ] **Door commands** (12): `/DoorLock`, `/DoorUnlock`, `/DoorSetOwnable`, `/DoorSetUnownable`,
  `/DoorSetAllOwnable`, `/DoorSetAllUnownable`, `/DoorSetHidden`, `/DoorSetFalse`, `/DoorSetParent`,
  `/DoorSetChild`, `/DoorUnparent`, `/DoorResetParent`. The Flux plugin has no commands.
- [ ] **Door tools:** `doortool`, `doorparent`.

**Partial**

- [ ] **Locking.** Instant via sprint+use or the menu. Lacking the timed action
  (`lock_time`, `unlock_time`) and generic lock hooks for non-door entities.
- [ ] **State persistence.** Locked state is saved; open/closed state is not.

---

## Sandbox rules, ownership and map entities

- [ ] **missing — Entity ownership ("property").** Entities owned by a character, disabled on
  character switch or disconnect, returned on rejoin, removed after a delay, counted per class.
  CW: `core/libraries/sv_player.lua:860-1069`.
- [ ] **missing — Prop protection** (`enable_prop_protection`) across physgun, freeze, tools and
  remover.
- [ ] **partial — Physgun.** `GM:PhysgunPickup` returns true for any entity given the permission.
  Lacking: map props, player ragdolls, players, vehicles with drivers, unfreeze rules.
- [ ] **partial — Tools.** Per-tool permission only. Lacking target-based rules and the
  dynamite/duplicator ban.
- [ ] **partial — Properties and driving.** Gated client-side by the context menu permission;
  no server-side `CanProperty` or `CanDrive`.
- [ ] **partial — Spawn menu.** Permission-based. Lacking the alive-and-standing check.
- [ ] **missing — Map entity bookkeeping** (is-map-entity flag, start position).
- [ ] **missing — Map cleaning** (the `cleanedmaps` plugin): removes chargers, map weapons and
  optionally map physics props.
- [ ] **missing — Chair handling:** seat swap for stock chair props, exit rules, using entities
  from a seat.
- [ ] **missing — Spray rules** (`disable_sprays`), **`gm_save` / admin cleanup blocking**,
  **post-process lockout.**
- [ ] **missing — Line-of-sight helpers** (`CanSeeEntity`, `CanSeePlayer`, `CanSeePosition`) and
  **`GetRealTrace`.**

---

## Administration

Flux: `plugins/admin`.

**Missing**

- [ ] **IP bans.** Bans are SteamID-only and the table has no address column.
- [ ] **Ban list UI** (browse, time left, unban).
- [ ] **Configurable ban message** with time left (`banned_message`).
- [ ] **`/PlySlay`, `/PlySetHealth`, `/PlyTeleportTo`** (move A to B), **`/PlyMute`**,
  **`/PlySearch`**, **`/Announce`.**
  *hl2rp:* partly: `/sethealth`, `/setarmor`, and `/gag` with `/ungag` for OOC mutes (kept in
  unsaved player data, so a mute ends on reconnect). Slay, teleport-to, search and announce are
  still missing.
- [ ] **Server-wide colour modify** with a system page, persistence and join sync.
  `plugins/cl_colormod.lua` is a client-only API.
- [ ] **External group systems** (`use_own_group_system`). Flux always overrides
  `GetUserGroup`, `IsAdmin` and `IsSuperAdmin`; there is no CAMI support.
- [ ] **Per-staff log feed toggle, log severities, dated log files, a hook per log line.**
- [ ] **Player status listing** (IDs, names, addresses).

**Partial**

- [ ] **Offline bans.** `Bolt:ban` accepts a SteamID string, but `/ban` resolves only online
  players.
- [ ] **Group management.** Lists connected players only. Lacking a list by role with offline
  members and offline demotion.
- [ ] **Player management.** Role and permission editing only. Lacking quick actions (kick, ban,
  teleport) and the scoreboard click menu.
- [ ] **Voice ban.** Possible through the permission editor; no command.
- [ ] **`/respawn`.** Refuses living targets; Catwork respawns them in place.
- [ ] **`/changelevel`.** No map-exists check and no save first.
- [ ] **Admin ESP.** Players only, and only while noclipping. Lacking: items, salesmen, static
  props and spawn points; weapon and status lines; per-category toggles.

---

## Command system

Flux: `packages/flow/lib/sh_command.lua`.

- [ ] **missing — Per-command cooldown.**
- [ ] **missing — State flags** (`CMD_DEAD`, `CMD_VEHICLE`, `CMD_RAGDOLLED`, `CMD_FALLENOVER`,
  `CMD_KNOCKEDOUT`). Each Flux command checks `Alive()` itself.
- [ ] **missing — Per-command faction restriction.**
- [ ] **missing — Hiding or removing a command at runtime.**
- [ ] **missing — Post-run hook** (`PostCommandUsed`).
- [ ] **missing — Browsable command list.** Flux has as-you-type suggestions only.
- [ ] **missing — Commands bound to tool clicks** (`leftClickCMD` and friends).
- [ ] **missing — Death code** (`CMD_DEATHCODE`: a one-time authenticated code that lets a
  knocked-out player run a command, consumed on use).

### Catwork commands with no Flux command

| Area | Commands |
|---|---|
| Chat | `Su`, `Announce`, `EventLocal`, `SetVoicemail` (`A` maps to `/staff`). Only in hl2rp: `Me`, `It`, `W`, `Y`, `PM`, `Radio`, `Roll`, `Event`, `ARequest` (as `/report`) |
| Characters | `CharBan`, `CharUnban`, `CharCheckAtts`, `CharCheckFlags`, `CharGiveFlags`, `CharTakeFlags`, `CharSetFlags`, `CharPhysDesc`, `CharTie`, `SetClass` |
| Players | `PlyGiveFlags`, `PlyTakeFlags`, `PlySetFlags`, `PlyGiveAccess`, `PlyTakeAccess`, `PlySlay`, `PlyTeleportTo`, `PlyVoiceBan`, `PlyVoiceUnban`, `PlySearch`. Only in hl2rp: `PlySetHealth` (as `/sethealth`), `PlyMute` (as `/gag`) |
| Server | `CfgSetVar`, `CfgListVars`, `PluginLoad`, `PluginUnload` |
| Items | `DropWeapon`, `InvAction`, `StorageClose`, `StorageGiveCash`, `StorageTakeCash`, `StorageGiveItem`, `StorageTakeItem` (the storage ones are net messages in Flux) |
| Containers | `ContFill`, `ContSetName`, `ContTakeName`, `ContSetMessage`, `ContSetPassword`, `ContTakePassword` |
| Salesmen | `SalesmanAdd`, `SalesmanEdit`, `SalesmanRemove` |
| Doors | the twelve `Door*` commands above |
| World | `SpawnPointAdd`, `SpawnPointRemove`, `AreaAdd`, `AreaRemove`, `TextAdd`, `TextRemove`, `AdvertAdd`, `AdvertRemove`, `MapSceneAdd`, `MapSceneRemove`, `Observer` (tool or bind only in Flux) |
| Emotes | `AnimCheer`, `AnimWave`, `AnimDeny`, `AnimMotion`, `AnimIdle`, `AnimSit`, `AnimPant`, `AnimThreat`, `AnimLean`, `AnimSitWall`, `AnimPantWall`, `AnimWindow` |

---

## Configuration

Flux: `lib/config.lua`, `config/*.yml`, plugin `config.yml` files.

**System**

- [ ] **missing — Per-map values.** One global config file for all schemas and maps.
- [ ] **missing — Static, private and needs-restart flags.** Flux has only `hidden`. The editor's
  `fl_config_change` sets any key (including `root_steamid`) and announces the raw value.
- [ ] **missing — Reset to default.**
- [ ] **missing — Config commands** (`CfgSetVar`, `CfgListVars`).
- [ ] **missing — Value substitution in text** (`$key$`).
- [ ] **missing — Global versus per-schema keys.**

**Catwork keys with no Flux key**

- Chat and voice: `talk_radius` (set in code by hl2rp), `ooc_interval`, `looc_interval`, `messages_must_see_player`,
  `chat_multiplier`, `enable_looc_icons`, `voice_enabled`, `local_voice`
- Characters: `additional_characters`, `default_physdesc`, `default_flags`,
  `change_class_interval`, `recognise_system`, `save_recognised_names`, `unrecognised_name`,
  `spawn_where_left`
- Attributes: `default_attribute_points`, `scale_attribute_progress`, `save_attribute_boosts`
- Economy: `cash_enabled`, `default_cash`, `cash_weight`, `cash_space`, `wages_interval`,
  `wages_name`, `scale_prop_cost`
- Inventory: `default_inv_weight`, `default_inv_space`, `enable_space_system`, `block_inv_binds`,
  `block_cash_binds`, `block_fallover_binds`
- Damage: `scale_head_dmg`, `scale_chest_dmg`, `scale_limb_dmg`, `scale_fall_damage`,
  `limb_damage_system`, `armor_chest_only`, `wood_breaks_fall`, `damage_view_punch`,
  `ragdoll_immunity_time`, `prop_kill_protection`, `health_regeneration_enabled`,
  `body_decay_time`, `fade_dead_npcs`
- Weapons: `raised_weapon_system`, `shoot_after_raise_time`, `sprint_lowers_weapon`,
  `quick_raise_enabled`, `custom_weapon_color`, `give_hands`, `give_keys`, `enable_gravgun_punt`,
  `take_physcannon`
- Doors: `door_cost`, `max_doors`, `lock_time`, `unlock_time`, `default_doors_hidden`,
  `doors_save_state`
- Entities: `enable_prop_protection`, `enable_map_props_physgrab`, `use_opens_entity_menus`,
  `force_entity_menus`, `entity_handle_time`, `target_id_delay`, `remove_map_physics`
- HUD: `enable_crosshair`, `enable_vignette`, `enable_heartbeat`, `enable_headbob`,
  `use_free_aiming`, `draw_intro_bars`, `clockwork_intro_enabled`, `enable_mouth_move`,
  `disable_sprays`, `hint_interval`
- Time: `minute_time`, `use_local_machine_date`, `use_local_machine_time`
- Admin and themes: `use_own_group_system`, `banned_message`, `modify_themes`, `default_theme`

---

## Plugin system, database, networking and kernel

- [ ] **partial — Disabling plugins.** `Plugin.is_disabled` exists and `disabled_plugins` is loaded
  at boot, but nothing consults the one or writes the other. No command, no UI.
  CW: `core/libraries/sh_plugin.lua:189-297`, `core/system/sh_manage_plugins.lua`.
- [ ] **missing — Nested plugins** and the parent/child disable cascade.
- [ ] **missing — MySQL reconnect.** No `setAutoReconnect` and no retry after a failed connect.
- [ ] **missing — Multiple named database connections.**
- [ ] **missing — Database failure shown to clients.**
- [ ] **missing — Chunked transfer.** `Cable.send` is one net message (64 KB, 16-bit table length);
  Catwork splits large payloads. CW: `core/libraries/sh_transfer.lua`.
- [ ] **partial — Netvars.** Lacking: owner-only vars (`sync_nv` re-sends every stored var to every
  joining player, so a privately sent value reaches late joiners), a nested-function check, and
  change callbacks on the client.
- [ ] **missing — In-game clock and calendar.** Advances every `minute_time`, saved, networked,
  `TimePassed` hook, 12/24 h display. `sh_time`/`sh_date` are real-world utility classes.
  CW: `core/libraries/sh_datetime.lua`.
- [ ] **missing — Content registration.** No `resource.AddWorkshop` or `resource.AddFile` anywhere,
  no map-to-Workshop lookup, no collection helper.
- [ ] **missing — Condition timers.** Call back after N seconds only if a predicate holds, or while
  the player keeps looking at an entity. CW: `core/libraries/sv_player.lua:1235-1284`.
- [ ] **partial — Timed actions.** `set_action` names the current action. Lacking: duration,
  completion callback, priority, progress getter, a shared progress bar. The get-up bar is
  hand-rolled.
- [ ] **missing — Server-driven client sounds** (named looping sound with fade, one-shot).
- [ ] **missing — Server-initiated prompts** (`RequestString`, `RequestConfirmation`, `Message`
  with a server callback). CW: `core/libraries/sh_dermarequest.lua`.
- [ ] **missing — Server opening or closing a player's tab menu; running a console command on a
  client.**
- [ ] **missing — Event switches** (`cw.event`: let a schema turn built-in effects off).
- [ ] **partial — Flat-file data.** Lacking: server-side exists and directory listing, the `..`
  guard, corrupt-file recovery, a type-preserving encoder.
- [ ] **partial — Console output levels.** `Flux.print` and `dev_print` only; no warning/error
  levels or verbosity setting.
- [ ] **partial — Text placeholders.** `string.fmt` and `t()` exist. Lacking automatic key-binding,
  config and money placeholders.
- [ ] **partial — Save cycle.** Lacking a save on `ShutDown` and a post-save hook.
- [ ] **partial — Per-player info table** rebuilt each think so plugins can adjust run speed, jump
  power and wages; backwards movement penalty.

---

## Language

- [ ] **missing — Per-client language choice.** Flux follows `gmod_language` only.
- [ ] **missing — Per-phrase fallback to English.** A missing phrase returns its key.
- [ ] **missing — Language display names** (needed for a picker).

---

## HUD and screen effects

Flux: `packages/flow/hooks/cl_hooks.lua`, `packages/flow/lib/cl_*.lua`, single-file client plugins.

**Missing**

- [ ] **F1 info menu.** Blurred overlay with date and time, bars, player info, limb diagram and the
  quick menu. `GM:ShowHelp` is an empty stub.
- [ ] **Player info box and registry** (money, wages, name, class).
- [ ] **Date and time line** with a 12/24 h setting.
- [ ] **Cinematic text** with letterbox bars, pushable from the server.
- [ ] **Character-load intro** (schema title, description, credits, optional bars).
- [ ] **Vignette.**
  *hl2rp:* partly. A static vignette image and colour grade drawn every frame; not dynamic and not
  toggleable.
- [ ] **Health effects:** motion blur, desaturation, heartbeat.
- [ ] **Underwater effects.**
- [ ] **Headbob** and fall shake.
- [ ] **Centre-screen status text** (`GetScreenTextInfo`).
- [ ] **Hook-error notice.** `OnHookError` is fired and nothing shows it.
- [ ] **Entity outline library** (`AddEntityOutlines`, distance-faded halos).
- [ ] **Markup tooltips, menu-from-data builder, titled menus, `Derma_NumRequest`.**
- [ ] **Bind blocking** for inventory, cash and fall-over commands.
- [ ] **Fading dead NPC ragdolls.**
- [ ] **Top HUD layers** drawn over VGUI (`HUDPaintForeground`, `HUDPaintImportant`,
  `HUDPaintTopScreen`).

**Partial**

- [ ] **Player target ID.** Lacking: recognition, fade-in delay, configurable distance, team colour,
  status lines for dead or fallen targets.
  *hl2rp:* adds recognition.
- [ ] **Hints.** Client-only random tips. Lacking: opt-out, centre hints, server-pushed hints with
  duration and sound, eligibility filtering before the pick.
- [ ] **Notifications.** Lacking classes, sounds, an adjust hook, radius notify, and a chat-only or
  popup-only choice.
- [ ] **Progress bar.** No single hook-driven bar; each plugin draws its own.
- [ ] **Black fade** when dead or unconscious. Fixed overlays only, no hooks or accessors.
- [ ] **Colour modify.** An imperative API. Lacking the per-frame adjust hooks so plugins compose.
- [ ] **Crosshair.** Lacking free-aim positioning, a full draw override and a config toggle.
- [ ] **Background blur.** Draw helpers exist; no registry that blurs the screen behind a panel.
- [ ] **Entity menus.** Per-plugin messages. Lacking a data-driven option list with shared server
  dispatch, distance check and rate limit; click-to-open; halo and title.
- [ ] **Intro splash.** Logo and sound are hard-coded, not schema options.
- [ ] **Visible legs.** Lacking per-hold-type and vehicle bone sets, the clip plane, skin sync.

---

## Menus, UI and theme

- [ ] **missing — Client settings.** A registry of sliders, checkboxes, choices, text and colour
  entries with categories and conditions, and the Settings tab. `lib/config.lua` points at a
  `cl_settings.lua` that does not exist. CW: `core/libraries/cl_setting.lua`.
- [ ] **missing — Quick menu** (contextual actions with a registry).
- [ ] **partial — Help.** The Help tab shows Plugins and Credits. Lacking the directory API
  (categories, pages, tips, sorting) and the generated Commands, Flags and Voice pages.
  CW: `core/libraries/cl_directory.lua`.
- [ ] **partial — Scoreboard.** Lacking: per-player admin action menu, a hide-player hook, a sort
  hook, a player count line.
  *hl2rp:* adds recognition: unrecognised players are listed separately without their character
  card.
- [ ] **partial — Tab menu API.** Lacking open/close from code, opened/closed hooks, tab removal,
  persistent tab panels.
- [ ] **missing — Voice panel** override (anonymised speakers).
- [ ] **missing — Widgets:** inline notice bar (`cwInfoText`), convar-bound forms, spawn icon with
  cooldown overlay.
- [ ] **missing — Player-selectable themes** (`modify_themes`, `default_theme`).
- [ ] **missing — Patching existing VGUI classes from a theme** with automatic undo on switch.
- [ ] **missing — Theme-scoped plugin hooks.** Theme methods are reached only through
  `Theme.hook`.
- [ ] **partial — Theme hooks around menus.** Paint hooks and whole-panel replacement exist; no
  Think or open-panel interception.

---

## Animation

Flux: `packages/flow/lib/sh_animation.lua`.

- [x] **partial — Model classes.** Only `player` (citizen-style) ships. Catwork has
  `combineOverwatch`, `civilProtection`, `femaleCP`, `femaleHuman`, `maleHuman`, `vortigaunt`, with
  default model assignments and a female fallback by path. (The Flux `hl2rp` schema was not
  checked.)
  *hl2rp:* covered: it registers `civil_protection`, `ota`, `vortigaunt` and `zombie` and assigns
  them through `FACTION.model_classes`. Female Civil Protection falls back to `player`.
- [ ] **partial — Forced animation.** `Player:set_animation` sets `fl_animation` only in the
  calling realm; it is not networked. Lacking: callbacks, activity input, the permanent-animation
  rule. Nothing in the framework calls it.
- [ ] **missing — Per-model animation overrides.**
- [ ] **missing — Emote animations** (the `emoteanims` plugin): twelve commands and a stance system
  with movement lock, wall checks, auto-exit, position restore and a forced camera.
  *hl2rp:* partly. `animations` has a registry, a context-menu list with previews, movement lock,
  exit on movement, third person and enter/exit transitions. Only `sit_ground` is registered; no
  commands or wall checks. It relies on `set_animation`, so whether other players see the pose is
  *(unverified)*.
- [ ] **partial — Character menu sequences.** No per-model registry.
- [ ] **missing — Pickup animation helper** (`FakePickup`).
- [ ] **missing — Mouth movement toggle.** Disabled outright.

---

## Bundled plugins

| Catwork plugin | Flux | Status | Lacking |
|---|---|---|---|
| `animatedlegs` | `plugins/cl_visiblelegs.lua` | partial | see HUD |
| `areadisplays` | `plugins/areas`, `plugins/areadisplay` | partial | scrolling, 3D and cinematic display classes; `%t` time; one-shot areas; per-client toggle; commands. `areadisplay` is an unfinished stub |
| `cleanedmaps` | — | missing | see sandbox rules |
| `developer` | — | missing | `/SetCharData`; probably not wanted |
| `displaytyping` | `plugins/displaytyping` | partial | see chat |
| `doorcommands` | `plugins/doors` | partial | see doors |
| `dynamicadverts` | `plugins/3dtexts` | present | commands only |
| `emoteanims` | hl2rp `plugins/animations` | partial | see animation |
| `fascwcompatibility` | — | missing | see weapons |
| `mapscene` | `plugins/mapscenes` | present | commands; scene position not added to the PVS |
| `observermode` | `plugins/observer` | present | `/Observer`; NPCs still target observers; no auto-exit on death or vehicle |
| `pickupobjects` | `plugins/sv_pickup_objects.lua` | partial | strength-based mass, throw, ragdoll dragging, grab entity |
| `salesmen` | — | missing | see economy |
| `savecash` | — | missing | see economy |
| `saveitems` | `plugins/items` | present | shipments only |
| `spawnpoints` | — | missing | per-class, per-faction and default spawn points with yaw, persistence, commands, ESP |
| `spawnsaver` | — | missing | see characters |
| `stamina` | `plugins/stamina` | partial | attribute coupling, health-scaled drain, crouch regen, punch cost, gradual speed scaling, persistence, veto hooks, no drain in noclip |
| `staticents` | `plugins/staticents` | present | narrower default whitelist (`edit_*`, `gmod_*`) |
| `storage` | `plugins/containers` | partial | see containers |
| `surfacetexts` | `plugins/3dtexts` | present | commands only |
| `toolguns` | — | missing | container tool |
| `cl_crosshair` | `plugins/cl_crosshair.lua` | present | config toggle |
| `sh_raisegun` | `plugins/sh_raisegun.lua` | present | see weapons |
| `sh_weaponselect` | `plugins/sh_weaponselect.lua` | partial | info box |

Also missing as a feature rather than a plugin: the **entry quiz** (questions, pass percentage,
blocking panel, kick on fail). CW: `core/libraries/sh_quiz.lua`, `core/derma/cl_quiz.lua`.

---

## Plugin hook surface

Of 147 custom hooks defined or fired in Catwork's server hook files, 12 exist under the same name
in Flux and roughly 44 have an equivalent under another name. About 91 have none. The client side
was not counted; its notable gaps are listed below. The "equivalent under another name" figure is
a judgement, not a mechanical match.

**Server**

- Damage, death, health: `PlayerScaleDamageByHitGroup`, `PlayerPlayPainSound`,
  `PlayerPlayDeathSound`, `PlayerAdjustDeathInfo`, `PlayerCanGainFrag`,
  `PlayerAdjustDropWeaponInfo`, `PlayerHealthSet`, `PlayerArmorSet`,
  `PlayerShouldHealthRegenerate`, `PlayerHealthRegenerate`, `PlayerLimbTakeDamage`,
  `PlayerLimbDamageHealed`, `PlayerLimbDamageReset`, `PlayerAdjustBulletInfo`
- Ragdoll: `PlayerCanRagdoll`, `PlayerCanUnragdoll`, `PlayerRagdolled`, `PlayerUnragdolled`,
  `PlayerRagdollCanTakeDamage`, `PlayerCanRagdollDecay`, `PlayerCanGetUp`, `PlayerCanKnockout`
- Weapons: `PlayerCanFireWeapon`, `PlayerCanBeGivenWeapon`, `PlayerGivenWeapon`,
  `PlayerDropWeapon`, `PlayerCanDropWeapon`, `PlayerCanHolsterWeapon`, `PlayerCanThrowPunch`,
  `PlayerCanPunchEntity`, `PlayerCanPunchKnockout`, `PlayerAdjustNextPunchInfo`, `AdjustAmmoTypes`
- Characters and classes: `PlayerCanInteractCharacter`, `PlayerCanUseCharacter`,
  `PlayerCanSwitchCharacter`, `PlayerCanDeleteCharacter`, `PlayerSelectCustomCharacterOption`,
  `PlayerAdjustCharacterTable`, `PlayerAdjustCharacterScreenInfo`, `GetPersuasionChoices`,
  `PlayerCanBypassFactionLimit`, `PlayerCanBypassClassLimit`, `PlayerCanChangeClass`,
  `PlayerClassSet`, `GetPlayerDefaultSkin`
- Doors, entities, props: `PlayerCanOwnDoor`, `PlayerCanViewDoor`, `PlayerCanUseDoor`,
  `PlayerDoesHaveDoorAccess`, `PlayerDoorGiven`, `PlayerDoorTaken`, `PlayerGetLockInfo`,
  `PlayerGetUnlockInfo`, `PlayerCanUseEntityInVehicle`, `GetEntityBeingHeld`,
  `PlayerPropertyGiven`, `PlayerPropertyTaken`, `PlayerReturnProperty`, `PlayerAdjustPropCostInfo`
- Economy: `ModifyWagesInterval`, `PlayerModifyWagesInfo`, `PlayerCanEarnWagesCash`,
  `PlayerGiveWagesCash`, `PlayerEarnWagesCash`
- Items and storage: `PlayerCanDestroyItem`, `PlayerDestroyItem`, `ItemEntityTakeDamage`,
  `ItemEntityDestroyed`, `ItemGetNetworkObservers`, `PlayerStorageShouldClose`
- Recognition, chat, radio: `PlayerCanSaveRecognisedName`, `PlayerCanRestoreRecognisedName`,
  `PlayerDoesRecognisePlayer`, `PlayerCanRadio`, `PlayerAdjustRadioInfo`, `PlayerRadioUsed`,
  `PlayerCanSayIC`, `PlayerCanSayOOC`, `PlayerCanSayLOOC`, `ChatboxMessageSent`
- Other: `OnAttributeProgress`, `PlayerAttributeUpdated`, `TimePassed`, `PostCommandUsed`,
  `PostSaveData`, `PostCModelHandsSet`, `ShouldSavePlayerSpawn`

**Client**

- HUD layers: `HUDPaintForeground`, `HUDPaintImportant`, `HUDPaintTopScreen`,
  `HUDPaintCharacterSelection`, `HUDPaintCharacterLoading`, `ShouldDrawBackgroundBlurs`
- Info and bars: `PaintInfoMenuExtras`, `PlayerCanSeeDateTime`, `GetPlayerInfoText`,
  `PlayerCanSeeBars`, `GetProgressBarInfo`, `PlayerCanSeeLimbDamage`
- Target ID: `ShouldDrawPlayerTargetID`, `GetTargetPlayerName`, `GetTargetPlayerFadeDistance`,
  `PlayerCanShowUnrecognised`, `DrawTargetPlayerStatus`
- Effects and view: `DrawPlayerVignette`, `PlayerAdjustMotionBlurs`,
  `PlayerSetDefaultColorModify`, `PlayerAdjustColorModify`, `ShouldPlayerScreenFadeBlack`,
  `PlayerAdjustHeadbobInfo`, `CalcViewAdjustTable`, `GetWeaponLoweredViewInfo`,
  `GetScreenTextInfo`, `GetPlayerCrosshairInfo`, `DrawPlayerCrosshair`
- Menus: `GetEntityMenuOptions`, `AddEntityOutlines`, `GetPlayerScoreboardOptions`,
  `PlayerShouldShowOnScoreboard`, `MenuOpened`, `MenuClosed`, `MenuItemsDestroy`,
  `GetCharacterPanelToolTip`, `PlayerCanSeeClass`, `TopLevelPlayerBindPress`
- Other: `PlayerCanSeeHints`, `NotificationAdjustInfo`, `PlayerCanSeeAdminESP`, `GetStatusInfo`,
  `GetCinematicIntroInfo`, `GetCharacterLoadingTime`

---

## Not worth porting

Present in Catwork but dead, broken or superseded there.

- **Business menu and `/OrderShipment`.** The command file is commented out and the menu tab is
  never added. Item recipes and `costScale` hang off it.
- **`cw.currency`.** A registry with no callers; real cash is a single currency.
- **Numbered-key selector** (`sh_selector.lua`). Unused and calls a function that does not exist.
- **Storage plugin persistence.** `SaveStorage` and `LoadStorage` are empty; `cw_locker` is
  referenced and never defined.
- **`breathing_volume`, `Fatigue`, `cwSpawnESP`, `cwNPCESP`, vehicle animation sub-tables,
  `optionalArguments`, plugin `compatibility` and `hookOrder`.** Declared and never read.
- **Implicit `#Phrase` translation** by overriding `surface.DrawText` and `Panel:SetText`.
  Flux's explicit `t()` replaces it.
- **CloudAuthX phrases, hard-coded bans, pON fallback, `md5.lua`, engine workarounds** and the
  small Lua helpers Flux's stdlib already covers.
- **Hard-coded map fixes** in `cleanedmaps`, **SXBASE weapon class tables**, the default Workshop
  map table.
- **`/CharTie`.** A wrapper around a schema function.

---

## Flux stubs found along the way

Half-built pieces in Flux that touch the gaps above. Found by reading; none were exercised in game.

- `Faction.default_class`, `char.char_class` (no column), `CHAR_ERR_CLASS`, `CHAR_ERR_LIMIT`,
  `CHAR_ERR_EXISTS`: declared, unused. `hl2rp` factions set `default_class` and `stats`; nothing
  reads either.
- `Plugin.is_disabled` and `disabled_plugins`: read at boot, never written or consulted.
- `Chatbox.add_filter`, `message_data.rich`, small/big chat font configs: stored, unused.
- `Prefixes:add`: no callers in the framework; `hl2rp` registers `ooc`, `looc` and `radio`.
- `Ammunition` model and `Player:get_ammo_table`: never written, no callers. `character.health` is
  never updated after creation.
- `set_player_data` / `get_player_data`: not persisted, no callers in the framework. `hl2rp` keeps
  OOC mutes in it, so they are lost on reconnect.
- `ItemBase:get_weight`, item `cost`, `Attribute.hidden`, `Faction.phys_desc`,
  `Entity:get_hitgroup_from_pos`: defined, unused. `Player:open_player_inventory` is used only by
  `hl2rp`'s player search.
- `spawn_chairs` permission: registered, never checked.
- `default_currency`: read by three commands, defined nowhere in the framework; `hl2rp` sets it.
- `plugins/areadisplay`: the notice text is the literal `'test test test'` and persistence is
  commented out.
- `plugins/cl_colormod.lua`: enable is the bare global `enable_color_mod` while disable is
  `Flux.disable_color_mod`; the player's table aliases the shared default.
- `plugins/ragdoll/plugin/sv_plugin.lua:98`: the bone loop runs `1..GetPhysicsObjectCount()` over
  zero-indexed physics objects.
- `lib/config.lua:10` refers to `cl_settings.lua`; `languages/en.yml` mentions a client settings
  menu "not in this build".
- `voice` permission: registered with no default role, so as written only staff can use voice
  unless a schema grants it.
- Factions with `has_description = false` still fail the server's minimum description length.
- `plugins/sh_autowalk.lua:51`: a commented-out call to the old hints API.
