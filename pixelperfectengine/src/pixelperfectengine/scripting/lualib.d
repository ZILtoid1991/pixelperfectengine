module pixelperfectengine.scripting.lualib;

import pixelperfectengine.scripting.lua;
import pixelperfectengine.scripting.globals;

import pixelperfectengine.graphics.layers.interfaces;
import pixelperfectengine.graphics.layers.base;
import pixelperfectengine.graphics.layers.trnstilelayer;
import pixelperfectengine.graphics.raster;
import pixelperfectengine.graphics.bitmap;

import pixelperfectengine.system.file;

import pixelperfectengine.audio.base.modulebase;

import bindbc.lua;

import std.conv : to;
import std.string : toLowerInPlace;
/** 
 * Registers the PPE standard library for a Lua script, so engine functions can be called through a Lua script.
 * Params:
 *   state = the state where the scripts need to be registered.
 */
public void registerLibForScripting(lua_State* state) {
	lua_register(state, "setPaletteIndex", &registerDFunction!setPaletteIndex);
	lua_register(state, "getPaletteIndex", &registerDFunction!getPaletteIndex);
	lua_register(state, "getLayer", &registerDFunction!getLayer);

	lua_register(state, "getLayerType", &registerDFunction!(getLayerType));
	lua_register(state, "setLayerRenderingMode", &registerDFunction!setLayerRenderingMode);
	lua_register(state, "scrollLayer", &registerDFunction!(scrollLayer));
	lua_register(state, "relScrollLayer", &registerDFunction!(relScrollLayer));
	lua_register(state, "getLayerScrollX", &registerDDelegate!(Layer.getSX));
	lua_register(state, "getLayerScrollY", &registerDDelegate!(Layer.getSY));

	lua_register(state, "readMapping", &registerDFunction!readMapping);
	lua_register(state, "tileByPixel", &registerDFunction!tileByPixel);
	lua_register(state, "writeMapping", &registerDFunction!writeMapping);
	lua_register(state, "getTileWidth", &registerDDelegate!(ITileLayer.getTileWidth));
	lua_register(state, "getTileHeight", &registerDDelegate!(ITileLayer.getTileHeight));
	lua_register(state, "getMapWidth", &registerDDelegate!(ITileLayer.getMX));
	lua_register(state, "getMapHeight", &registerDDelegate!(ITileLayer.getMY));
	lua_register(state, "getTileWidth", &registerDDelegate!(ITileLayer.getTX));
	lua_register(state, "getTileHeight", &registerDDelegate!(ITileLayer.getTY));
	lua_register(state, "clearTilemap", &registerDDelegate!(ITileLayer.clearTilemap));
	lua_register(state, "addTile", &registerDDelegate!(ITileLayer.addTile));
	lua_register(state, "getTile", &registerDDelegate!(ITileLayer.getTile));
	lua_register(state, "removeTile", &registerDDelegate!(ITileLayer.removeTile));

	lua_register(state, "ttl_setA", &registerDFunction!ttl_setA);
	lua_register(state, "ttl_setB", &registerDFunction!ttl_setB);
	lua_register(state, "ttl_setC", &registerDFunction!ttl_setC);
	lua_register(state, "ttl_setD", &registerDFunction!ttl_setD);
	lua_register(state, "ttl_setx_0", &registerDFunction!ttl_setx_0);
	lua_register(state, "ttl_sety_0", &registerDFunction!ttl_sety_0);
	lua_register(state, "ttl_getA", &registerDFunction!ttl_getA);
	lua_register(state, "ttl_getB", &registerDFunction!ttl_getB);
	lua_register(state, "ttl_getC", &registerDFunction!ttl_getC);
	lua_register(state, "ttl_getD", &registerDFunction!ttl_getD);
	lua_register(state, "ttl_getx_0", &registerDFunction!ttl_getx_0);
	lua_register(state, "ttl_gety_0", &registerDFunction!ttl_gety_0);

	lua_register(state, "moveSprite", &registerDFunction!(moveSprite));
	lua_register(state, "relMoveSprite", &registerDFunction!(relMoveSprite));
	lua_register(state, "getSpriteCoordinate", &registerDDelegate!(ISpriteLayer.getSpriteCoordinate));
	lua_register(state, "setSpriteSlice", &registerDFunction!setSpriteSlice);
	lua_register(state, "getSpriteSlice", &registerDDelegate!(ISpriteLayer.getSlice));
	lua_register(state, "addSprite", &registerDDelegate!(ISpriteLayer.addSprite));
	lua_register(state, "removeSprite", &registerDDelegate!(ISpriteLayer.removeSprite));
	lua_register(state, "getPaletteID", &registerDDelegate!(ISpriteLayer.getPaletteID));
	lua_register(state, "setPaletteID", &registerDDelegate!(ISpriteLayer.setPaletteID));
	lua_register(state, "scaleSpriteHoriz", &registerDDelegate!(ISpriteLayer.scaleSpriteHoriz));
	lua_register(state, "scaleSpriteVert", &registerDDelegate!(ISpriteLayer.scaleSpriteVert));
	lua_register(state, "getScaleSpriteHoriz", &registerDDelegate!(ISpriteLayer.getScaleSpriteHoriz));
	lua_register(state, "getScaleSpriteVert", &registerDDelegate!(ISpriteLayer.getScaleSpriteVert));

	lua_register(state, "getBitmapWidth", &registerDDelegate!(ABitmap.width));
	lua_register(state, "getBitmapHeight", &registerDDelegate!(ABitmap.height));

	lua_register(state, "getAudioModule", &registerDFunction!getAudioModule);
	lua_register(state, "midiCMD", &registerDFunction!midiCMD);
}
package void scrollLayer(Layer l, LuaVar x, LuaVar y) {
	l.scroll(cast(int)x, cast(int)y);
}
package void relScrollLayer(Layer l, LuaVar x, LuaVar y) {
	l.relScroll(cast(int)x, cast(int)y);
}
package uint getPaletteIndex(ushort n) @safe @nogc nothrow {
	return mainRaster.getPaletteIndex(n).base;
}
package uint setPaletteIndex(ushort n, uint c) @nogc nothrow {
	Color c0;
	c0.base = c;
	return mainRaster.setPaletteIndex(n, c0).base;
}
package LuaVar getLayer(int n) {
	Layer l = mainRaster.getLayer(n);
	if (l is null)
		return LuaVar.voidType();
	else
		return LuaVar(l);
}
package LuaVar getAudioModule(int n) {
	if (n >= 0 && modMan.moduleList.length < n) {
		AudioModule a = modMan.moduleList[n];
		return LuaVar(a);
	} else return LuaVar.voidType();
}
package void midiCMD(void* target, uint a, uint b, uint c, uint d) @nogc nothrow {
	import midi2.types.structs;
	AudioModule am = cast(AudioModule)target;
	UMP u;
	u.base = a;
	am.midiReceive(u, b, c, d);
}
package string getLayerType(Layer l) {
	return l.getLayerType().to!string();
}
package long readMapping(void* target, int x, int y) @nogc nothrow {
	ITileLayer l = cast(ITileLayer)target;
	MappingElement me = l.readMapping(x, y);
	return *cast(uint*)&me;
}
package long tileByPixel(void* target, int x, int y) @nogc nothrow {
	ITileLayer l = cast(ITileLayer)target;
	MappingElement me = l.tileByPixel(x, y);
	return *cast(uint*)&me;
}
package bool setLayerRenderingMode(Layer target, string mode) {
	char[] mode0 = mode.dup;
	toLowerInPlace(mode0);
	switch (mode0) {
		case "copy":
			target.setRenderingMode(RenderingMode.Copy);
			break;
		case "blitter":
			target.setRenderingMode(RenderingMode.Blitter);
			break;
		case "alphablend":
			target.setRenderingMode(RenderingMode.AlphaBlend);
			break;
		case "multiply":
			target.setRenderingMode(RenderingMode.Multiply);
			break;
		case "multiplybl":
			target.setRenderingMode(RenderingMode.MultiplyBl);
			break;
		case "screen":
			target.setRenderingMode(RenderingMode.Screen);
			break;
		case "screenbl":
			target.setRenderingMode(RenderingMode.ScreenBl);
			break;
		case "add":
			target.setRenderingMode(RenderingMode.Add);
			break;
		case "addbl":
			target.setRenderingMode(RenderingMode.AddBl);
			break;
		case "subtract":
			target.setRenderingMode(RenderingMode.Subtract);
			break;
		case "subtractbl":
			target.setRenderingMode(RenderingMode.SubtractBl);
			break;
		case "diff":
			target.setRenderingMode(RenderingMode.Diff);
			break;
		case "diffbl":
			target.setRenderingMode(RenderingMode.DiffBl);
			break;
		case "and":
			target.setRenderingMode(RenderingMode.AND);
			break;
		case "or":
			target.setRenderingMode(RenderingMode.OR);
			break;
		case "xor":
			target.setRenderingMode(RenderingMode.XOR);
			break;
		default:
			return false;
	}
	return true;
}
package void setSpriteRenderingMode(ISpriteLayer target, int n, string mode) {
	char[] mode0 = mode.dup;
	toLowerInPlace(mode0);
	switch (mode0) {
		case "copy":
			target.setSpriteRenderingMode(n, RenderingMode.Copy);
			break;
		case "blitter":
			target.setSpriteRenderingMode(n, RenderingMode.Blitter);
			break;
		case "alphablend":
			target.setSpriteRenderingMode(n, RenderingMode.AlphaBlend);
			break;
		case "multiply":
			target.setSpriteRenderingMode(n, RenderingMode.Multiply);
			break;
		case "multiplybl":
			target.setSpriteRenderingMode(n, RenderingMode.MultiplyBl);
			break;
		case "screen":
			target.setSpriteRenderingMode(n, RenderingMode.Screen);
			break;
		case "screenbl":
			target.setSpriteRenderingMode(n, RenderingMode.ScreenBl);
			break;
		case "add":
			target.setSpriteRenderingMode(n, RenderingMode.Add);
			break;
		case "addbl":
			target.setSpriteRenderingMode(n, RenderingMode.AddBl);
			break;
		case "subtract":
			target.setSpriteRenderingMode(n, RenderingMode.Subtract);
			break;
		case "subtractbl":
			target.setSpriteRenderingMode(n, RenderingMode.SubtractBl);
			break;
		case "diff":
			target.setSpriteRenderingMode(n, RenderingMode.Diff);
			break;
		case "diffbl":
			target.setSpriteRenderingMode(n, RenderingMode.DiffBl);
			break;
		case "and":
			target.setSpriteRenderingMode(n, RenderingMode.AND);
			break;
		case "or":
			target.setSpriteRenderingMode(n, RenderingMode.OR);
			break;
		case "xor":
			target.setSpriteRenderingMode(n, RenderingMode.XOR);
			break;
		default:
			target.setSpriteRenderingMode(n, RenderingMode.init);
			break;
	}
}
package void writeMapping(void* target, int x, int y, uint val) @nogc nothrow {
	ITileLayer l = cast(ITileLayer)target;
	MappingElement me = *cast(MappingElement*)&val;
	l.writeMapping(x, y, me);
}
package Box setSpriteSlice(void* target, int n, LuaVar x0, LuaVar y0, LuaVar x1, LuaVar y1) {
	ISpriteLayer l = cast(ISpriteLayer)target;
	return l.setSlice(n, Box(cast(int)x0, cast(int)y0, cast(int)x1, cast(int)y1));
}
package void moveSprite(ISpriteLayer target, int n, LuaVar x, LuaVar y) {
	target.moveSprite(n, cast(int)x, cast(int)y);
}
package void relMoveSprite(ISpriteLayer target, int n, LuaVar x, LuaVar y) {
	target.relMoveSprite(n, cast(int)x, cast(int)y);
}
/+package void addSprite(ISpriteLayer target, ABitmap s, int n, LuaVar x, LuaVar y, ushort paletteSel, 
		LuaVar scaleHoriz, LuaVar scaleVert) {
	target.addSprite(s, n, cast(int)x, cast(int)y, paletteSel, cast(int)scaleHoriz, cast(int)scaleVert);
}+/
package short ttl_getA(ITTL target) @nogc nothrow {
	return target.A;
}
package short ttl_getB(ITTL target) @nogc nothrow {
	return target.B;
}
package short ttl_getC(ITTL target) @nogc nothrow {
	return target.C;
}
package short ttl_getD(ITTL target) @nogc nothrow {
	return target.D;
}
package short ttl_getx_0(ITTL target) @nogc nothrow {
	return target.x_0;
}
package short ttl_gety_0(ITTL target) @nogc nothrow {
	return target.y_0;
}
package short ttl_setA(ITTL target, LuaVar val) {
	return target.A(cast(short)val);
}
package short ttl_setB(ITTL target, LuaVar val) {
	return target.B(cast(short)val);
}
package short ttl_setC(ITTL target, LuaVar val) {
	return target.C(cast(short)val);
}
package short ttl_setD(ITTL target, LuaVar val) {
	return target.D(cast(short)val);
}
package short ttl_setx_0(ITTL target, LuaVar val) {
	return target.x_0(cast(short)val);
}
package short ttl_sety_0(ITTL target, LuaVar val) {
	return target.y_0(cast(short)val);
}
package LuaVar getBitmapResource(string resID) {
	ABitmap src = scrptResMan[resID];
	if (src !is null) return LuaVar(src);
	else return LuaVar.voidType();
}