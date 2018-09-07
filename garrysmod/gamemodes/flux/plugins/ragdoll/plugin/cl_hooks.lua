fl.bars:register("getup", {
  text = t"bar_text.getup",
  color = Color(50, 200, 50),
  maxValue = 100,
  x = ScrW() * 0.5 - fl.bars.defaultW * 0.5,
  y = ScrH() * 0.5 - 8,
  textOffset = 1,
  height = 20,
  type = BAR_MANUAL
})

function PLUGIN:PlayerBindPress(player, bind, bIsPressed)
  if bIsPressed and bind:find("jump") and player:IsDoingAction("fallen") then
    fl.command:Send("getup")
  end
end

function PLUGIN:HUDPaint()
  local fallen, getup = fl.client:IsDoingAction("fallen"), fl.client:IsDoingAction("getup")

  if (fallen or getup) and plugin.call("ShouldFallenHUDPaint") != false then
    local scrW, scrH = ScrW(), ScrH()

    draw.RoundedBox(0, 0, 0, scrW, scrH, Color(0, 0, 0, 100))

    if getup then
      local barValue = 100 - 100 * ((fl.client:get_nv("GetupEnd", 0) - CurTime()) / fl.client:get_nv("GetupTime"))

      fl.bars:SetValue("getup", barValue)
      fl.bars:Draw("getup")
    elseif fallen then
      local text = t'press_jump_to_getup'
      local w, h = util.text_size(text, theme.GetFont("Text_Normal"))

      draw.SimpleText(text, theme.GetFont("Text_Normal"), scrW * 0.5 - w * 0.5, scrH * 0.5 - h * 0.5, theme.GetColor("Text"))
    end
  end
end
