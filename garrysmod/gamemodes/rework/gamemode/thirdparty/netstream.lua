--[[ 
	Netstream © Alex Grist
	Distributed under MIT license.
	http://github.com/alexgrist/netstream
--]]

if (netstream) then return; end;

local net = net;
local ErrorNoHalt = ErrorNoHalt;
local pairs = pairs;
local pcall = pcall;
local type = type;
local util = util;

netstream = netstream or {};
local stored = {};

if (DBugR) then
	DBugR.Profilers.Netstream = table.Copy(DBugR.SP);
	DBugR.Profilers.Netstream.CChan = "";
	DBugR.Profilers.Netstream.Name = "Netstream";
	DBugR.Profilers.Netstream.Type = SERVICE_PROVIDER_TYPE_NET;

	DBugR.Profilers.NetstreamPerf = table.Copy(DBugR.SP);
	DBugR.Profilers.NetstreamPerf.Name = "Netstream";
	DBugR.Profilers.NetstreamPerf.Type = SERVICE_PROVIDER_TYPE_CPU;
end;

-- A function to split data for a data stream.
function netstream.Split(data)
	local index = 1;
	local result = {};
	local buffer = {};

	for i = 0, string.len(data) do
		buffer[#buffer + 1] = string.sub(data, i, i);

		if (#buffer == 32768) then
			result[#result + 1] = table.concat(buffer);
				index = index + 1;
			buffer = {};
		end;
	end;

	result[#result + 1] = table.concat(buffer);

	return result;
end;

--[[
	@codebase Shared
	@details A function to hook a data stream.
	@param String A unique identifier.
	@param Function The datastream callback.
--]]
function netstream.Hook(name, Callback)
	stored[name] = Callback;
end;

if (DBugR) then
	local oldDS = netstream.Hook;

	for name, func in pairs(stored) do
		stored[name] = nil;

		oldDS(name, DBugR.Util.Func.AttachProfiler(func, function(time) 
			DBugR.Profilers.NetstreamPerf:AddPerformanceData(tostring(name), time, func);
		end));
	end;

	netstream.Hook = DBugR.Util.Func.AddDetourM(netstream.Hook, function(name, func, ...) 
		func = DBugR.Util.Func.AttachProfiler(func, function(time) 
			DBugR.Profilers.NetstreamPerf:AddPerformanceData(tostring(name), time, func);
		end);

		return name, func, ...;
	end);
end;

if (SERVER) then
	util.AddNetworkString("NetStreamDS");

	-- A function to start a net stream.
	function netstream.Start(player, name, ...)
		local recipients = {};
		local bShouldSend = false;

		if (type(player) != "table") then
			if (!player) then
				player = _player.GetAll();
			else
				player = {player};
			end;
		end;

		for k, v in ipairs(player) do
			if (type(v) == "Player") then
				recipients[#recipients + 1] = v;

				bShouldSend = true;
			end;
		end;

		local dataTable = {...};
		local encodedData = pon.encode(dataTable);

		if (encodedData and #encodedData > 0 and bShouldSend) then
			net.Start("NetStreamDS");
				net.WriteString(name);
				net.WriteUInt(#encodedData, 32);
				net.WriteData(encodedData, #encodedData);
			net.Send(recipients);
		end;
	end;

	if (DBugR) then
		netstream.Start = DBugR.Util.Func.AddDetour(netstream.Start, function(player, name, ...)
			local dataTable = {...};
			local encodedData = pon.encode(dataTable);

			DBugR.Profilers.Netstream:AddNetData(name, #encodedData);
		end);
	end;

	-- A function to listen for a request.
	function netstream.Listen(name, Callback)
		netstream.Hook(name, function(player, data)
			local bShouldReply, reply = Callback(player, data);

			if (bShouldReply) then
				netstream.Start(player, name, reply);
			end;
		end);
	end;
	
	net.Receive("NetStreamDS", function(length, player)
		local NS_DS_NAME = net.ReadString();
		local NS_DS_LENGTH = net.ReadUInt(32);
		local NS_DS_DATA = net.ReadData(NS_DS_LENGTH);

		if (NS_DS_NAME and NS_DS_DATA and NS_DS_LENGTH) then
			player.nsDataStreamName = NS_DS_NAME;
			player.nsDataStreamData = "";

			if (player.nsDataStreamName and player.nsDataStreamData) then
				player.nsDataStreamData = NS_DS_DATA;

				if (stored[player.nsDataStreamName]) then
					local bStatus, value = pcall(pon.decode, player.nsDataStreamData);

					if (bStatus) then
						stored[player.nsDataStreamName](player, unpack(value));
					else
						ErrorNoHalt("NetStream: '"..NS_DS_NAME.."'\n"..value.."\n");
					end;
				end;

				player.nsDataStreamName = nil;
				player.nsDataStreamData = nil;
			end;
		end;

		NS_DS_NAME, NS_DS_DATA, NS_DS_LENGTH = nil, nil, nil;
	end);
else
	-- A function to start a net stream.
	function netstream.Start(name, ...)
		local dataTable = {...};
		local encodedData = pon.encode(dataTable);

		if (encodedData and #encodedData > 0) then
			net.Start("NetStreamDS");
				net.WriteString(name);
				net.WriteUInt(#encodedData, 32);
				net.WriteData(encodedData, #encodedData);
			net.SendToServer();
		end;
	end;

	if (DBugR) then
		netstream.Start = DBugR.Util.Func.AddDetour(netstream.Start, function(name, ...)
			local dataTable = {...};
			local encodedData = pon.encode(dataTable);

			DBugR.Profilers.Netstream:AddNetData(name, #encodedData);
		end);
	end;

	-- A function to send a request.
	function netstream.Request(name, data, Callback)
		netstream.Hook(name, Callback);		
		netstream.Start(name, data);
	end;

	net.Receive("NetStreamDS", function(length)
		local NS_DS_NAME = net.ReadString();
		local NS_DS_LENGTH = net.ReadUInt(32);
		local NS_DS_DATA = net.ReadData(NS_DS_LENGTH);

		if (NS_DS_NAME and NS_DS_DATA and NS_DS_LENGTH) then
			if (stored[NS_DS_NAME]) then
				local bStatus, value = pcall(pon.decode, NS_DS_DATA);

				if (bStatus) then
					stored[NS_DS_NAME](unpack(value));
				else
					ErrorNoHalt("NetStream: '"..NS_DS_NAME.."'\n"..value.."\n");
				end;
			end;
		end;

		NS_DS_NAME, NS_DS_DATA, NS_DS_LENGTH = nil, nil, nil;
	end);
end;