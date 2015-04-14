module system.file;
/*
 *Copyright (C) 2015, by Laszlo Szeremi under the Boost license.
 *
 *VDP Engine, file module
 */

import std.file;
import std.stdio;

import graphics.bitmap;

import derelict.sdl2.mixer;

Bitmap16Bit[] loadBitmapFromFile(char[] filename){
	auto fileHeader = cast(ubyte[]) read(filename, 6);
	ushort x = (fileHeader[2]*256)+fileHeader[3], y = (fileHeader[4]*256)+fileHeader[5], nOfSprites = (fileHeader[0]*256)+fileHeader[1];
	auto fileData = cast(ubyte[]) read(filename, 6 + (x*y*nOfSprites));
	ushort pixelData[] = new ushort[x*y];
	Bitmap16Bit[] rv = new Bitmap16Bit[nOfSprites];
	for(int i; i <= nOfSprites; i++){
		for(int j; j <= (x*y); j++){
			pixelData[j] = (fileData[6+(j*2)]*256) + fileData[(j*2)+7];
		}
		rv[i] = new Bitmap16Bit(pixelData, x, y);
	}
	return rv;
}

public Mix_Chunk* loadSoundFromFile(const char* filename){
	return Mix_LoadWAV(filename);
}

File loadFileFromDisk(string filename){
	return File(filename, "r");
}