module pixelperfectengine.system.file;
/*
 * Copyright (C) 2015-2017, by Laszlo Szeremi under the Boost license.
 *
 * Pixel Perfect Engine, file module
 */

import std.file;
import std.path;
import std.stdio;
import std.conv : to;
import std.algorithm.searching : startsWith;
import core.stdc.string : memcpy;
import pixelperfectengine.system.etc;
import pixelperfectengine.system.exc;

import pixelperfectengine.graphics.bitmap;
import pixelperfectengine.graphics.raster;
import pixelperfectengine.graphics.fontsets;

//import pixelperfectengine.extbmp.extbmp;

public import dimage.base;
import dimage.tga;
import dimage.png;
import dimage.bmp;

//import bitleveld.reinterpret;

import vfile;

import mididi;

//import sdl_mixer;
import std.utf;

/** 
 * Pads a scanline to be on size_t's bounds.
 * Params:
 *   scanline = The scanline to be padded.
 * Returns: the padded scanline
 */
package size_t[] padScanLine(ubyte[] scanline) @safe {
	const int extra = size_t.sizeof - (scanline.length % size_t.sizeof);
	if (extra)
		scanline.length = scanline.length + extra;
	return reinterpretCast!size_t(scanline);
}
/**
 * Loads a bitmap slice from an image.
 * Ideal for loading sprite sheets.
 */
public T loadBitmapSliceFromImage(T)(Image img, int x, int y, int w, int h) {
	synchronized{T src = loadBitmapFromImage!T(img), result;
	result = src.window(x, y, x + w - 1, y + h - 1);
	return result;}
}
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
		if (is (T == Bitmap1Bit) || is(T == Bitmap2Bit) || is(T == Bitmap4Bit) || is(T == Bitmap8Bit) || 
		is(T == Bitmap16Bit) || is(T == Bitmap32Bit)) {
	// Later we might want to detect image type from classinfo, until then let's rely on similarities between types
	static if(is(T == Bitmap1Bit)){
		if (img.getBitdepth != 1)
			throw new BitmapFormatException("Bitdepth mismatch exception!");
		ubyte[] data = img.imageData.raw;
		size_t[] newData;
		const size_t pitch = data.length / img.imageData.height;
		for (int i ; i < img.imageData.height ; i++) {
			newData ~= padScanLine(data[pitch * i..pitch * (i + 1)]);
		}
		return new Bitmap1Bit(newData, img.imageData.width, img.imageData.height);
	} else static if(is(T == Bitmap2Bit)){
		if (img.getBitdepth == 2)
			return new Bitmap2Bit(img.imageData.raw, img.width, img.height);
		else if (img.getBitdepth < 2)
			return new Bitmap2Bit(img.imageData.convTo(PixelFormat.Indexed2Bit).raw, img.width, img.height);
		else
			throw new BitmapFormatException("Bitdepth mismatch exception!");	
	}else static if(is(T == Bitmap4Bit)){
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
		return new Bitmap32Bit(reinterpretCast!Color(img.imageData.convTo(PixelFormat.RGBA8888).raw),
				img.width, img.height);

	}

}
//TODO: Make collision model loader for 1 bit bitmaps
/**
 * Loads a bitmap from disk.
 * Currently supported formats: *.tga, *.png, *.bmp
 */
public T loadBitmapFromFile(T)(string filename)
		if (is (T == Bitmap1Bit) || is(T == Bitmap2Bit) || is(T == Bitmap4Bit) || is(T == Bitmap8Bit) || 
		is(T == Bitmap16Bit) || is(T == Bitmap32Bit)) {
	File f = File(filename);
	return loadBitmapFromImage!T(loadImage(f));
}
/**
 * Loads a bitmap sheet from file.
 * This one doesn't require TGA devarea extensions.
 */
