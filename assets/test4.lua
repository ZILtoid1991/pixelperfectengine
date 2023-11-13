Globalstate = 0

MoveX = 1
MoveY = 1

--Script entry point
function Main(luastate)
    Globalstate = luastate
    local sprtLayer = getLayer(16)
    local dlangman = getBitmapResource("dlangman")
    addSprite(SprtLayer, dlangman, 0, 0, 0, 0, 0, 255, 1024, 1024, 0)
    timer_register(Globalstate, 20, "UpdateFunc")
    return 0
end
--Make D man bounce on the screen
function UpdateFunc()
    local sprtLayer = getLayer(16)
    relMoveSprite(sprtLayer, 0, MoveX, MoveY)
    local spritePos = getSpriteCoordinate(sprtLayer, 0)
    if spritePos.left <= 0 then
        MoveX = 1
    end
    if spritePos.right >= 423 then
        MoveX = -1
    end
    if spritePos.top <= 0 then
        MoveY = 1
    end
    if spritePos.bottom >= 239 then
        MoveY = -1
    end
end