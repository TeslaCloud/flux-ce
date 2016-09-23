if (SERVER) then
	concommand.Add("rwThirdPerson", function(player)
		
	end);
else
	rw.binds.AddBind("ToggleThirdPerson", "rwThirdPerson", KEY_X);
end;