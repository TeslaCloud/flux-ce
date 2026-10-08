--- Server-side additions of the Flux core: `hook.run_client`, which runs a hook on the
-- client of a player, and a `ServerLog` that leaves an empty line after every entry.
-- Also derives the gamemode from sandbox on the server.
-- @module [hook]

DeriveGamemode('sandbox')

old_server_log = old_server_log or ServerLog

--- Detour of the engine function that prints an empty line to the console after each log
-- entry. The original function is kept as old_server_log.
-- @param ... [Vararg text passed on to the original ServerLog]
function ServerLog(...)
  old_server_log(...)
  print('')
end

--- Runs a hook on a player's client. The arguments are sent over the network.
-- @param target [Player the client to run the hook on]
-- @param hook_name [String name of the hook]
-- @param ... [Vararg arguments passed to the hook]
function hook.run_client(target, hook_name, ...)
  Cable.send(target, 'fl_hook_run_cl', hook_name, ...)
end
