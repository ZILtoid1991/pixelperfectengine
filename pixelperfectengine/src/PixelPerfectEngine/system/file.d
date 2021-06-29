module PixelPerfectEngine.system.file;
/*
 * Copyright (C) 2015-2017, by Laszlo Szeremi under the Boost license.
 *
 * Pixel Perfect Engine, file module
 */

import std.file;
import std.path;
import std.stdio;
import std.conv : to;
import core.stdc.string : memcpy;
import PixelPerfectEngine.system.etc;
import PixelPerfectEngine.system.exc;

import PixelPerfectEngine.graphics.bitmap;
import PixelPerfectEngine.graphics.raster;
import PixelPerfectEngine.graphics.fontsets;

//import PixelPerfectEngine.extbmp.extbmp;

public import dimage.base;
import dimage.tga;
import dimage.png;
import dimage.bmp;


import vfile;

import bindbc.sdl.mixer;

/**
 * Loads an Image from a File or VFile.
 * Automatically detects format from file extension.
 */
public Image loadImage(F = File)(F file) @trusted{
	switch(extension(file.name)){
		case ".tga", ".TGA":
			TGA imageFile = TGA.load!(F, true, true)(file);
			if(!imageFile.getHeader.topOrigin){
				imageFile.flipVertical;
			}
			return imageFile;
		case ".png", ".PNG":
			PNG imageFile = PNG.load!F(file);
			return imageFile;
		case ".bmp", ".BMP":
			BMP imageFile = BMP.load!F(file);
			return imageFile;
		default:
			throw new Exception("Unsupported file format!");
	}
}
/**
 * Loads a bitmap from Image.
 */
public T loadBitmapFromImage(T)(Image img) @trusted
		if (is(T == Bitmap4Bit) || is(T == Bitmap8Bit) || is(T == Bitmap16Bit) || is(T == Bitmap32Bit)) {
	// Later we might want to detect image type from classinfo, until then let's rely on similarities between types
	static if(is(T == Bitmap4Bit)){
		if (img.getBitdepth == 4)
			return new Bitmap4Bit(img.imageData.raw, img.width, img.height);
		else if (img.getBitdepth < 4)
			return new Bitmap4Bit(img.imageData.convTo(PixelFormat.Indexed4Bit).raw, img.width, img.height);
		else
			throw new BitmapFormatException("Bitdepth mismatch exception!");	

	}else static if(is(T == Bitmap8Bit)){
		if (img.getBitdepth == 8)
			return new Bitmap8Bit(img.imageData.raw, img.width, img.height);
		else if (img.getBitdepth < 8)
			return new Bitmap8Bit(img.imageData.convTo(PixelFormat.Indexed8Bit).raw, img.width, img.height);
		else
			throw new BitmapFormatException("Bitdepth mismatch exception!");

	}else static if(is(T == Bitmap16Bit)){
		if (img.getBitdepth == 16)
			return new Bitmap16Bit(reinterpretCast!ushort(img.imageData.raw), img.width, img.height);
		else if (img.getBitdepth < 16)
			return new Bitmap16Bit(reinterpretCast!ushort(img.imageData.convTo(PixelFormat.Indexed16Bit).raw), 
					img.width, img.height);
		else
			throw new BitmapFormatException("Bitdepth mismatch exception!");
		
	}else static if(is(T == Bitmap32Bit)){
		return new Bitmap32Bit(reinterpretCast!Color(img.imageData.convTo(PixelFormat.ARGB8888 | PixelFormat.BigEndian).raw), 
				img.width, img.height);

	}

}
//TODO: Make collision model loader for 1 bit bitmaps
/**
 * Loads a bitmap from disk.
 * Currently supported formats: *.tga, *.png, *.bmp
 */
public T loadBitmapFromFile(T)(string filename)
		if (is(T == Bitmap4Bit) || is(T == Bitmap8Bit) || is(T == Bitmap16Bit) || is(T == Bitmap32Bit)) {
	File f = File(filename);
	return loadBitmapFromImage!T(loadImage(f));
}
/**
 * Loads a bitmap sheet from file.
 * This one doesn't require TGA devarea extensions.
 */
public T[] loadBitmapSheetFromFile(T)(string filename, int x, int y)
		if (is(T == Bitmap4Bit) || is(T == Bitmap8Bit) || is(T == Bitmap16Bit) || is(T == Bitmap32Bit)) {
	//T source = loadBitmapFromFile!T(filename);
	return loadBitmapSheetFromImage!T(loadImage(File(filename)), x, y);
}
/**
 * Creates a bitmap sheet from an image file.
 * This one doesn't require embedded data.
 */
public T[] loadBitmapSheetFromImage(T)(Image img, int x, int y)
		if (is(T == Bitmap4Bit) || is(T == Bitmap8Bit) || is(T == Bitmap16Bit) || is(T == Bitmap32Bit)) {
	T source = loadBitmapFromImage!T(img);
	if(source.width % x == 0 && source.height % y == 0){
		T[] output;
		static if (is(T == Bitmap4Bit))
			const size_t length = x / 2, pitch = source.width / 2;
		else static if (is(T == Bitmap8Bit))
			const size_t length = x, pitch = source.width;
		else static if (is(T == Bitmap16Bit))
			const size_t length = x * 2, pitch = source.width * 2;
		else static if (is(T == Bitmap32Bit))
			const size_t length = x * 4, pitch = source.width * 4;
		const size_t pitch0 = pitch * y;
		output.reserve(source.height / y * source.width / x);
		for (int mY ; mY < source.height / y ; mY++){
			for (int mX ; mX < source.width / x ; mX++){
				T next = new T(x, y);
				for (int lY ; lY < y ; lY++){
					memcpy(next.getPtr + (lY * length), source.getPtr + (pitch * lY) + (pitch0 * mY) + (length * mX), length);
				}
				output ~= next;
			}
		}
		return output;
	}else throw new Exception("Requested size cannot be divided by input file's sizes!");
}
/**
 * Loads a palette from a file.
 */
public Color[] loadPaletteFromFile(string filename) {
	File f = File(filename);
	switch(extension(filename)){
		case ".tga", ".TGA":
			TGA imageFile = TGA.load(f);
			return loadPaletteFromImage(imageFile);
		case ".png", ".PNG":
			PNG imageFile = PNG.load(f);
			return loadPaletteFromImage(imageFile);
		case ".bmp", ".BMP":
			BMP imageFile = BMP.load(f);
			return loadPaletteFromImage(imageFile);
		default:
			throw new Exception("Unsupported file format!");
	}
}
/**
 * Loads a palette from image.
 */
public Color[] loadPaletteFromImage (Image img) {
	Color[] palette;
	IPalette sourcePalette = img.palette.convTo(PixelFormat.ARGB8888 | PixelFormat.BigEndian);
	palette = reinterpretCast!Color(sourcePalette.raw);

	assert(palette.length == sourcePalette.length, "Palette lenght import mismatch!");
	if(!(img.palette.paletteFormat & PixelFormat.ValidAlpha)){
		palette[0].a = 0x0;
		for(int i = 1; i < palette.length; i++) {
			palette[i].a = 0xFF;
		}
	}
	return palette;
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
