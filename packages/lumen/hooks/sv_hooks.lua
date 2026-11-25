--- Server-side hooks of the Lumen package, registered as `Lumen`: writing the compiled
-- templates for the clients.

local hooks = {}

--- Writes the compiled templates along with the other files that get sent to the clients.
function hooks:WriteClientFiles()
  Lumen.write_client_files()
end

Plugin.add_hooks('Lumen', hooks)
