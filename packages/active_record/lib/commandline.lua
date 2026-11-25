--- Server console commands of ActiveRecord. `flux db:<task>` runs one of the database
-- tasks of `ActiveRecord.Tasks` (`flux db:migrate`, `flux db:rollback STEP=2`,
-- `flux db:schema:dump` and so on), and `flux generate migration <Name> [column:type ...]`
-- (or `flux g`) writes a new migration file with `ActiveRecord::MigrationGenerator`; anything
-- else prints the list of tasks, which comes from `migrator/task_list.lua`. fpkg runs the same
-- tasks from the shell without the server (`fpkg db:migrate`, see the package's
-- `taskspec.lua`). `ar_recreate_schema` wipes and recreates the whole database
-- once it has been entered twice within three seconds. Both commands only work from the
-- server console, never for a player.

local hold_start = nil

concommand.Add('ar_recreate_schema', function(actor)
  if !IsValid(actor) then
    if !hold_start or (os.time() - hold_start > 3) then
      print(txt[[
        ================================================
        Warning! You are about to recreate the database!
        This will destroy all of the data stored in it!

        Please enter this command again within 3 seconds
                    to confirm this action.
        ================================================
      ]])
      hold_start = os.time()
    else
      print('ActiveRecord - Wiping and recreating the database...')
      ActiveRecord.recreate_schema()
      hold_start = nil
    end
  end
end)

--- Returns the command of a task as the usage text of the 'flux' command shows it.
-- @param prefix [String what the command starts with, such as 'flux db:']
-- @param entry [Map the task, see task_list.lua]
-- @return [String]
local function command_text(prefix, entry)
  return entry.usage and prefix..entry.name..' '..entry.usage or prefix..entry.name
end

--- Appends a section of the usage text: its title, then one row per task with the command and
-- the description, the descriptions aligned.
-- @param lines [List<String> the lines of the usage text]
-- @param title [String]
-- @param prefix [String what the commands start with, such as 'flux db:']
-- @param entries [List<Map> the tasks, see task_list.lua]
local function add_section(lines, title, prefix, entries)
  local width = 0

  for _, entry in ipairs(entries) do
    width = math.max(width, #command_text(prefix, entry))
  end

  lines[#lines + 1] = title

  for _, entry in ipairs(entries) do
    lines[#lines + 1] = string.format('  %-'..width..'s  %s', command_text(prefix, entry), entry.description)
  end

  lines[#lines + 1] = ''
end

--- The lines of the usage text of the 'flux' command, built from the list of tasks (see
-- task_list.lua). They are printed one by one, since the console cuts a long print short.
local usage = { 'Usage: flux <task> [KEY=VALUE ...]', '' }

add_section(usage, 'Database tasks:', 'flux db:', ActiveRecord.Tasks.list.database)
add_section(usage, 'Generators (flux g is short for flux generate):', 'flux generate ',
  ActiveRecord.Tasks.list.generators)

usage[#usage + 1] = 'e.g. flux generate migration AddRoleToUsers role:string'
usage[#usage + 1] = '     flux g migration CreateItems name:string owner:references'
usage[#usage + 1] = ''
usage[#usage + 1] = 'fpkg runs the same tasks from the shell, without the server: fpkg db:migrate, fpkg tasks.'

local function print_usage()
  for _, line in ipairs(usage) do
    print(line)
  end
end

--- Splits the arguments of the 'flux' command into the task, its KEY=VALUE options and
-- the remaining words.
-- @param args_str [String]
-- @return [String task, Map options (keys upper-cased), List<String> words]
local function parse_args(args_str)
  local words = {}
  local env = {}
  local task = nil

  for _, word in ipairs(string.Trim(args_str or ''):split(' ')) do
    if word != '' then
      local key, value = word:match('^([%w_]+)=(.*)$')

      if !task then
        task = word
      elseif key then
        env[key:upper()] = value
      else
        table.insert(words, word)
      end
    end
  end

  return task, env, words
end

concommand.Add('flux', function(actor, _cmd, _args, args_str)
  if IsValid(actor) then return end

  local task, env, words = parse_args(args_str)

  if !task then
    print_usage()
    return
  end

  if task:start_with('db:') then
    ActiveRecord.Tasks.run(task:sub(4), env, words)
  elseif task == 'generate' or task == 'g' then
    local success, result = pcall(ActiveRecord.Tasks.generate, words)

    if !success then
      ErrorNoHalt(tostring(result)..'\n')
    end
  else
    print_usage()
  end
end)
