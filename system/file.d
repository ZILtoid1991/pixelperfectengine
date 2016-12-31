module system.file;
/*
 *Copyright (C) 2015, by Laszlo Szeremi under the Boost license.
 *
 *VDP Engine, file module
 */

import std.file;
import std.stdio;
import std.conv;
import system.etc;

import graphics.bitmap;
import graphics.raster;
import graphics.fontsets;

import extbmp.extbmp;

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
 * FILE FORMAT IS DEPRECATED! USE XMP INSTEAD!
 */
public void loadPaletteFromFile(string filename, Raster target){
	auto palette = cast(ubyte[])std.file.read(filename);
	//writeln(palette.length);
	target.setupPalette(0);
	int max = (palette.length / 3);
	for(int i ; i < max ; i++){
		target.addColor(palette[(i * 3)], palette[(i * 3) + 1], palette[(i * 3) + 2]);
		//writeln(i);
	}
}

/**
 * FILE FORMAT IS DEPRECATED! USE XMP INSTEAD!
 */
public void load24bitPaletteFromFile(string filename, Raster target){
	auto palette = cast(ubyte[])std.file.read(filename);
	//writeln(palette.length);
	target.setupPalette(0);
	int max = (palette.length / 3);
	target.addColor(palette[0], palette[1], palette[2], 0);
	for(int i = 1; i < max ; i++){
		target.addColor(palette[(i * 3)], palette[(i * 3) + 1], palette[(i * 3) + 2]);
		//writeln(i);
	}
}

/**
 * Gets the bitmap from the XMP file.
 */
Bitmap16Bit loadBitmapFromXMP(ExtendibleBitmap xmp, string ID){

	Bitmap16Bit result = new Bitmap16Bit(xmp.get16bitBitmap(ID),xmp.getXsize(ID),xmp.getYsize(ID));
	return result;
}

Bitmap32Bit load32BitBitmapFromXMP(ExtendibleBitmap xmp, string ID){
	Bitmap32Bit result = new Bitmap32Bit(cast(ubyte[])xmp.getBitmap(ID),xmp.getXsize(ID),xmp.getYsize(ID));
	return result;
}

public void loadPaletteFromXMP(ExtendibleBitmap xmp, string ID, Raster target){
	target.palette = cast(ubyte[])xmp.getPalette(ID);
	//writeln(target.palette);
	/*target.setupPalette(0);
	int max = (palette.length / 3);
	for(int i ; i < max ; i++){
		target.addColor(palette[(i * 3)], palette[(i * 3) + 1], palette[(i * 3) + 2]);
		//writeln(i);
	}*/

}

Fontset loadFontsetFromXMP(ExtendibleBitmap xmp, string fontName){
	Bitmap16Bit[wchar] characters;
	foreach(s;xmp.bitmapID){
		//writeln(parseHex(s[fontName.length..(s.length-1)]));
		//if(fontName == s[0..(fontName.length-1)]){
			characters[to!wchar(parseHex(s[fontName.length..s.length]))] = loadBitmapFromXMP(xmp,s);
		//}
	}
	return new Fontset(fontName, characters['0'].getY, characters);
}

public deprecated void saveBitmapToFile(Bitmap16Bit[] bitmap, string filename){
	ushort[] rawData;
	rawData ~= to!ushort(bitmap.length);
	rawData ~= to!ushort(bitmap[0].getX());
	rawData ~= to!ushort(bitmap[0].getY());
	for(int i; i < bitmap.length; i++){
		for(int j; j < bitmap[0].getY(); j++)
			rawData ~= bitmap[i].readRow(j);
	}
	std.file.write(filename, rawData);
}

public Mix_Chunk* loadSoundFromFile(const char* filename){
	return Mix_LoadWAV(filename);
}

File loadFileFromDisk(string filename){
	return File(filename, "r");
}