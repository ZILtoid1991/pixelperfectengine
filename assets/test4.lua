Globalstate = 0
Titlescreen = true

--Script entry point
function Main(luastate)
    Globalstate = luastate
    local sprtLayer = getLayer(16)
    addSprite(sprtLayer, getBitmapResource("Titlescreen"), 0, 0, 0, 0, 0, 255, 1024, 1024, 0)
end
--Horrible tone generator, using the engine's own RNG
function OnNextNote_Title()
    local r = rng_Seed()
    local audioModule = getAudioModule(0)
    --Melody 1
    midiCMD(audioModule, 0x40803c00 + ((r % 18) * 256), 0xFFFF0000, 0x00000000, 0x00000000)
    r = rng_Seed()
    --Melody 2
    midiCMD(audioModule, 0x40813000 + ((r % 20) * 256), 0xFFFF0000, 0x00000000, 0x00000000)
    r = rng_Seed()
    --Bass
    if (r % 12) > 5 then 
        r = rng_Seed()
        midiCMD(audioModule, 0x40821600 + ((r % 12) * 256), 0xFFFF0000, 0x00000000, 0x00000000)
    end
    --Rhythm
    r = rng_Seed()
    --Cymbals
    if (r % 20) == 0 then
        midiCMD(audioModule, 0x40836000, 0xFFFF0000, 0x00000000, 0x00000000)
    else
        midiCMD(audioModule, 0x40846000, 0xFFFF0000, 0x00000000, 0x00000000)
    end
    --Kick
    if (r % 7) == 0 then
        midiCMD(audioModule, 0x40852000, 0xFFFF0000, 0x00000000, 0x00000000)
    end
    --Snare
    if (r % 9) == 0 then
        midiCMD(audioModule, 0x40856000, 0xFFFF0000, 0x00000000, 0x00000000)
    end
    
    if Titlescreen then
        timer_register(Globalstate, 250, "OnNextNote_Title")
    end
end

function ToSelection()
    Titlescreen = false
end

