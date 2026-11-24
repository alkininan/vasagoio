local root = (arg and arg[1]) or "."
local width, height = 2560, 1440
UIParent = {GetWidth = function() return width end, GetHeight = function() return height end}
CreateFrame = function() return {RegisterEvent = function() end, SetScript = function() end} end
local V = {}
assert(loadfile(root .. "/Core.lua"))("vasagoio", V)
V.db = {layoutScale = 1}
local function near(a, b) assert(math.abs(a-b) < .000001, tostring(a) .. " differs from " .. tostring(b)) end
for _, dimensions in ipairs({{2560,1440}, {3440,1440}, {1920,1200}}) do
    width, height = unpack(dimensions)
    local ox, oy = V:CanvasOrigin()
    -- FUF stores center offsets; Bartender/HUD store absolute corner offsets.
    local playerX, playerY, frameWidth, frameHeight = 884, 1098, 320, 64
    local fufLeft = width/2 + V:Pixel(playerX + frameWidth/2 - 1280) - V:Pixel(frameWidth/2)
    local fufTop = height/2 - V:Pixel(720 - playerY - frameHeight/2) - V:Pixel(frameHeight/2)
    near(fufLeft, ox + V:Pixel(playerX))
    near(fufTop, oy + V:Pixel(playerY))
    near(2*ox + V:Pixel(2560), width)
    near(2*oy + V:Pixel(1440), height)
end
width, height = 3440, 1440
local ox, oy = V:CanvasOrigin(); near(ox,440); near(oy,0)
width, height = 1920, 1200
ox, oy = V:CanvasOrigin(); near(ox,0); near(oy,60)
V.db.layoutScale = .8
ox, oy = V:CanvasOrigin()
near(2*ox + V:Pixel(2560), width); near(2*oy + V:Pixel(1440), height)
print("canvas_spec: centered design anchors align at 16:9, ultrawide, 16:10 and custom scale")
