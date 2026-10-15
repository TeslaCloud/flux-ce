--- Server side of the SrcdsProxy plugin: hands the commands of the srcdsproxy backend addon
-- over to Flux once the gamemode has initialized, and again after a Lua refresh. The addon's
-- autorun file has run by then, so what the plugin sets here replaces what the addon has set
-- up.

--- The console commands of the srcdsproxy addon, keyed by their names, with the Flux
-- command each one runs and the usage shown in its console help. The plugin registers these
-- names again, so that typing one of them in the console runs the Flux command, with its
-- permission check and logging, instead of the addon's own handler.
local console_commands = {
  srcdsproxy_status = { command = 'proxy', usage = '' },
  srcdsproxy_server = { command = 'server', usage = '[name]' },
  srcdsproxy_glist = { command = 'glist', usage = '' },
  srcdsproxy_pinfo = { command = 'pinfo', usage = '<player>' },
  srcdsproxy_send = { command = 'transfer', usage = '<player> <server> [reason]' },
  srcdsproxy_whitelist = { command = 'proxywhitelist', usage = 'add|remove <server> <player> | list [server]' },
  srcdsproxy_ban = { command = 'netban', usage = '<player|steamid|ip|subnet> [duration] [reason]' },
  srcdsproxy_banip = { command = 'netbanip', usage = '<player> [duration] [reason]' },
  srcdsproxy_unban = { command = 'netunban', usage = '<steamid|ip|subnet>' },
  srcdsproxy_bans = { command = 'netbans', usage = '' }
}

--- Runs the Flux command that stands for one of the addon's console commands, with the
-- arguments that were typed after it.
-- @param actor [Player the player who has typed the console command, an invalid entity for
--   the server console]
-- @param cmd [String name of the console command, such as 'srcdsproxy_status']
-- @param args [List<String> arguments of the console command]
-- @param args_text [String arguments as they were typed]
local function run_console_command(actor, cmd, args, args_text)
  local data = console_commands[cmd]

  if data then
    Flux.Command:interpret(actor, data.command..' '..(args_text or table.concat(args, ' ')), true)
  end
end

--- Answers the addon's check of who is an admin. A player is one if they have the `moderate`
-- permission, the compatibility permission through which other addons see a player as an
-- admin.
-- @param target [Player]
-- @return [Boolean]
local function is_admin(target)
  return IsValid(target) and target:can('moderate')
end

--- Hands the srcdsproxy addon's commands over to Flux: turns off the addon's chat commands
-- through its `srcdsproxy.ChatCommands` setting, so that the chat forms such as `!server`
-- reach the Flux commands, replaces its `srcdsproxy_*` console commands with ones that run
-- the Flux commands, and answers its admin check with the `moderate` permission. Without
-- the addon nothing is changed, and a warning is printed the first time.
function SrcdsProxy:take_over()
  if !self:available() then
    if !self.warned then
      self.warned = true

      print('[SrcdsProxy] The srcdsproxy backend addon is not installed, the proxy commands are disabled.')
    end

    return
  end

  srcdsproxy.ChatCommands = false
  srcdsproxy.IsAdmin = is_admin

  for k, v in pairs(console_commands) do
    local name = k:gsub('^srcdsproxy_', '')

    concommand.Add(k, run_console_command, nil, 'srcdsproxy '..name..' '..v.usage)
  end
end

--- Hands the addon's commands over to Flux once every addon and the gamemode have loaded.
function SrcdsProxy:Initialize()
  self:take_over()
end

--- Hands the addon's commands over to Flux again after a Lua refresh.
function SrcdsProxy:OnReloaded()
  self:take_over()
end
