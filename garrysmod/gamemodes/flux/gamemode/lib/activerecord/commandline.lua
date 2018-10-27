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
