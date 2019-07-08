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

import PixelPerfectEngine.extbmp.extbmp;

public import dimage.base;
import dimage.tga;
import dimage.png;

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
			PNG imageFile = PNG.load!File(file);
			return imageFile;
		default:
			throw new Exception("Unsupported file format!");
	}
}
/**
 * Loads a bitmap from Image.
 */
public T loadBitmapFromImage(T)(Image img) @trusted
		if(T.stringof == Bitmap4Bit.stringof || T.stringof == Bitmap8Bit.stringof || T.stringof == Bitmap16Bit.stringof
		|| T.stringof == Bitmap32Bit.stringof){
	// Later we might want to detect image type from classinfo, until then let's rely on similarities between types
	static if(T.stringof == Bitmap4Bit.stringof){
		if(img.getBitdepth != 4)
			throw new BitmapFormatException("Bitdepth mismatch exception!");
		return new Bitmap4Bit(img.getImageData, img.width, img.height);
	}else static if(T.stringof == Bitmap8Bit.stringof){
		if(img.getBitdepth != 8)
			throw new BitmapFormatException("Bitdepth mismatch exception!");
		return new Bitmap8Bit(img.getImageData, img.width, img.height);
	}else static if(T.stringof == Bitmap16Bit.stringof){
		if(img.getBitdepth != 16)
			throw new BitmapFormatException("Bitdepth mismatch exception!");
		return new Bitmap16Bit(reinterpretCast!ushort(img.getImageData), img.width, img.height);
	}else static if(T.stringof == Bitmap32Bit.stringof){
		if(img.getBitdepth != 32)
			throw new BitmapFormatException("Bitdepth mismatch exception!");
		return new Bitmap32Bit(reinterpretCast!Color(img.getImageData), img.width, img.height);
	}

}
//TODO: Make collision model loader for 1 bit bitmaps
/**
 * Loads a bitmap from disk.
 * Currently supported formats: *.tga, *.png
 */
public T loadBitmapFromFile(T)(string filename)
		if(T.stringof == Bitmap4Bit.stringof || T.stringof == Bitmap8Bit.stringof || T.stringof == Bitmap16Bit.stringof
		|| T.stringof == Bitmap32Bit.stringof){
	File f = File(filename);
	switch(extension(filename)){
		case ".tga", ".TGA":
			TGA imageFile = TGA.load!(File, false, false)(f);
			if(!imageFile.getHeader.topOrigin){
				imageFile.flipVertical;
			}
			static if(T.stringof == Bitmap4Bit.stringof){
				if(imageFile.getBitdepth != 4)
					throw new BitmapFormatException("Bitdepth mismatch exception!");
				return new Bitmap4Bit(imageFile.getImageData, imageFile.width, imageFile.height);
			}else static if(T.stringof == Bitmap8Bit.stringof){
				if(imageFile.getBitdepth != 8)
					throw new BitmapFormatException("Bitdepth mismatch exception!");
				return new Bitmap8Bit(imageFile.getImageData, imageFile.width, imageFile.height);
			}else static if(T.stringof == Bitmap16Bit.stringof){
				if(imageFile.getBitdepth != 16)
					throw new BitmapFormatException("Bitdepth mismatch exception!");
				return new Bitmap16Bit(imageFile.getImageData, imageFile.width, imageFile.height);
			}else static if(T.stringof == Bitmap32Bit.stringof){
				if(imageFile.getBitdepth != 32)
					throw new BitmapFormatException("Bitdepth mismatch exception!");
				return new Bitmap32Bit(imageFile.getImageData, imageFile.width, imageFile.height);
			}
		case ".png", ".PNG":
			PNG imageFile = PNG.load!File(f);
			static if(T.stringof == Bitmap8Bit.stringof){
				if(imageFile.getBitdepth != 8)
					throw new BitmapFormatException("Bitdepth mismatch exception!");
				return new Bitmap8Bit(imageFile.getImageData, imageFile.width, imageFile.height);
			}else static if(T.stringof == Bitmap32Bit.stringof){
				if(imageFile.getBitdepth != 32)
					throw new BitmapFormatException("Bitdepth mismatch exception!");
				return new Bitmap32Bit(imageFile.getImageData, imageFile.width, imageFile.height);
			}
		default:
			throw new Exception("Unsupported file format!");
	}
}
/**
 * Loads a bitmap sheet from file.
 * This one doesn't require TGA devarea extensions.
 */
public T[] loadBitmapSheetFromFile(T)(string filename, int x, int y)
		if(T.stringof == Bitmap4Bit.stringof || T.stringof == Bitmap8Bit.stringof || T.stringof == Bitmap16Bit.stringof
		|| T.stringof == Bitmap32Bit.stringof) {
	T source = loadBitmapFromFile!T(filename);
	if(source.width % x == 0 && source.height % y == 0){
		T[] output;
		static if (T.stringof == Bitmap4Bit.stringof)
			const size_t length = x / 2, pitch = source.width / 2;
		else static if (T.stringof == Bitmap8Bit.stringof)
			const size_t length = x, pitch = source.width;
		else static if (T.stringof == Bitmap16Bit.stringof)
			const size_t length = x * 2, pitch = source.width * 2;
		else static if (T.stringof == Bitmap32Bit.stringof)
			const size_t length = x * 4, pitch = source.width * 4;
		const size_t pitch0 = pitch * y;
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
 * Creates a bitmap sheet from an image file.
 * This one doesn't require embedded data.
 */
public T[] loadBitmapSheetFromImage(T)(Image img, int x, int y)
		if(T.stringof == Bitmap4Bit.stringof || T.stringof == Bitmap8Bit.stringof || T.stringof == Bitmap16Bit.stringof
		|| T.stringof == Bitmap32Bit.stringof) {
	T source = loadBitmapFromImage!T(img);
	if(source.width % x == 0 && source.height % y == 0){
		T[] output;
		static if (T.stringof == Bitmap4Bit.stringof)
			const size_t length = x / 2, pitch = source.width / 2;
		else static if (T.stringof == Bitmap8Bit.stringof)
			const size_t length = x, pitch = source.width;
		else static if (T.stringof == Bitmap16Bit.stringof)
			const size_t length = x * 2, pitch = source.width * 2;
		else static if (T.stringof == Bitmap32Bit.stringof)
			const size_t length = x * 4, pitch = source.width * 4;
		const size_t pitch0 = pitch * y;
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
			Color[] result;
			ubyte[] src = imageFile.getPaletteData;
			switch(imageFile.getPaletteBitdepth){
				case 24:
					for(ushort i; i < src.length; i+=3){
						result ~= Color(255, src[i + 2], src[i + 1], src[i]);
					}
					break;
				case 32:
					for(ushort i; i < src.length; i+=4){
						result ~= Color(src[i + 3], src[i + 2], src[i + 1], src[i]);
					}
					break;
				default:
					return [];
			}
			return result;
		case ".png", ".PNG":
			PNG imageFile = PNG.load(f);
			return cast(Color[])(cast(void[])imageFile.getPaletteData);
		default:
			throw new Exception("Unsupported file format!");
	}
}
/**
 * Gets a bitmap from the XMP file.
 * DEPRECATED! Recommended to use *.tga with devarea extensions or even *.png files.
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
 * Deprecated!
 */
public void loadPaletteFromXMP(ExtendibleBitmap xmp, string ID, Raster target, int offset = 0){
	target.palette = cast(Color[])xmp.getPalette(ID);


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
