--[[ 
	Rework © 2016 TeslaCloud Studios
	Do not share, re-distribute or sell.
--]]

library.New("sound", rw);

local cache = rw.sound.cache or {};
rw.sound.cache = cache;

function rw.sound:Download(url, saveAs, callback)
	if (!file.Exists("rw_sounds", "DATA")) then
		file.CreateDir("rw_sounds");
	end;

	if (!file.Exists("rw_sounds/"..saveAs..".txt", "DATA")) then
		http.Fetch(url, function(body, length, headers, code)
			print("[Rework] Downloaded sound: data/rw_sounds/"..saveAs..".txt");
			file.Write("rw_sounds/"..saveAs..".txt", body);

			if (callback) then
				callback();
			end;
		end);
	end;
end;

function rw.sound:Create(fileName, id)
	fileName = "rw_sounds/"..fileName..".txt";

	cache[fileName] = cache[fileName] or {};

	sound.PlayFile(fileName, "noblock noplay", function(channel, errID, errName)
		if (errID) then
			print("[Rework:PlaySound] Error ID: "..errID.."; Error Name: "..errName);
			return;
		end;

		channel:SetVolume(0.4);

		cache[fileName][id] = channel;
	end);

	return cache[fileName][id];
end;

function rw.sound:Find(fileName, id)
	fileName = "rw_sounds/"..fileName..".txt";

	if (cache[fileName] and cache[fileName][id]) then
		return cache[fileName][id];
	end;
end;

function rw.sound:Remove(fileName, id)
	local channel = self:Find(fileName, id);

	if (channel) then
		channel:Pause();
		channel:Stop();

		cache[fileName][id] = nil;
	end;
end;

function rw.sound:Play(fileName, id)
	local channel = self:Find(fileName, id);

	if (channel) then
		channel:Play();
	end;
end;

function rw.sound:Pause(fileName, id)
	local channel = self:Find(fileName, id);

	if (channel) then
		channel:Pause();
	end;
end;

--[[
function rw.sound:PlayFromURL(url, saveAs, id)
	cache["rw_sounds/"..saveAs..".txt"] = cache["rw_sounds/"..saveAs..".txt"] or {};

	if (!file.Exists("rw_sounds", "DATA")) then
		file.CreateDir("rw_sounds");
	end;

	if (!file.Exists("rw_sounds/"..saveAs..".txt", "DATA")) then
		http.Fetch(url, function(body, length, headers, code)
			print("[Rework] Downloaded sound: data/rw_sounds/"..saveAs..".txt");
			file.Write("rw_sounds/"..saveAs..".txt", body);

			sound.PlayFile("rw_sounds/"..saveAs..".txt", "noblock noplay", function(channel, errID, errName)
				if (errID) then
					print("[Rework:PlaySound] Error ID: "..errID.."; Error Name: "..errName);
					return;
				end;

				channel:SetVolume(0.4);
				channel:Play();

				cache["rw_sounds/"..saveAs..".txt"][id] = channel;
			end);
		end);
	end;

	return cache["rw_sounds/"..saveAs..".txt"][id];
end;
--]]

function rw.sound:PlayFromURL(url, volume)
	sound.PlayURL(url, "noblock", function(channel, errID, errName)
		if (errID) then
			print(errID, errName);
			return;
		end;

		if (cache[url]) then
			cache[url]:Stop();
		end;

		if (volume) then
			channel:SetVolume(volume);
		end;

		cache[url] = channel;
	end);
end;