public T[] loadBitmapSheetFromFile(T)(string filename, int x, int y)
		if (is (T == Bitmap1Bit) || is(T == Bitmap2Bit) || is(T == Bitmap4Bit) || is(T == Bitmap8Bit) || 
		is(T == Bitmap16Bit) || is(T == Bitmap32Bit)) {
	//T source = loadBitmapFromFile!T(filename);
	return loadBitmapSheetFromImage!T(loadImage(File(filename)), x, y);
}
/**
 * Creates a bitmap sheet from an image file.
 * This one doesn't require embedded data.
 */
public T[] loadBitmapSheetFromImage(T)(Image img, int x, int y)
		if (is (T == Bitmap1Bit) || is(T == Bitmap2Bit) || is(T == Bitmap4Bit) || is(T == Bitmap8Bit) || 
		is(T == Bitmap16Bit) || is(T == Bitmap32Bit)) {
	T source = loadBitmapFromImage!T(img);
	if (source.width % x == 0 && source.height % y == 0) {
		T[] output;
		static if (is(T == Bitmap1Bit))
			const size_t length = x / 8, length0 = x / 8, pitch = source.width / 8;
		else static if (is(T == Bitmap2Bit))
			const size_t length = x / 4, length0 = x / 4, pitch = source.width / 4;
		else static if (is(T == Bitmap4Bit))
			const size_t length = x / 2, length0 = x / 2, pitch = source.width / 2;
		else static if (is(T == Bitmap8Bit))
			const size_t length = x, length0 = x, pitch = source.width;
		else static if (is(T == Bitmap16Bit))
			const size_t length = x, length0 = x * 2, pitch = source.width;
		else static if (is(T == Bitmap32Bit))
			const size_t length = x, length0 = x * 4, pitch = source.width;
		const size_t pitch0 = pitch * y;
		output.reserve(source.height / y * source.width / x);
		for (int mY ; mY < source.height / y ; mY++){
			for (int mX ; mX < source.width / x ; mX++){
				T next = new T(x, y);
				for (int lY ; lY < y ; lY++){
					memcpy(next.getPtr + (lY * length), source.getPtr + (pitch * lY) + (pitch0 * mY) + (length * mX), length0);
				}
				output ~= next;
			}
		}
		return output;
	} else throw new Exception("Requested size cannot be divided by input file's sizes!");
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
	IPalette sourcePalette = img.palette.convTo(PixelFormat.RGBA8888);
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
///PRELIMINARY FUNCTION! WILL CHANGE IN THE FUTURE!
///Reads text (e.g. XML) from file, and returns it as a string.
///Does some automatic conversion using BOM detection.
///TODO: Add the encoding detection and conversion utility to the newxml library.
public dstring loadTextFile(F = File)(F file) {
	import std.encoding;
	import std.utf;
	file.seek(0);
	dstring result;
	char[] buffer;
	buffer.length = cast(size_t)file.size;
	file.rawRead(buffer);
	const BOMSeq encodingType = getBOM(reinterpretCast!(immutable(ubyte))(buffer));
	switch (encodingType.schema) {
		case BOM.utf16le:
			result = cast(dstring)toUTF32(reinterpretCast!wchar(buffer));
			break;
		case BOM.utf32le:
			result = reinterpretCast!(const(dchar))(buffer);
			break;
		default:		//treat it as UTF8!
			result = cast(dstring)toUTF32(buffer);
			break;
	}
	return result;
}
/** 
 * Loads the shader file into memory.
 * Params:
 *   path = Path to the shader. Symbols are automatically resolved.
 * Returns: The content of the shader, with an added null terminator.
 */
public const(char)[] loadShader(string path) @trusted {
	path = resolvePath(path);
	char[] buffer;
	File file = File(path, "rb");
	buffer.length = cast(size_t)file.size;
	file.rawRead(buffer);
	return reinterpretCast!(const(char))(buffer ~ '\00');
}
///Path to the root folder, where assets etc. are stored.
public immutable string pathRoot;
///Path to the executable folder, null if not eveilable for security reasons.
public immutable string pathExec;
public string[string] pathSymbols;
shared static this () {
	import std.path;
	import std.file : exists;
	pathExec = thisExePath();	//Note: once we go to consoles/phones, we might need to make more 
	string pathToExec = pathExec[0..$-baseName(pathExec).length];
	if (exists(buildNormalizedPath(pathToExec, "../system/"))) {	//Inside of a bin-[arch]-[os] folder
		pathRoot = buildNormalizedPath(pathToExec, "../");
	} else if (exists(buildNormalizedPath(pathToExec, "./system/"))) {//Outside of a bin-[arch]-[os] folder
		pathRoot = buildNormalizedPath(pathToExec);
	} else {
		debug assert(0, "Folder /system/ does not exist! Check your development environment and the documentation for info.");
		else assert(0, "Folder /system/ does not exist! Please reinstall the software or contact the developer if that does 
				not solve the issue.");
		}
	pathSymbols["PATH"] = pathRoot;
	pathSymbols["EXEC"] = pathToExec;
	pathSymbols["SYSTEM"] = pathRoot ~ "/system/";
	pathSymbols["SHADERS"] = pathRoot ~ "/shaders/";
	pathSymbols["LOCAL"] = pathRoot ~ "/local/";
	version (ARM) pathSymbols["SHDRVER"] = "300es";
	else version (AArch64) pathSymbols["SHDRVER"] = "300es";
	else pathSymbols["SHDRVER"] = "330";
	if (exists(buildNormalizedPath(pathRoot, "./_debug/"))) {
		pathSymbols["DEBUG"] = pathRoot ~ "/_debug/";
		pathSymbols["STORE"] = pathRoot ~ "/_debug/";
	}
}
///Sets the symbol `CURRLOCAL` to value specified by `newLocal`. Returns the newly set symbol.
public string setCurrentLocal(string newLocal) {
	return pathSymbols["CURRLOCAL"] = newLocal;
}
/** 
 * Initializes the storage path if folder `_debug` does not exist.
 * Params:
 *   appName = Application name.
 *   etc = Organization or other name if needed.
 * Returns: The created storage path.
 */
public string initStoragePath(string appName, string etc) {
	if (etc.length) etc ~= "/";
	if (pathSymbols.get("STORE", null) == null) {
		version (Windows) {
			pathSymbols["STORE"] = buildNormalizedPath("%APPDATA%/", etc, "./" ~ appName);
		} else {
			pathSymbols["STORE"] = buildNormalizedPath("~/", etc, "./" ~ appName);
		}
	}
	return pathSymbols["STORE"];
}
/** 
 * Builds a path to the language file.
 * Params:
 *   country = Country code.
 *   language = Language code.
 *   fileext = Extension/rest of the language file
 * Returns: The path to the localization file.
 * This function will be favored less moving forward.
 */
public string getPathToLocalizationFile (string country, string language, string fileext) @safe pure nothrow {
	if (fileext[0] == '.') fileext = fileext[1..$];
	if (country.length) return pathRoot ~ "/local/" ~ country ~ "-" ~ language ~ "." ~ fileext;
	return pathRoot ~ "/local/" ~ language ~ "." ~ fileext;
}
///Builds a path to the asset path.
///This function will be favored less moving forward.
public string getPathToAsset (string path) @safe pure {
	if (startsWith(path, "%PATH%")) path = path[6..$];
	else if (startsWith(path, "../", "..\\")) path = path[3..$];
	//else if (startsWith(path, ["./", ".\\"])) path = path[2..$];
	return buildNormalizedPath(pathRoot ~ dirSeparator ~ path);
}
/// Subtitutes symbols found in `path`, then returns the resolved path.
/// Can substitute symbols other than path related, e.g. can be used for version selection.
/// This function will be favored more moving forward.
public string resolvePath(string path) @safe {
	import pixelperfectengine.system.etc : interpolateStr;
	return interpolateStr(path, pathSymbols);
}
/**
 * Implements the RIFF serialization system (Maybe remove?)
 */
public struct RIFFHeader{
	char[4] data;
	uint length;
}
