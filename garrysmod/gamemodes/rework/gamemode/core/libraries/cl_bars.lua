--[[ 
	Rework © 2016 TeslaCloud Studios
	Do not share, re-distribute or sell.
--]]

library.New("bars", rw);

local stored = rw.bars.stored or {};
rw.bars.stored = stored;

local sorted = rw.bars.sorted or {};
rw.bars.sorted = sorted;

-- Some fail-safety variables.
rw.bars.defaultX = 8;
rw.bars.defaultY = 8;
rw.bars.defaultW = ScrW() / 4;
rw.bars.defaultH = 18;
rw.bars.drawing = rw.bars.drawing or 0; -- Amount of bars currently being drawn.

function rw.bars:Register(uniqueID, data, force)
	if (!data) then return; end;

	if (stored[uniqueID] and !force) then
		return stored[uniqueID];
	end;

	stored[uniqueID] = {
		uniqueID = uniqueID,
		text = data.text or "",
		color = data.color or Color(200, 90, 90),
		maxValue = data.maxValue or 100,
		hinderColor = data.hinderColor or Color(255, 0, 0),
		hinderText = data.hinderText or "",
		display = data.display or 100,
		minDisplay = data.minDisplay or 0,
		hinderDisplay = data.hinderDisplay or false,
		value = data.value or 0,
		hinderValue = data.hinderValue or 0,
		x = data.x or self.defaultX,
		y = data.y or self.defaultY,
		width = data.width or self.defaultW,
		height = data.height or self.defaultH,
		cornerRadius = data.cornerRadius or 2,
		priority = data.priority or table.Count(stored),
		type = data.type or BAR_TOP,
		font = data.font or "bar_text"
	};

	return stored[uniqueID];
end;

function rw.bars:Get(uniqueID)
	if (stored[uniqueID]) then
		return stored[uniqueID];
	end

	return false;
end;

function rw.bars:SetValue(uniqueID, newValue)
	local bar = self:Get(uniqueID);

	if (bar) then
		bar.value = newValue;
	end
end;

function rw.bars:Prioritize()
	for k, v in pairs(stored) do
		sorted[v.priority] = sorted[v.priority] or {};

		if (v.type == BAR_TOP) then
			table.insert(sorted[v.priority], v);
		end;
	end

	return sorted;
end;

function rw.bars:Draw(uniqueID)
	local barInfo = self:Get(uniqueID);

	if (barInfo) then
		plugin.Call("PreDrawBar", barInfo);

		if (!plugin.Call("ShouldDrawBar", barInfo) and (barInfo.display < barInfo.value or barInfo.minDisplay >= barInfo.value)) then
			return;
		end;

		local cornerRadius = barInfo.cornerRadius;
		local width = barInfo.width;
		local height = barInfo.height;

		if (!plugin.Call("DrawBarBackground", barInfo)) then
			draw.RoundedBox(cornerRadius, barInfo.x, barInfo.y, width, height, Color(40, 40, 40));
		end;

		if (plugin.Call("ShouldFillBar", barInfo) or barInfo.value != 0) then
			if (!plugin.Call("DrawBarFill", barInfo)) then
				draw.RoundedBox(cornerRadius, barInfo.x + 1, barInfo.y + 1, (barInfo.fillWidth or width) - 2, height - 2, barInfo.color);
			end;
		end;

		if (barInfo.hinderDisplay) then
			if (!plugin.Call("DrawBarHindrance", barInfo)) then
				local length = width * (barInfo.hinderValue / barInfo.maxValue);

				draw.RoundedBox(cornerRadius, barInfo.x + width - length - 1, barInfo.y + 1, length, height - 2, barInfo.hinderColor);
			end;
		end;

		if (!plugin.Call("DrawBarTexts", barInfo)) then
			draw.SimpleText(barInfo.text, barInfo.font, barInfo.x + 4, barInfo.y, Color(255, 255, 255));

			if (barInfo.hinderDisplay) then
				local textWide = util.GetTextSize(barInfo.font, barInfo.hinderText);

				render.SetScissorRect(barInfo.x + width - length, barInfo.y, barInfo.x + width, barInfo.y + height, true);
					draw.SimpleText(barInfo.hinderText, barInfo.font, barInfo.x + width - textWide - 8, barInfo.y - 1, Color(255, 255, 255));
				render.SetScissorRect(0, 0, 0, 0, false);
			end
		end;
	end;
end;

do
	local rwBars = {};

	function rwBars:LazyTick()
		for k, v in pairs(stored) do
			plugin.Call("AdjustBarInfo", k, stored[k]);
		end;
	end;

	function rwBars:PreDrawBar(bar)
		bar.fillWidth = bar.width * (bar.value / bar.maxValue);
		bar.text = string.utf8upper(rw.lang:TranslateText(bar.text));
		bar.hinderText = string.utf8upper(rw.lang:TranslateText(bar.hinderText));
	end;

	plugin.AddHooks("RWBarHooks", rwBars);
end;