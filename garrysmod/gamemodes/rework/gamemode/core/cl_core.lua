--[[
	Rework © 2016-2017 TeslaCloud Studios
	Do not share or re-distribute before
	the framework is publicly released.
--]]

DeriveGamemode("sandbox")

function rw.core:DrawScaledText(text, font, x, y, scale, color)
	local matrix = Matrix()

	matrix:Translate(Vector(x, y))
	matrix:Scale(Vector(1, 1, 1) * scale)
	matrix:Translate(-Vector(x, y))

	cam.PushModelMatrix(matrix)
		surface.SetFont(font)
		surface.SetTextColor(color)
		surface.SetTextPos(x, y)
		surface.DrawText(text)
	cam.PopModelMatrix()
end