module pixelperfectengine.scripting.lualib;

import pixelperfectengine.scripting.lua;

import pixelperfectengine.graphics.layers.interfaces;
import pixelperfectengine.graphics.layers.base;

import bindbc.lua;
/** 
 * Registers the PPE standard library for a Lua script, so engine functions can be called through a Lua script.
 * Params:
 *   state = 
 */
public void registerLibForScripting(lua_State* state) {
	lua_register(state, "scrollLayer", &registerDFunction!scrollLayer);
	lua_register(state, "relScrollLayer", &registerDFunction!relScrollLayer);
	lua_register(state, "getLayerScrollX", &registerDFunction!getLayerScrollX);
	lua_register(state, "getLayerScrollY", &registerDFunction!getLayerScrollY);
}
package void scrollLayer(void* target, int x, int y) {
	Layer l = cast(Layer)target;
	l.scroll(x, y);
}
package void relScrollLayer(void* target, int x, int y) {
	Layer l = cast(Layer)target;
	l.relScroll(x, y);
}
package int getLayerScrollX(void* target) @nogc nothrow {
	Layer l = cast(Layer)target;
	return l.getSX();
}
package int getLayerScrollY(void* target) @nogc nothrow {
	Layer l = cast(Layer)target;
	return l.getSY();
}
