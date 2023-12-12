Globalstate = 0

MoveX = 1
MoveY = 1

--Script initialization
function Initialize()
    addSprite(16, "dlangman", 0, 0, 0, 0, 255, 1024, 1024)
end
--Make D man bounce on the screen
function UpdateFunc()
    relMoveSprite(16, 0, MoveX, MoveY)
    local spritePos = getSpriteCoordinate(16, 0)
    --test sprite if it touched the edges
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