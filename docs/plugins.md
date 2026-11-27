# Writing plugins and schemas

This is the one page to read before you write a plugin or a schema for Flux. It walks through a small plugin, Notes, which lets characters write notes with a `/note` command, and shows every kind of file Flux loads by convention with a short example. Each example follows a file of the same kind in this repository, linked as further reading.

Run a server in the `development` environment while you work, such as the stack of [Docker (development)](../readme.md#docker-development): it reloads your code as you save it and prints what it loads.

## Where a plugin lives

A plugin is a folder (or a [single file](#a-single-file-plugin)) in `plugins/` of a schema or of Flux. Its folder name is its ID, in snake_case words (`spawn_points`, `door_keys`), and the name other plugins and `<schema>.yml` use for it. Every plugin in the schema's `plugins/` folder loads; the plugins of Flux load when the schema's `<schema>.yml` or another plugin asks for them (see [Plugins](../readme.md#plugins) in the readme).

`fpkg new plugin notes`, run in a schema, creates `plugins/notes/` with a `plugin.yml`, the main file, a client and a server hook file, a config key and its English phrases: a working plugin to start from. `fpkg new plugin notes --minimal` writes the single file `sh_notes.lua` instead.

## Folder layout

```
plugins/notes/
  plugin.yml          name, description, author, version, depends, depends_development, environment
  plugin/
    sh_plugin.lua     the main file
    cl_plugin.lua     code that is not a hook handler, one file per realm
    sv_plugin.lua
    cl_hooks.lua      hook handlers, one file per realm
    sh_hooks.lua
    sv_hooks.lua
    lib/              libraries, lib/meta (metatable extensions), lib/classes (classes)
    commands/  roles/  config/  languages/  migrations/  models/  nethooks/
    items/  species/  factions/  views/  controllers/  tools/  themes/  entities/ ...
```

The root of `plugin/` holds only the files listed above, and only the ones the plugin needs. The main file is `sh_plugin.lua`, or `sh_<folder>.lua` named after the plugin's folder. Everything else goes into `lib/` or one of the folders that Flux includes by convention.

Those folders are included **before** the main file, `lib` first, in the order the doc comment at the top of [`lib/plugin.lua`](../lib/plugin.lua) lists. The files of a folder are included in alphabetical order, each in the realm its prefix names: `sv_` on the server, `cl_` on the client, `sh_` on both. Models and migrations have no prefix.

## plugin.yml

```yaml
name: Notes
description: Lets characters write notes.
author: You
depends:
  - characters
```

`depends` lists the plugins that have to be loaded first; a plugin whose dependency is missing or disabled is not loaded. `depends_development` adds dependencies outside of the production environment, and `environment` (`development`, `production` or `test`, or a list of them) loads the plugin in those environments only. `version` is shown in the plugin manager. See [`plugins/door_keys/plugin.yml`](../plugins/door_keys/plugin.yml).

## The main file and the plugin global

```lua
--- Notes lets characters write notes with the `/note` command, keeps them in the `notes` table
-- and sends a player the notes of their character when the client asks for them.

PLUGIN:set_global('Notes')

require_relative 'sv_hooks'
```

While a plugin loads, `PLUGIN` is the plugin. `PLUGIN:set_global('Notes')` makes it the global `Notes`, in ConstantStyle, which the hook files and libraries use. `require_relative` includes the other root files, picks the realm from their prefix and sends client files to clients itself, so plugin files never call `AddCSLuaFile`.

A library in `lib/` runs before the main file, so it sets up the global itself:

```lua
--- Saving the notes of characters.

if !Notes then
  PLUGIN:set_global('Notes')
end

--- Saves a note for the active character of a player and tells them, unless it is longer than
-- the `notes_max_length` config.
-- @param actor [Player]
-- @param text [String]
function Notes:write(actor, text)
  local max_length = Config.get('notes_max_length')

  if #text > max_length then
    actor:notify('error.notes.too_long', { max = max_length })

    return
  end

  local note = Note.new()
  note.character_id = actor:get_character_id()
  note.text = text
  note:save()

  --- Called on the server when a player has written a note.
  -- @param actor [Player the player who wrote it]
  -- @param note [Note the note]
  hook.Run('NoteWritten', actor, note)

  actor:notify('notification.notes.saved')
end
```

That is `plugin/lib/sv_notes.lua`. Compare [`plugins/doors/plugin/sh_plugin.lua`](../plugins/doors/plugin/sh_plugin.lua) and [`plugins/doors/plugin/lib/sh_doors.lua`](../plugins/doors/plugin/lib/sh_doors.lua). Flux reruns the whole plugin on every code refresh: a library that keeps state does it with `local stored = Notes.stored or {}` followed by `Notes.stored = stored`.

## Hooks

A hook handler is a method on the plugin global named after the hook; it needs no `hook.Add`:

```lua
--- Tells a player how many notes their character has once it is loaded.
-- @param owner [Player]
-- @param character [Character]
function Notes:PostLoadCharacter(owner, character)
  Note:where('character_id', character.id):get(function(notes)
    if IsValid(owner) and #notes > 0 then
      owner:notify('notification.notes.count', { count = #notes })
    end
  end):fetch()
end

--- Keeps players who have no character from spawning props.
-- @param actor [Player]
-- @param _model [String]
-- @return [Boolean false to forbid the prop, nil to leave the decision to the others]
function Notes:PlayerCanSpawnProp(actor, _model)
  if !actor:is_character_loaded() then
    return false
  end
end
```

**The first handler that returns anything other than nil ends the hook:** its value is the result, and the handlers after it are not called, the schema's (which run after every plugin's), those added with `hook.Add` and the gamemode's included. So return a value only when you mean to decide, as `return false` does above, and return nothing from a handler that only reacts or changes something in place. A stray `return true` hides the event from everyone after you.

Flux runs a hook of its own with `hook.Run('NoteWritten', actor, note)`, with a doc comment right above the call that says when it runs, its parameters and what a return value does, as in `Notes:write` above. The names of Flux's hooks follow a grammar: `PlayerCan<Verb><Object>` for a veto (false denies), `Should<Verb><Object>` for a decision, `Get<Thing>` for a value, `Adjust<Thing>` for a change made in place, `Pre<Verb><Object>` and `Post<Verb><Object>` around an action, `<Subject><Verb>ed` when something has happened. Never start one with `On`.

## Commands

`plugin/commands/sh_note.lua` defines the command `note`, after its file name:

```lua
--- The Note command: `/note <text>` writes a note for the caller's character.

CMD.name = 'Note'
CMD.description = 'command.note.description'
CMD.syntax = 'command.note.syntax'
CMD.category = 'permission.categories.general'
CMD.arguments = 1
CMD.arg_types = { 'text' }
CMD.no_console = true

--- Saves the text as a note of the caller's character.
-- @param actor [Player the caller]
-- @param text [String the note, as it was typed]
function CMD:on_run(actor, text)
  Notes:write(actor, text)
end
```

`arguments` is how many arguments the command needs at least, and `arg_types` says what each one is: `player` (one or more players by name or SteamID, passed as a list), `text` (the rest of the line), `number`, `role` and others; with `immunity = true` the caller may only target players whose role ranks below their own, and `aliases` adds other names. The command's ID is also its permission: nobody may run it until a role grants it, or `CMD.permission = 'user'` allows it to a role and the roles based on it. See [`packages/bolt/commands/sh_sethealth.lua`](../packages/bolt/commands/sh_sethealth.lua) and [`packages/flow/lib/classes/sh_command.lua`](../packages/flow/lib/classes/sh_command.lua).

## Roles and permissions

A file in `roles/` named after an existing role adds permissions to it, and through it to every role based on it. `plugin/roles/sh_user.lua` lets every player write notes:

```lua
--- Lets every player write notes.

--- Allows the Note command.
function ROLE:define_permissions()
  can 'note'
end
```

The built-in roles are `user`, `assistant`, `gamemaster` and `admin`, each based on the one before. A file with a new name defines a new role, with `ROLE.name`, `ROLE.base`, `ROLE.immunity` and the others that [`packages/bolt/roles/sh_assistant.lua`](../packages/bolt/roles/sh_assistant.lua) sets. Check a permission in code with `actor:can('note')`. See [`plugins/srcdsproxy/plugin/roles/sh_assistant.lua`](../plugins/srcdsproxy/plugin/roles/sh_assistant.lua).

## Config

A tunable value is a config, defined in `plugin/config/config.yml`:

```yaml
categories:
  notes:
    name: config.notes.title
    description: config.notes.desc
configs:
  notes_max_length:
    name: config.notes.max_length.name
    description: config.notes.max_length.desc
    category: notes
    type: number
    min_value: 1
    max_value: 2000
    default_value: 500
```

The key starts with the plugin's ID and sits in a category named after it. The types are `number`, `boolean`, `string`, `table` and `color`. Read the value with `Config.get('notes_max_length')`; the `ConfigChanged` hook runs with `key, old_value, new_value` when it changes. Staff change configs in game; a schema sets them in its `<schema>.yml` (`notes_max_length: 300`). The flags `hidden`, `static`, `private` and `needs_restart` are described at the top of [`packages/flow/config/config.yml`](../packages/flow/config/config.yml). See [`plugins/hints/plugin/config/config.yml`](../plugins/hints/plugin/config/config.yml).

## Phrases

Every text a player reads is a phrase in `plugin/languages/en.yml`:

```yaml
en:
  command:
    note:
      description: Write a note for your character.
      syntax: <text>
  config:
    notes:
      title: Notes
      desc: Settings of the notes that characters write.
      max_length:
        name: Maximum Note Length
        desc: How many characters a note may have.
  error:
    notes:
      too_long: "A note may have {max} characters at most."
  notification:
    notes:
      saved: Your note has been saved.
      count: "Notes of your character: {count}."
```

`t'notification.notes.saved'` translates a phrase, `t('error.notes.too_long', { max = 500 })` fills in its placeholders, and `actor:notify` and the command fields take phrase keys as they are. A command has `command.<id>.description` and `syntax`; a config `config.<category>.<key without the prefix>.name` and `desc`. `es.yml`, `fr.yml` and `ru.yml` next to it translate the same keys; a phrase missing there is shown in English. See [`plugins/hints/plugin/languages/en.yml`](../plugins/hints/plugin/languages/en.yml).

## Migrations and models

Tables are created by migrations, never by models. `plugin/migrations/20261125120000_create_notes.lua`, whose name starts with a `YYYYMMDDHHMMSS` timestamp, creates the `notes` table:

```lua
--- Migration that creates the `notes` table.

local CreateNotes = ActiveRecord.Migration.new()

--- Creates the notes table.
function CreateNotes:change()
  create_table('notes', function(t)
    t:references('character', { foreign_key = { on_delete = 'cascade' } })
    t:string 'text'
    t:timestamps()
  end)
end

return CreateNotes
```

Flux installs it into the schema's `db/migrate/` and runs it when the server starts, or when you run `fpkg db:migrate` in the schema's folder, which needs no server (see [Migrations](../readme.md#migrations) in the readme). The model, `plugin/models/note.lua`, and the relation it adds to the `Character` model of the Characters plugin, `plugin/models/character.lua`:

```lua
--- A note that a `Character` has written, stored in the `notes` table.

class 'Note' extends 'ActiveRecord::Base'

Note:belongs_to 'Character'
```

```lua
--- Gives the `Character` model its notes.

Character:has_many 'notes'
```

`Note.new()` and `note:save()` write a row, `Note:where('character_id', id):get(callback):fetch()` reads them; queries are asynchronous and call back with the results. `first`, `find_by`, `order`, `limit`, `expect`, `destroy` and the others are documented in [`packages/active_record/lib/base.lua`](../packages/active_record/lib/base.lua). Relations load only when a query names them with `preload`. See the migrations and models of [`plugins/currencies`](../plugins/currencies/plugin).

## Net messages

`Cable` sends any number of values, tables included, in one call. Handlers go into `nethooks/`, one file per realm and topic. On the server the sender comes first, and everything else a client sends is hostile until checked: whether the player is valid, the types, the permission when there is one, and a rate limit. `plugin/nethooks/sv_notes.lua`:

```lua
--- Server-side receivers of the Notes plugin.

Cable.receive('fl_notes_request', function(actor)
  if !IsValid(actor) or !actor:is_character_loaded() then return end
  if (actor.fl_next_notes_request or 0) > CurTime() then return end

  actor.fl_next_notes_request = CurTime() + 1

  Note:where('character_id', actor:get_character_id()):get(function(notes)
    if !IsValid(actor) then return end

    Cable.send(actor, 'fl_notes_list', table.map(notes, note -> note.text))
  end):fetch()
end)
```

`plugin/nethooks/cl_notes.lua`, which the client runs after `Cable.send('fl_notes_request')`:

```lua
--- Client-side receivers of the Notes plugin.

Cable.receive('fl_notes_list', function(texts)
  for _, text in ipairs(texts) do
    chat.AddText(text)
  end
end)
```

Message names start with `fl_`. For requests that expect an answer, `MVC.request` and `MVC.handler` in [`packages/active_ui/lib/sh_mvc.lua`](../packages/active_ui/lib/sh_mvc.lua) pair them up. See [`plugins/door_keys/plugin/nethooks/sv_door_keys.lua`](../plugins/door_keys/plugin/nethooks/sv_door_keys.lua).

## Items

With the Items plugin loaded, every file in an `items/` folder is an item, named after the file. `items/sh_bandage.lua` of a schema:

```lua
--- A bandage that gives back 2 health a second for 5 seconds.

ITEM:base_off 'medical'

ITEM.name = 'item.bandage.name'
ITEM.description = 'item.bandage.description'
ITEM.model = 'models/props_junk/cardboard_box004a.mdl'
ITEM.weight = 0.5

ITEM.health_ticks = 5
ITEM.health_regen = 2
ITEM.health_delay = 1
```

`ITEM:base_off` takes over a base from [`plugins/items/plugin/items/bases/`](../plugins/items/plugin/items/bases): `usable` (define `ITEM:use(actor)`), `consumable`, `medical`, `weapon`, `wearable` and others. The fields and callbacks an item can have are listed at the top of [`plugins/items/plugin/lib/classes/sh_item.lua`](../plugins/items/plugin/lib/classes/sh_item.lua). Compare `schema/items/sh_medical_bandage.lua` of HL2RP.

## Species

With the Characters plugin loaded, every file in a `species/` folder is a species, named after the file. A species is what a character is: it owns the models, whether characters have a gender, a name and a description of their own, their random names and how many characters of it a player may have. The first stage of character creation offers one option per species, and is left out when there is only one. Flux ships one species, `human`, in [`plugins/characters/plugin/species/sh_human.lua`](../plugins/characters/plugin/species/sh_human.lua). A file whose ID is registered already reopens that species instead of replacing it, so `species/sh_human.lua` of a schema amends the human of Flux:

```lua
--- Humans of the city: the citizens of Flux with random names, members of the citizen
-- faction unless they carry something that makes them members of another one.

SPECIES.default_faction = 'citizen'
SPECIES.max_characters = 3
SPECIES.random_names = {
  male = { first = { 'John', 'Paul' }, last = { 'Doe', 'Smith' } },
  female = { first = { 'Jane', 'Mary' }, last = { 'Doe', 'Smith' } }
}
```

A species of its own sets `SPECIES.name` and `SPECIES.description` (phrases), `SPECIES.models` (`male`, `female` and `universal` lists) and `SPECIES.model_classes` (their animation classes), and `has_gender`, `has_name` and `has_description` to false to take those choices away from the player; `phys_desc` is the description it gives instead, and a `SPECIES:get_random_name(gender)` of its own names the characters. The fields are described in [`plugins/characters/plugin/lib/classes/sh_species.lua`](../plugins/characters/plugin/lib/classes/sh_species.lua).

## Factions

With the Factions plugin loaded, every file in a `factions/` folder is a faction, named after the file. A faction is what a character is recognized as. Nobody is put into one: a player is a member because of what they carry or wear, an item whose definition sets `ITEM.faction`, or else because it is the `default_faction` of their species. `factions/sh_police.lua`:

```lua
--- The police, who keep order in the city. Wearing the uniform makes a member; whitelisted
-- players may create officers who start with it.

FACTION.name = 'faction.police.title'
FACTION.description = 'faction.police.desc'
FACTION.color = Color(60, 100, 200)
FACTION.species = 'human'
FACTION.whitelisted = true
FACTION.priority = 10
FACTION.kit = { 'police_uniform', 'police_badge' }
FACTION.name_template = '{rank} {name}'

FACTION:add_rank('recruit', 'Rct.')
FACTION:add_rank('officer', 'Ofc.')
```

The item that grants the faction, `items/sh_police_uniform.lua`. An equipable item grants it while it is equipped, any other item while it is carried, and the rank lives in the data of the item, so whoever wears the uniform holds the rank and `/rank` changes the uniform:

```lua
--- The uniform of the police, which makes its wearer a member.

ITEM:base_off 'wearable'

ITEM.name = 'item.police_uniform.name'
ITEM.description = 'item.police_uniform.description'
ITEM.model = 'models/props_c17/suitcase_passenger_physics.mdl'
ITEM.model_group = 'police'
ITEM.valid_model_group = '/citizens/'
ITEM.equip_model_classes = { male = 'metrocop', female = 'female' }
ITEM.faction = 'police'
ITEM.faction_rank = 'recruit'
```

`model_group` dresses the wearer in the model of the same name in the `police` model folder: the last folder of the path of their model is replaced, so `models/<pack>/citizens/male01.mdl` becomes `models/<pack>/police/male01.mdl`, and `equip_model_classes` gives those models their animation classes, by the gender of the species model they replace. This needs a model whose last folder is named in letters. The human models Flux ships are in `models/humans/group01/`, which has no counterpart: no police model is found for them, no class is assigned, and a wearer would get the model of the item itself. `valid_model_group`, a pattern that the path of the wearer's model has to contain, keeps the uniform to the models that have a `police` counterpart; the example assumes a schema whose human species uses models of a pack in `citizens` folders.

A whitelist restricts nobody: a player with the police whitelist gets a character creation option that starts a human with the kit. When the `default_faction` of a species is whitelisted, the option of that species is only offered to players with that whitelist and to players who may bypass creation limits (`PlayerCanBypassCreationLimits`). A faction that is neither a default of its species nor whitelisted is joined through its items only, and `/setfaction` hands out kits. To show members under something other than the template, a faction overrides `get_display_name`, here with the badge number kept in the data of the badge:

```lua
function FACTION:get_display_name(target, _name, _rank_table)
  local badge = target:find_item('police_badge')
  local number = badge and badge:get_data('number')

  if number then
    return 'Officer #'..number
  end
end
```

The real name of the character never changes; `Player:name()` shows the display name and `Player:name(true)` the real one. The other fields, the ranks and the callbacks are described in [`plugins/factions/plugin/lib/classes/sh_faction.lua`](../plugins/factions/plugin/lib/classes/sh_faction.lua). Compare `schema/factions/sh_cca.lua` of HL2RP.

## A single-file plugin

A plugin without folders is one file in `plugins/`, whose prefix sets its realm. `plugins/sh_join_log.lua` is the plugin `join_log`:

```lua
--- Join Log writes to the server log when a player's game has finished loading.

PLUGIN:set_name('Join Log')
PLUGIN:set_author('You')
PLUGIN:set_description('Logs the players whose game has loaded.')

if SERVER then
  --- Writes to the server log that a player's game has finished loading.
  -- @param actor [Player]
  function PLUGIN:PlayerInitialized(actor)
    ServerLog(actor:Name()..' has finished loading.\n')
  end
end
```

See [`plugins/sh_auto_walk.lua`](../plugins/sh_auto_walk.lua).

## Schemas

A schema has the layout of a plugin in its `schema/` folder, with `sh_schema.lua`, `cl_schema.lua` and `sv_schema.lua` in place of the plugin files and `SCHEMA` in place of `PLUGIN`: `function SCHEMA:PlayerSpawn(actor)` handles a hook. Unlike a plugin's main file, `sh_schema.lua` runs before the folders of the schema. Its `<schema>.yml` picks the plugins of Flux and sets config values, and its `db/` folder is written by the server: never edit it by hand. `fpkg new schema <name>` creates a working schema; [HL2RP](https://github.com/TeslaCloud/hl2rp) is the full example. Behavior that would be the same in any schema belongs in a plugin.

## Where to find things

Before writing a function, look for it: Flux has more than it seems.

* The API reference, generated from the doc comments, is at https://docs.fluxpkg.dev/flux/. Its `Hooks` pages list every hook Flux runs, with its parameters, what a return value does and where it is called. [README.md](README.md) says how to build it from your checkout.
* The standard library: [`lib/stdlib/`](../lib/stdlib), such as `sh_string.lua`, `sh_table.lua` (`table.map`, `table.safe_merge`), `sh_math.lua` and `sh_utils.lua`.
* Player and entity methods (`notify`, `can`, `is_in_reach`, `is_door`): [`packages/flow/lib/meta/`](../packages/flow/lib/meta), and the `lib/meta/` folders of the plugins, such as `get_character` of the Characters plugin.
* Every `sh_plugin.lua` and library starts with a doc comment that sums up what it does.

## Conventions

* Globals and classes are ConstantStyle (`Notes`, `ItemMedical`), everything else Flux defines is snake_case (`get_character_id`, `notes_max_length`), and engine functions and hook names keep their PascalCase. Name players by their role (`actor`, `target`, `owner`) and never shadow a library such as `player`, `team`, `file`, `table` or `sound`.
* Write `!`, `!=` and the newer syntax that Flux's Lua library reads: `x += 1`, `a ?? b`, `c ? a : b`, `x -> x.id`.
* The only comments are doc comments: `---` on the first line, `--` on the rest, at the top of every file, above every global function and method and above every `hook.Run` that introduces a hook. Tags such as `@param name [Type description]` and `@return [Type description]` are described in the [fdoc README](https://github.com/Meow/fdoc), and [`fdoc_demo.lua`](fdoc_demo.lua) shows every one of them. A comment says what the code does, in the present tense.

## Linting and the reference

[proofreader](https://github.com/Meow/proofreader) checks the style of Flux and fixes what it can; it reads the nearest `.proofreader.yml`, which `fpkg new schema` writes. Install it with `cargo install --locked --git https://github.com/Meow/proofreader`, then:

```sh
proofreader plugins/notes          # list the offenses
proofreader --fix plugins/notes    # fix what can be fixed
```

[fdoc](https://github.com/Meow/fdoc) builds the reference of your own code the way it builds Flux's, from its doc comments: `fdoc . -o ../my-schema-reference` in the schema's folder, then open `index.html` there. Always pass `-o`: the default output folder of fdoc is the `docs` folder of the source.
