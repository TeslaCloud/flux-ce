--- Chat prefixes of the RolePlay Commands plugin: `//` and `/ooc` send a message to the OOC
-- chat, `.//`, `[[` and `/looc` to the local one. The `/ooc` and `/looc` prefixes end with a
-- space, so that commands whose names merely start the same way (`/oocmute`) stay commands.
-- The prefixes themselves are listed in `RPCommands.ooc_prefixes` and
-- `RPCommands.looc_prefixes` on both realms, and are registered with the Prefixes plugin on
-- the server.

if !RPCommands then
  PLUGIN:set_global('RPCommands')
end

RPCommands.ooc_prefixes = { '//', '/ooc ' }
RPCommands.looc_prefixes = { './/', '[[', '/looc ' }

if SERVER then
  Prefixes:add('ooc', {
    prefix = RPCommands.ooc_prefixes,
    callback = function(actor, text, team_chat)
      RPCommands:say_ooc(actor, text, team_chat)
    end
  })

  Prefixes:add('looc', {
    prefix = RPCommands.looc_prefixes,
    callback = function(actor, text, team_chat)
      RPCommands:say_looc(actor, text, team_chat)
    end
  })
end
