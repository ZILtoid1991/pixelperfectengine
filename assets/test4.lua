Globalstate = 0
SprtLayer = 0
MoveX = 1
MoveY = 1

--Script entry point
function Main(luastate)
    Globalstate = luastate
    SprtLayer = getLayer(16)
    addSprite(SprtLayer, getBitmapResource("dlangman"), 0, 0, 0, 0, 0, 255, 1024, 1024, 0)
    timer_register(Globalstate, 20, "UpdateFunc")
end

function UpdateFunc()
    relMoveSprite(SprtLayer, 0, MoveX, MoveY)
    local spritePos = getSpriteCoordinate(SprtLayer, 0)
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
