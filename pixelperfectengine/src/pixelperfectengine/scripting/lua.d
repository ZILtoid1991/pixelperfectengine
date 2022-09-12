module pixelperfectengine.scripting.lua;

import bindbc.lua;

/** 
 * Initializes the Lua scripting engine.
 * Returns: true if successful.
 */
public bool initLua() {
    LuaSupport ver = loadLua();
    return ver == LuaSupport.lua54;
}

public string createLuaCaller() {
    return null;
}