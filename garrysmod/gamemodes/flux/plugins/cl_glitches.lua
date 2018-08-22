PLUGIN:SetName("Glitches")
PLUGIN:SetAuthor("Mr. Meow")
PLUGIN:SetDescription("Adds the ability to create pixelized glitch effects on the screen.")

do
  local nextGlitch = 0
  local glitches = {}

  function PLUGIN:FLHUDPaint(curTime, w, h)
    if (false and hook.Run("ShouldDrawDeathGlitches") != false) then
      for k, v in ipairs(glitches) do
        glitches[k].c = ColorAlpha(v.c, Lerp(FrameTime() * 8, v.c.a, 0))

        draw.RoundedBox(0, v.x, v.y, v.w, v.h, v.c)
      end

      if (nextGlitch <= curTime) then
        glitches = {}

        local nGlitches = math.random(1, 4)

        for i = 1, nGlitches do
          table.insert(glitches, {
            x = math.random(1, w - 256),
            y = math.random(1, h - 48),
            w = math.random(64, 256),
            h = math.random(32, 40),
            c = Color(math.random(220, 255), math.random(220, 255), math.random(220, 255), math.random(125, 200))
          })
        end

        nextGlitch = curTime + math.Rand(0.2, 0.6)
      end
    end
  end
end
