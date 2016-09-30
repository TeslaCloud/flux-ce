--[[ 
	Rework © 2016 TeslaCloud Studios
	Do not share, re-distribute or sell.
--]]

library.New("command", rw);
rw.command.stored = rw.command.stored or {};
rw.command.aliases = rw.command.aliases or {};

function rw.command:Create(id, data)
	data.uniqueID = id:utf8lower();
	data.name = data.name or "Unknown";
	data.description = data.description or "An undescribed command.";
	data.syntax = data.syntax or "[none]";
	data.immunity = data.immunity or false;
	data.playerArg = nil;
	data.arguments = data.arguments or 0;

	self.stored[id] = data;

	-- Add original command name to aliases table.
	self.aliases[id] = id:utf8lower();

	if (data.aliases) then
		for k, v in ipairs(data.aliases) do
			self.aliases[v] = id;
		end;
	end;

	rw.admin:PermissionFromCommand(data);
end;

function rw.command:Find(id)
	id = id:utf8lower();

	if (self.stored[id]) then return self.stored[id]; end;
	if (self.aliases[id]) then return self.stored[self.aliases[id]]; end;

	for k, v in pairs(self.aliases) do
		if (k:find(id)) then
			return self.stored[v];
		end;
	end;
end;

function rw.command:FindByID(id)
	id = id:utf8lower();

	if (self.stored[id]) then return self.stored[id]; end;
	if (self.aliases[id]) then return self.stored[self.aliases[id]]; end;
end;

-- A function to find all commands by given search string.
function rw.command:FindAll(id)
	local hits = {};

	for k, v in pairs(self.aliases) do
		if (k:find(id) or v:find(id)) then
			table.insert(hits, v);
		end;
	end;

	return hits;
end;

function rw.command:ExtractArguments(text)
	local arguments = {};
	local word = "";
	local skip = 0;

	for i = 1, #text do
		if (skip > 0) then
			skip = skip - 1;
			continue;
		end;

		local char = text:utf8sub(i, i);

		if ((char == "\"" or char == "'") and word == "") then
			local endPos = text:find("\"", i + 1);

			if (!endPos) then
				endPos = text:find("'", i + 1);
			end;

			if (endPos) then
				table.insert(arguments, text:utf8sub(i + 1, endPos - 1));

				skip = endPos - i;
			else
				word = word..char;
			end;
		elseif (char == " ") then
			if (word != "") then
				table.insert(arguments, word);
				word = "";
			end;
		else
			word = word..char;
		end;
	end;

	if (word != "") then
		table.insert(arguments, word);
	end;

	return arguments;
end;

if (SERVER) then
	function rw.command:Interpret(player, text)
		local args;

		if (typeof(text) == "table") then
			args = text;
		else
			args = self:ExtractArguments(text);
		end;

		local command = args[1]:utf8lower();
		table.remove(args, 1);

		local cmdTable = self:FindByID(command);

		if (cmdTable) then
			if ((!IsValid(player) and !cmdTable.noConsole) or player:HasPermission(cmdTable.uniqueID)) then
				if (cmdTable.arguments == 0 or cmdTable.arguments <= #args) then
					if (cmdTable.immunity or cmdTable.playerArg != nil) then
						local targetArg = args[(cmdTable.playerArg or 1)];
						local target = _player.Find(targetArg, true);

						if (IsValid(target)) then
							if (cmdTable.immunity and !rw.admin:CheckImmunity(player, target, cmdTable.canBeEqual)) then
								rw.player:Notify(player, L("Commands_HigherImmunity", target:Name()));
								return;
							end;

							-- one step less for commands.
							args[(cmdTable.playerArg or 1)] = target;
						else
							if (IsValid(player)) then
								rw.player:Notify(player, L("Commands_PlayerInvalid", targetArg));
							else
								ErrorNoHalt("'"..targetArg.."' is not a valid player!\n");
							end;

							return;
						end;
					end;

					-- Let plugins hook into this and abort command's execution of necessary.
					if (!plugin.Call("PlayerRunCommand", player, cmdTable, args)) then
						if (IsValid(player)) then
							ServerLog(player:Name().." has used /"..cmdTable.name.." "..text:utf8sub(cmdTable.name:utf8len() + 2, text:utf8len()));
						end;

						self:Run(player, cmdTable, args);
					end;
				else
					rw.player:Notify(player, "/"..cmdTable.name.." "..cmdTable.syntax);
				end;
			else
				if (IsValid(player)) then
					rw.player:Notify(player, "#Commands_NoAccess");
				else
					ErrorNoHalt("[Rework] This command cannot be run from console!\n");
				end;
			end;
		else
			if (IsValid(player)) then
				rw.player:Notify(player, L("Commands_NotValid", command));
			else
				ErrorNoHalt("'"..command.."' is not a valid command!\n");
			end;
		end;
	end;

	-- Warning: this function assumes that command is valid and all permission checks have been done.
	function rw.command:Run(player, cmdTable, arguments)
		if (cmdTable.OnRun) then
			local success, result = pcall(cmdTable.OnRun, cmdTable, player, unpack(arguments));

			if (!success) then
				ErrorNoHalt("[Rework] "..cmdTable.uniqueID.." command has failed to run!\n");
				ErrorNoHalt(result.."\n");
			end;
		end;
	end;

	concommand.Add("reCmd", function(player, cmd, args)
		rw.command:Interpret(player, args);
	end)

	concommand.Add("rwc", function(player, cmd, args)
		rw.command:Interpret(player, args);
	end)
end;