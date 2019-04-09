DeriveGamemode('sandbox')

old_server_log = old_server_log or ServerLog

function ServerLog(...)
  old_server_log(...)
  print('')
end

function hook.run_client(player, strHookName, ...)
  Cable.send(player, 'fl_hook_run_cl', strHookName, ...)
end
