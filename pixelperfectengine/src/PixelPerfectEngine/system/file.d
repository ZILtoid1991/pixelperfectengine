module PixelPerfectEngine.system.file;
/*
 * Copyright (C) 2015-2017, by Laszlo Szeremi under the Boost license.
 *
 * Pixel Perfect Engine, file module
 */

import std.file;
import std.stdio;
import std.conv;
import PixelPerfectEngine.system.etc;
import PixelPerfectEngine.system.exc;

import PixelPerfectEngine.graphics.bitmap;
import PixelPerfectEngine.graphics.raster;
import PixelPerfectEngine.graphics.fontsets;

import PixelPerfectEngine.extbmp.extbmp;

import derelict.sdl2.mixer;

/**
 * FILE FORMAT IS DEPRECATED! USE XMP INSTEAD!
 */
public Bitmap16Bit[] loadBitmapFromFile(string filename){
	auto fileData = cast(ushort[])std.file.read(filename);
	ushort x = fileData[1], y = fileData[2], nOfSprites = fileData[0];
	//writeln(fileData.length);
	Bitmap16Bit[] bar;
	for(int i; i < nOfSprites; i++){
		//writeln(3+(x*y*i));
		ushort[] pixeldata = fileData[(3+(x*y*i)) .. (3+(x*y*(i+1)))];
		Bitmap16Bit foo = new Bitmap16Bit(pixeldata , x, y);

		bar ~= foo;

	}

	return bar;
}
/**
 * Gets a bitmap from the XMP file.
 */
T loadBitmapFromXMP(T)(ExtendibleBitmap xmp, string ID){
	static if(T.stringof == Bitmap4Bit.stringof || T.stringof == Bitmap8Bit.stringof){
		T result = new T(cast(ubyte[])xmp.getBitmap(ID),xmp.getXsize(ID),xmp.getYsize(ID),null);
		return result;
	}else static if(T.stringof == Bitmap16Bit.stringof){
		T result;// = new T(cast(ushort[])xmp.getBitmap(ID),xmp.getXsize(ID),xmp.getYsize(ID));
		switch(xmp.bitdepth[xmp.searchForID(ID)]){
			case "16bit":
				result = new T(cast(ushort[])xmp.getBitmap(ID),xmp.getXsize(ID),xmp.getYsize(ID));
				break;
			case "8bit":
				ushort[] subresult;
				ubyte[] input = cast(ubyte[])xmp.getBitmap(ID);
				subresult.length = input.length;
				for(int i ; i < subresult.length ; i++){
					subresult[i] = input[i];
				}
				result = new T(subresult,xmp.getXsize(ID),xmp.getYsize(ID));
				break;
			case "4bit":
				ushort[] subresult;
				ubyte[] input = cast(ubyte[])xmp.getBitmap(ID);
				subresult.length = input.length;
				for(int i ; i < subresult.length ; i++){
					if(i & 1)
						subresult[i] = input[i>>1]>>4;
					else
						subresult[i] = input[i>>1]&0b0000_1111;
				}
				result = new T(subresult,xmp.getXsize(ID),xmp.getYsize(ID));
				break;
			/*case "1bit":

				break;*/
			default:
				throw new FileAccessException("Bitdepth error!");
		}

		return result;
	}else static if(T.stringof == Bitmap32Bit.stringof){
		T result = new T(cast(Color[])xmp.getBitmap(ID),xmp.getXsize(ID),xmp.getYsize(ID));
		return result;
	}else static if(T.stringof == ABitmap.stringof){

		switch(xmp.bitdepth[xmp.searchForID(ID)]){
			case "4bit":
				return new Bitmap4Bit(cast(ubyte[])xmp.getBitmap(ID),xmp.getXsize(ID),xmp.getYsize(ID));
			case "8bit":
				return new Bitmap8Bit(cast(ubyte[])xmp.getBitmap(ID),xmp.getXsize(ID),xmp.getYsize(ID));
			case "16bit":
				return new Bitmap16Bit(cast(ushort[])xmp.getBitmap(ID),xmp.getXsize(ID),xmp.getYsize(ID));
			case "32bit":
				return new Bitmap32Bit(cast(Color[])xmp.getBitmap(ID),xmp.getXsize(ID),xmp.getYsize(ID));
			default:
				return null;

		}

	}else static assert("Template argument \'" ~ T.stringof ~ "\' not supported in function \'T loadBitmapFromXMP(T)(ExtendibleBitmap xmp, string ID)\'");
}
/**
 * Loads a palette from an XMP file.
 */
public void loadPaletteFromXMP(ExtendibleBitmap xmp, string ID, Raster target, int offset = 0){
	target.palette = cast(Color[])xmp.getPalette(ID);
	//writeln(target.palette);
	/*target.setupPalette(0);
	int max = (palette.length / 3);
	for(int i ; i < max ; i++){
		target.addColor(palette[(i * 3)], palette[(i * 3) + 1], palette[(i * 3) + 2]);
		//writeln(i);
	}*/

}
/**
 * Loads a fontset from an XMP file.
 */
Fontset!Bitmap16Bit loadFontsetFromXMP(ExtendibleBitmap xmp, string fontName){
	Bitmap16Bit[wchar] characters;
	foreach(s;xmp.bitmapID){
		//writeln(parseHex(s[fontName.length..(s.length-1)]));
		//if(fontName == s[0..(fontName.length-1)]){
		characters[to!wchar(parseHex(s[fontName.length..s.length]))] = loadBitmapFromXMP!Bitmap16Bit(xmp,s);
		//}
	}
	return new Fontset!Bitmap16Bit(fontName, characters['0'].height, characters);
}
/**
 * Loads a *.wav file if SDL2 mixer is used
 */
public Mix_Chunk* loadSoundFromFile(const char* filename){
	return Mix_LoadWAV(filename);
}

File loadFileFromDisk(string filename){
	return File(filename, "r");
}

/**
 * Implements the RIFF serialization system
 */
public struct RIFFHeader{
	char[4] data;
	uint length;
}
