--- Server console commands of ActiveRecord. `flux db:<task>` runs one of the database
-- tasks of `ActiveRecord.Tasks` (`flux db:migrate`, `flux db:rollback STEP=2`,
-- `flux db:schema:dump` and so on), and `flux generate migration <Name> [column:type ...]`
-- writes a new migration file with `ActiveRecord::MigrationGenerator`; anything else
-- prints the list of tasks. `ar_recreate_schema` wipes and recreates the whole database
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

local usage = txt[[
  Usage: flux <task> [KEY=VALUE ...]

  Database tasks:
    flux db:migrate [VERSION=x]        run the pending migrations, or migrate to a version
    flux db:migrate:status             list the migrations and whether they have been run
    flux db:migrate:up VERSION=x       run a single migration
    flux db:migrate:down VERSION=x     revert a single migration
    flux db:migrate:redo [STEP=n]      revert and re-run the newest migration(s)
    flux db:rollback [STEP=n]          revert the newest migration(s)
    flux db:forward [STEP=n]           run the next pending migration(s)
    flux db:version                    print the current schema version
    flux db:schema:dump                write the schema into db/schema.lua
    flux db:schema:load                create the tables of db/schema.lua
    flux db:create                     create the database (PostgreSQL only)
    flux db:drop                       drop the database

  Generators:
    flux generate migration <Name> [column:type ...]
      e.g. flux generate migration AddRoleToUsers role:string
           flux g migration CreateItems name:string owner:references
]]

--- Splits the arguments of the 'flux' command into the task, its KEY=VALUE options and
-- the remaining words.
-- @param args_str [String]
-- @return [String task, Map options (keys upper-cased), List<String> words]
local function parse_args(args_str)
  local words = {}
  local env = {}
  local task = nil

  for k, v in ipairs(string.Trim(args_str or ''):split(' ')) do
    if v != '' then
      local key, value = v:match('^([%w_]+)=(.*)$')

      if !task then
        task = v
      elseif key then
        env[key:upper()] = value
      else
        table.insert(words, v)
      end
    end
  end

  return task, env, words
end

concommand.Add('flux', function(actor, cmd, args, args_str)
  if IsValid(actor) then return end

  local task, env, words = parse_args(args_str)

  if !task then
    print(usage)
    return
  end

  if task:start_with('db:') then
    ActiveRecord.Tasks.run(task:sub(4), env)
  elseif task == 'generate' or task == 'g' then
    if words[1] != 'migration' or !words[2] then
      print(usage)
      return
    end

    local generator = ActiveRecord.MigrationGenerator.new(words[2], { unpack(words, 3) })
    local success, result = pcall(generator.generate, generator)

    if success then
      print('Generated migration:\n-> '..result)
    else
      ErrorNoHalt(tostring(result)..'\n')
    end
  else
    print(usage)
  end
end)
