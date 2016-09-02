--[[ 
	Rework © 2016 Mr. Meow and NightAngel
	Do not share, re-distribute or sell.
--]]

library.New("player", rw);

if (SERVER) then
	function rw.player:Notify(player, message)
		if (!IsValid(player)) then
			print("[Notification] "..message);
			return;
		end;

		netstream.Start(player, "reNotification", message);
	end;

	function rw.player:NotifyAll(message)
		ServerLog("NOTIFY - "..message);

		netstream.Start(nil, "reNotification", message);
	end;
else
	netstream.Hook("reNotification", function(message)
		chat.AddText(Color(40, 40, 255), "[Notification] ", Color(255, 255, 255), message);
	end);
end;