module system.file;
/*
 *Copyright (C) 2015, by Laszlo Szeremi under the Boost license.
 *
 *VDP Engine, file module
 */

import std.file;
import std.stdio;
import std.conv;

import graphics.bitmap;
import graphics.raster;

import derelict.sdl2.mixer;

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

/*public Bitmap16Bit[] loadBitmapFromDat(void[] data){
	auto cdata = cast(ushort[])data;
	ushort x = fileHeader[1], y = fileHeader[2], nOfSprites = fileHeader[0];
	ushort[] pixelData = new ushort[x*y];
	Bitmap16Bit[] rv = new Bitmap16Bit[nOfSprites];
	for(int i; i <= nOfSprites; i++){
		
		pixelData = fileData[2+(x*y*i)..2+(x*y*(i+1))];
		
		rv[i] = new Bitmap16Bit(pixelData, x, y);
	}
	return rv;
}*/

public void saveBitmapToFile(Bitmap16Bit[] bitmap, string filename){
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