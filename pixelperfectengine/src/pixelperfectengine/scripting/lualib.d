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
	//lua_register(state, "getLayer", &registerDFunction!getLayer);

	lua_register(state, "getLayerType", &registerDFunction!(getLayerType));
	lua_register(state, "setLayerRenderingMode", &registerDFunction!setLayerRenderingMode);
	lua_register(state, "scrollLayer", &registerDFunction!(scrollLayer));
	lua_register(state, "relScrollLayer", &registerDFunction!(relScrollLayer));
	lua_register(state, "getLayerScrollX", &registerDMemberFunc!(Layer.getSX));
	lua_register(state, "getLayerScrollY", &registerDMemberFunc!(Layer.getSY));
	lua_register(state, "addTile", &registerDMemberFunc!(ITileLayer.addTile));
	//lua_register(state, "setTileMaterial", &registerDFunction!(setTileMaterial));

	lua_register(state, "readMapping", &registerDFunction!readMapping);
	lua_register(state, "tileByPixel", &registerDFunction!tileByPixel);
	lua_register(state, "writeMapping", &registerDFunction!writeMapping);
	lua_register(state, "getTileWidth", &registerDMemberFunc!(ITileLayer.getTileWidth));
	lua_register(state, "getTileHeight", &registerDMemberFunc!(ITileLayer.getTileHeight));
	lua_register(state, "getMapWidth", &registerDMemberFunc!(ITileLayer.getMX));
	lua_register(state, "getMapHeight", &registerDMemberFunc!(ITileLayer.getMY));
	lua_register(state, "getTileWidth", &registerDMemberFunc!(ITileLayer.getTX));
	lua_register(state, "getTileHeight", &registerDMemberFunc!(ITileLayer.getTY));
	lua_register(state, "clearTilemap", &registerDMemberFunc!(ITileLayer.clearTilemap));
	lua_register(state, "addTile", &registerDMemberFunc!(ITileLayer.addTile));
	lua_register(state, "getTile", &registerDMemberFunc!(ITileLayer.getTile));
	lua_register(state, "removeTile", &registerDMemberFunc!(ITileLayer.removeTile));

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

	//lua_register(state, "moveSprite", &registerDMemberFunc!(ISpriteLayer.moveSprite));
	lua_register(state, "moveSprite", &registerDFunction!(moveSprite));
	//lua_register(state, "relMoveSprite", &registerDMemberFunc!(ISpriteLayer.relMoveSprite));
	lua_register(state, "relMoveSprite", &registerDFunction!(relMoveSprite));
	lua_register(state, "getSpriteCoordinate", &registerDMemberFunc!(ISpriteLayer.getSpriteCoordinate));
	lua_register(state, "setSpriteSlice", &registerDFunction!setSpriteSlice);
	lua_register(state, "getSpriteSlice", &registerDMemberFunc!(ISpriteLayer.getSlice));
	//lua_register(state, "addSprite", &registerDMemberFunc!(ISpriteLayer.addSprite));
	lua_register(state, "addSprite", &registerDFunction!(addSprite));
	lua_register(state, "removeSprite", &registerDMemberFunc!(ISpriteLayer.removeSprite));
	lua_register(state, "getPaletteID", &registerDMemberFunc!(ISpriteLayer.getPaletteID));
	lua_register(state, "setPaletteID", &registerDMemberFunc!(ISpriteLayer.setPaletteID));
	lua_register(state, "scaleSpriteHoriz", &registerDMemberFunc!(ISpriteLayer.scaleSpriteHoriz));
	lua_register(state, "scaleSpriteVert", &registerDMemberFunc!(ISpriteLayer.scaleSpriteVert));
	lua_register(state, "getScaleSpriteHoriz", &registerDMemberFunc!(ISpriteLayer.getScaleSpriteHoriz));
	lua_register(state, "getScaleSpriteVert", &registerDMemberFunc!(ISpriteLayer.getScaleSpriteVert));

	lua_register(state, "getBitmapWidth", &registerDMemberFunc!(ABitmap.width));
	lua_register(state, "getBitmapHeight", &registerDMemberFunc!(ABitmap.height));

	lua_register(state, "getBitmapResource", &registerDFunction!getBitmapResource);
	lua_register(state, "loadBitmapResource", &registerDFunction!loadBitmapResource);

	//lua_register(state, "getAudioModule", &registerDFunction!getAudioModule);
	lua_register(state, "midiCMD", &registerDFunction!midiCMD);

	lua_register(state, "rng_Seed", &registerDFunction!rng_Seed);
	lua_register(state, "rng_Dice", &registerDFunction!rng_Dice);

	lua_register(state, "timer_resume", &registerDFunction!timer_resume);
	lua_register(state, "timer_suspend", &registerDFunction!timer_suspend);
	lua_register(state, "timer_register", &registerDFunction!timer_register);
}
package void scrollLayer(int n, int x, int y) {
	Layer l = mainRaster.getLayer(n);
	if (l)
		l.scroll(cast(int)x, cast(int)y);
}
package void relScrollLayer(int n, int x, int y) {
	Layer l = mainRaster.getLayer(n);
	if (l)
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
package void midiCMD(int n, uint a, uint b, uint c, uint d) @nogc nothrow {
	import midi2.types.structs;
	if (n >= 0 && modMan.moduleList.length < n) {
		AudioModule am = modMan.moduleList[n];
		UMP u;
		u.base = a;
		am.midiReceive(u, b, c, d);
	}
}
package string getLayerType(Layer l) {
	return l.getLayerType().to!string();
}
package long readMapping(int target, int x, int y) @nogc nothrow {
	ITileLayer l = cast(ITileLayer)mainRaster.getLayer(target);
	if (l) {
		MappingElement me = l.readMapping(x, y);
		return *cast(uint*)&me;
	}
	return 0;
}
package long tileByPixel(int target, int x, int y) @nogc nothrow {
	ITileLayer l = cast(ITileLayer)mainRaster.getLayer(target);
	if (l) {
		MappingElement me = l.tileByPixel(x, y);
		return *cast(uint*)&me;
	}
	return 0;
}
package bool setLayerRenderingMode(int n, string mode) {
	Layer target = mainRaster.getLayer(n);
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
package void setSpriteRenderingMode(int t, int n, string mode) {
	ISpriteLayer target = cast(ISpriteLayer)mainRaster.getLayer(t);
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
package void writeMapping(int t, int x, int y, uint val) @nogc nothrow {
	ITileLayer l = cast(ITileLayer)mainRaster.getLayer(t);
	MappingElement me = *cast(MappingElement*)&val;
	l.writeMapping(x, y, me);
}
//package Box setSpriteSlice(int t, int n, LuaVar x0, LuaVar y0, LuaVar x1, LuaVar y1) {
package Box setSpriteSlice(int t, int n, int x0, int y0, int x1, int y1) {
	ISpriteLayer l = cast(ISpriteLayer)mainRaster.getLayer(t);
	return l.setSlice(n, Box(cast(int)x0, cast(int)y0, cast(int)x1, cast(int)y1));
}
//package void moveSprite(ISpriteLayer target, int n, LuaVar x, LuaVar y) {
package void moveSprite(int t, int n, int x, int y) {
	ISpriteLayer target = cast(ISpriteLayer)mainRaster.getLayer(t);
	target.moveSprite(n, cast(int)x, cast(int)y);
}
//package void relMoveSprite(ISpriteLayer target, int n, LuaVar x, LuaVar y) {
package void relMoveSprite(int t, int n, int x, int y) {
	ISpriteLayer target = cast(ISpriteLayer)mainRaster.getLayer(t);
	target.relMoveSprite(n, cast(int)x, cast(int)y);
}
package void addSprite(int t, string s, int n, int x, int y, ushort paletteSel, 
		ubyte paletteSh, ubyte alpha, int scaleHoriz, int scaleVert) {
	ISpriteLayer target = cast(ISpriteLayer)mainRaster.getLayer(t);
	target.addSprite(scrptResMan[s], n, x, y, paletteSel, paletteSh, alpha, scaleHoriz, scaleVert, RenderingMode.init);
}
package short ttl_getA(int t) @nogc nothrow {
	ITTL target = cast(ITTL)mainRaster.getLayer(t);
	return target.A;
}
package short ttl_getB(int t) @nogc nothrow {
	ITTL target = cast(ITTL)mainRaster.getLayer(t);
	return target.B;
}
package short ttl_getC(int t) @nogc nothrow {
	ITTL target = cast(ITTL)mainRaster.getLayer(t);
	return target.C;
}
package short ttl_getD(int t) @nogc nothrow {
	ITTL target = cast(ITTL)mainRaster.getLayer(t);
	return target.D;
}
package short ttl_getx_0(int t) @nogc nothrow {
	ITTL target = cast(ITTL)mainRaster.getLayer(t);
	return target.x_0;
}
package short ttl_gety_0(int t) @nogc nothrow {
	ITTL target = cast(ITTL)mainRaster.getLayer(t);
	return target.y_0;
}
package short ttl_setA(int t, LuaVar val) {
	ITTL target = cast(ITTL)mainRaster.getLayer(t);
	return target.A(cast(short)val);
}
package short ttl_setB(int t, LuaVar val) {
	ITTL target = cast(ITTL)mainRaster.getLayer(t);
	return target.B(cast(short)val);
}
package short ttl_setC(int t, LuaVar val) {
	ITTL target = cast(ITTL)mainRaster.getLayer(t);
	return target.C(cast(short)val);
}
package short ttl_setD(int t, LuaVar val) {
	ITTL target = cast(ITTL)mainRaster.getLayer(t);
	return target.D(cast(short)val);
}
package short ttl_setx_0(int t, LuaVar val) {
	ITTL target = cast(ITTL)mainRaster.getLayer(t);
	return target.x_0(cast(short)val);
}
package short ttl_sety_0(int t, LuaVar val) {
	ITTL target = cast(ITTL)mainRaster.getLayer(t);
	return target.y_0(cast(short)val);
}
package ABitmap getBitmapResource(string resID) {
	/* ABitmap src = scrptResMan[resID];
	if (src !is null) return LuaVar(src);
	else return LuaVar.voidType(); */
	return scrptResMan[resID];
}
package int loadBitmapResource(string path, string resID, int paletteOffset) {
	try {
		import std.stdio : File;
		Image img = loadImage(File(path));
		switch (img.getBitdepth) {
		case 1:
			scrptResMan[resID] = loadBitmapFromImage!Bitmap1Bit(img);
			break;
		case 2:
			scrptResMan[resID] = loadBitmapFromImage!Bitmap2Bit(img);
			mainRaster.loadPaletteChunk(loadPaletteFromImage(img), cast(ushort)paletteOffset);
			break;
		case 4:
			scrptResMan[resID] = loadBitmapFromImage!Bitmap4Bit(img);
			mainRaster.loadPaletteChunk(loadPaletteFromImage(img), cast(ushort)paletteOffset);
			break;
		case 8:
			scrptResMan[resID] = loadBitmapFromImage!Bitmap8Bit(img);
			mainRaster.loadPaletteChunk(loadPaletteFromImage(img), cast(ushort)paletteOffset);
			break;
		case 16:
			scrptResMan[resID] = loadBitmapFromImage!Bitmap16Bit(img);
			mainRaster.loadPaletteChunk(loadPaletteFromImage(img), cast(ushort)paletteOffset);
			break;
		default:
			scrptResMan[resID] = loadBitmapFromImage!Bitmap32Bit(img);
			break;
		}
	} catch (Exception e) {
		return 2;
	}
	return 0;
}
/* package int setTileMaterial(int layerID, int tileID, string resID, int paletteSh) {
	ITileLayer itl = cast(ITileLayer)mainRaster.layerMap[layerID];
	if (itl !is null) {
		try {
			itl.addTile(scrptResMan[resID], cast(wchar)tileID, cast(ubyte)paletteSh);
		} catch (Exception e) {
			return 2;
		}
		return 0;
	} else {
		return 1;
	}
} */

package ulong rng_Seed() @nogc nothrow {
	return rng.seed();
}
package ulong rng_Dice(uint s) @nogc nothrow {
	return rng.dice(s);
}

package void timer_suspend() {
	timer.suspendTimer;
}
package void timer_resume() {
	timer.resumeTimer;
}
package void timer_register(void* state, uint ms, string func) {
	timer.register(delegate void(Duration){callLuaFunc!void(cast(lua_State*)state, func);}, msecs(ms));
}