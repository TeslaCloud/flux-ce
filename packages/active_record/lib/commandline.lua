local hold_start = nil

concommand.Add('ar_recreate_schema', function(player)
  if !IsValid(player) then
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

concommand.Add('flux', function(player, cmd, args, args_str)
  if !IsValid(player) then
    local args = args_str:split(' ')

    if args[1] == 'db:create' then
      ActiveRecord.Database:setup(ActiveRecord.db_settings)
    elseif args[1] == 'db:drop' then
      ActiveRecord.Database:drop_database(ActiveRecord.db_settings)
    end
  end
end)
