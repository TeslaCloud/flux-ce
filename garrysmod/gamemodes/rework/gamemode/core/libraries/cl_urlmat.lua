--[[ 
	Rework © 2016 TeslaCloud Studios
	Do not share, re-distribute or sell.
--]]

library.New("urlmat", rw);
local cache = rw.urlmat.cache or {};
rw.urlmat.cache = cache;

local gifcache = rw.urlmat.gifcache or {};
rw.urlmat.gifcache = gifcache;

local loading = {};

function rw.urlmat:CacheMaterial(url)
	if (isstring(url) and url != "") then
		local urlCRC = util.CRC(url);
		local exploded = string.Explode("/", url);

		if (istable(exploded) and #exploded > 0) then
			local extension = string.GetExtensionFromFilename(exploded[#exploded]);

			if (extension) then
				local extension = "."..extension;
				local path = "rework/materials/"..urlCRC..extension;

				if (_file.Exists(path, "DATA")) then
					cache[urlCRC] = Material("../data/"..path, "noclamp smooth"); 
					return;
				end;

				local directories = string.Explode("/", path);
				local currentPath = "";

				for k, v in pairs(directories) do
					if (k < #directories) then
						currentPath = currentPath..v.."/";
						file.CreateDir(currentPath);
					end;
				end;

				http.Fetch(url, function(body, length, headers, code)
					path = path:gsub(".jpeg", ".jpg");
					file.Write(path, body);
					cache[urlCRC] = Material("../data/"..path, "noclamp smooth");

					plugin.Call("OnURLMatLoaded", url, cache[urlCRC]);
				end);
			end;
		end;
	end;
end;

local placeholder = Material("vgui/wave");

function URLMaterial(url)
	local urlCRC = util.CRC(url);

	if (cache[urlCRC]) then
		return cache[urlCRC];
	end;

	if (!loading[urlCRC]) then
		rw.urlmat:CacheMaterial(url);
		loading[urlCRC] = true; -- we're in progress!
	end;

	return placeholder; -- return some placeholder material while we download
end;

-- Gonna comment this out now and get to it later.
--[[

local function OpenHTMLPanel(url)
	local panel = vgui.Create("DHTML");

//	panel:Dock(FILL);
	panel:OpenURL(url);
//	panel:SetAlpha(255);
	panel:MoveToBack();
	panel:SetMouseInputEnabled(false);
	panel:SetKeyboardInputEnabled(false);
	panel:SetPaintedManually(true);

	function panel:ConsoleMessage(msg) end;

	-- This could possibly override some sort of function
	-- for closing the webpage or whatnot, keep an eye on this.
	function panel:OnRemove()
		cache[url] = nil;
	end;

	gifcache[url] = panel;

	return gifcache[url];
end;

function rw.urlmat.ClearGifCache()
	for k, v in pairs(rw.urlmat.gifcache) do
		v:Remove();
	end;

	rw.urlmat.gifcache = {};
end;

rw.urlmat.ClearGifCache()


function URLGIF(url, w, h)
	if (cache[url]) then
		return cache[url];
	end;

	local panel = gifcache[url];

	if (!panel) then
		panel = OpenHTMLPanel(url);
	end;
	
	local mat = panel:GetHTMLMaterial();

	if (panel and mat) then
		local matName = mat:GetName();
		local matData = {
			["$basetexture"] = matName,
			["$basetexturetransform"] = "scale "..w.." "..h,
			["$model"] = 1
		};

		local id = matName:gsub("__vgui_texture_", "");

		cache[url] = CreateMaterial("GifMat_"..id, "UnlitGeneric", matData);

		return cache[url];
	end;

	return placeholder;
end;

function URLGIF(url, x, y, w, h)
	local panel = gifcache[url];

	if (!panel) then
		panel = OpenHTMLPanel(url);
	end;

	if (panel) then
		if (panel.x != x or panel.y != y) then
			panel:SetPos(x, y);
		end;

		if (panel:GetWide() != w or panel:GetTall() != h) then
			panel:SetSize(w, h);
		end;

		print(panel:GetSize(), panel:GetPos());

		panel:PaintManual();
	end;
end;

--]]