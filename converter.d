﻿module converter;

//import imageformats;

import graphics.bitmap;
import extbmp.extbmp;
import system.exc;
import system.etc;

import derelict.freeimage.freeimage;
//import derelict.freeimage.functions;
import derelict.freeimage.types;

import std.stdio;
import std.path;
import std.bitmanip;
import std.conv;

/*Bitmap32Bit import32BitBitmapFromFile(string filename){

	FREE_IMAGE_FORMAT format;
	switch(filename[filename.length-3..filename.length]){
		case "png": format = FIF_PNG; break;
		case "tga": format = FIF_TARGA; break;
		case "bmp": format = FIF_BMP; break;
		default: break;
	}

	const char* fn = std.string.toStringz(filename);
	FIBITMAP* source = FreeImage_Load(format, fn);
	int iX = FreeImage_GetWidth(source), iY = FreeImage_GetHeight(source);
	Bitmap32Bit result = new Bitmap32Bit(iX,iY);
	switch(FreeImage_GetBPP(source)){
		case 32:
			for(int y; y < iY; y++){
				for(int x; x < iX; x++){
					RGBQUAD c; FreeImage_GetPixelColor(source, x, iY - 1 - y, &c);
					result.writePixel(x,y,c.rgbRed,c.rgbGreen,c.rgbBlue,c.rgbReserved);
					//writeln(c.rgbRed,',',c.rgbGreen,',',c.rgbBlue,',',c.rgbReserved,',');
				}
			}
			break;
		default:
			for(int y; y < iY; y++){
				for(int x; x < iX; x++){
					RGBQUAD c; FreeImage_GetPixelColor(source, x, iY - 1 - y, &c);
					result.writePixel(x,y,c.rgbRed,c.rgbGreen,c.rgbBlue,255);
					//writeln(c.rgbRed,',',c.rgbGreen,',',c.rgbBlue,',',c.rgbReserved,',');
				}
			}
			break;
	}

	return result;
}*/

enum NumberingStyle{
	DECIMAL		=	0,
	OCTAL		=	1,
	HEXADECIMAL	=	2,
	CHAR		=	3,
	WCHAR		=	4
}

class ImportData{
	string[] ID;
	string bitdepth, format;
	int x, y, IDpos;
	ushort paletteOffset;
	NamingConvention nc;
	this(string[] ID, string bitdepth, int x, int y, ushort paletteOffset){
		this.ID = ID;
		this.bitdepth = bitdepth;
		this.x = x;
		this.y = y;
		this.paletteOffset = paletteOffset;
		//this.numOfDigits = numOfDigits;
	}
	this(NamingConvention nc, string bitdepth, int x, int y, ushort paletteOffset){
		this.nc = nc;
		this.bitdepth = bitdepth;
		this.x = x;
		this.y = y;
		this.paletteOffset = paletteOffset;
		//this.numOfDigits = numOfDigits;
	}
	string getNextID(){
		if(nc is null){
			string result = ID[IDpos];
			IDpos++;
			return result;
		}else{
			string result = nc.wordA;
			switch(nc.incrStyle){
				case NumberingStyle.OCTAL: result ~= intToOct(IDpos+nc.startingPoint,nc.format); break;
				case NumberingStyle.HEXADECIMAL: result ~= intToHex(IDpos+nc.startingPoint,nc.format); break;
				default: result ~= to!string(IDpos+nc.startingPoint); break;
			}
			IDpos++;
			result ~= nc.wordB;
			return result;
		}
	}
	bool isMulti(){
		if(x > 0 && y > 0) return true;
		return false;
	}

}

class NamingConvention{
	string wordA, wordB;
	NumberingStyle incrStyle;
	int startingPoint, format;
	this(string wordA, string wordB, NumberingStyle incrStyle, int startingPoint, int format){
		this.wordA = wordA;
		this.wordB = wordB;
		this.incrStyle = incrStyle;
		this.startingPoint = startingPoint;
		this.format = format;
	}
}

public void importDirectlyToXMP(string path, ExtendibleBitmap target, ImportData id){
	FREE_IMAGE_FORMAT format;
	switch(extension(path)){
		case ".png": format = FIF_PNG; break;
		case ".tga": format = FIF_TARGA; break;
		case ".bmp": format = FIF_BMP; break;
		default: break;
	}
	const char* fn = std.string.toStringz(path);
	FIBITMAP* source = FreeImage_Load(format, fn);
	int iX = FreeImage_GetWidth(source), iY = FreeImage_GetHeight(source);
	ubyte[] raw; ushort[] raw16;
	switch(id.bitdepth){
		case "1bit":
			BitArray ba = BitArray(cast(void[])raw, 0);
			ba.length(iX * iY);
			for(int y; y < iY; y++){
				for(int x; x < iX; x++){
					ubyte c; FreeImage_GetPixelIndex(source, x, iY - 1 - y, &c);
					if(c != 0){
						ba[x + (iX * y)] = true;
					}
				}
			}
			break;
		case "16bit": 
			for(int y; y < iY; y++){
				for(int x; x < iX; x++){
					ubyte c; FreeImage_GetPixelIndex(source, x, iY - 1 - y, &c);
					raw16 ~= to!ushort(id.paletteOffset + c);
				}
			} 
			break;
		default:
			switch(FreeImage_GetBPP(source)){
				case 1,2,4,8:
					for(int y; y < iY; y++){
						for(int x; x < iX; x++){
							ubyte c; FreeImage_GetPixelIndex(source, x, iY - 1 - y, &c);
							raw ~= c;
						}
					}
					break;
				case 32:
					for(int y; y < iY; y++){
						for(int x; x < iX; x++){
							RGBQUAD c; FreeImage_GetPixelColor(source, x, iY - 1 - y, &c);
							//result.writePixel(x,y,c.rgbRed,c.rgbGreen,c.rgbBlue,c.rgbReserved);
							//writeln(c.rgbRed,',',c.rgbGreen,',',c.rgbBlue,',',c.rgbReserved,',');
							raw ~= [c.rgbRed,c.rgbGreen,c.rgbBlue,c.rgbReserved];
						}
					}
					break;
				default:
					for(int y; y < iY; y++){
						for(int x; x < iX; x++){
							RGBQUAD c; FreeImage_GetPixelColor(source, x, iY - 1 - y, &c);
							//result.writePixel(x,y,c.rgbRed,c.rgbGreen,c.rgbBlue,255);
							//writeln(c.rgbRed,',',c.rgbGreen,',',c.rgbBlue,',',c.rgbReserved,',');
							raw ~= [c.rgbRed,c.rgbGreen,c.rgbBlue,255];
						}
					}
					break;
			}
			break;
	}
	if(id.isMulti){
		if(iX%id.x > 0 || iY%id.y > 0){
			throw new BitmapFormatException("Incorrect sizes for slicing!");
		}
		if(id.bitdepth == "16bit"){
			//target.addBitmap(raw16,id.x,id.y,id.bitdepth,id.ID[0]);
			for(int jY; jY < iY / id.y; jY++){
				for(int jX; jX < iX / id.x; jX++){
					ushort[] raw2;
					for(int y; y < id.y; y++){
						int from = ((jY * id.y * iX) + (y * iX) + (jX * id.x)), t = from + id.x;
						raw2 ~= raw16[from..t];
					}
					target.addBitmap(raw2,id.x,id.y,id.bitdepth,id.getNextID(),id.format);
					//si++;
				}
			}
		}else{
			int pitch = 1;
			if(id.bitdepth == "32bit")pitch = 4;
			for(int jY; jY < iY / id.y; jY++){
				for(int jX; jX < iX / id.x; jX++){
					ubyte[] raw2;
					for(int y; y < id.y; y++){
						int from = pitch * ((jY * id.y * iX) + (y * iX) + (jX * id.x)), t = from + (id.x * pitch);
						raw2~= raw[from..t];
					}
					target.addBitmap(raw2,id.x,id.y,id.bitdepth,id.getNextID(),id.format);
					//si++;
				}
			}
			
		}
	}else{
		if(id.bitdepth == "16bit"){
			target.addBitmap(raw16,iX,iY,id.bitdepth,id.ID[0]);
		}else{
			target.addBitmap(raw,iX,iY,id.bitdepth,id.ID[0],id.format);
		}
	}
}

public void importPaletteDirectlyToXMP(string path, ExtendibleBitmap target, string paletteID, ushort offset = 0){
	FREE_IMAGE_FORMAT format;
	switch(extension(path)){
		case ".png": format = FIF_PNG; break;
		case ".tga": format = FIF_TARGA; break;
		case ".bmp": format = FIF_BMP; break;
		default: break;
	}
	const char* fn = std.string.toStringz(path);
	FIBITMAP* source = FreeImage_Load(format, fn);
	uint bitdepth = FreeImage_GetBPP(source);

	ubyte[] palette;
	switch(bitdepth){
		case 4: palette.length = 64; break;
		case 8: palette.length = 1024; break;
		default: break;
	}
	RGBQUAD* colors = FreeImage_GetPalette(source);
	//RGBQUAD.sizeof;
	palette[0] = 0;
	palette[1] = colors.rgbRed;
	palette[2] = colors.rgbGreen;
	palette[3] = colors.rgbBlue;
	for(int i = 4; i < palette.length; i+=4){
		colors++;
		palette[i] = 255;
		palette[i + 1] = colors.rgbRed;
		palette[i + 2] = colors.rgbGreen;
		palette[i + 3] = colors.rgbBlue;

	}
	target.addPalette(cast(void[])palette, paletteID);
}

public Bitmap32Bit getBitmapPreview(ExtendibleBitmap xmp, string ID){
	Bitmap32Bit result;
	switch(xmp.getBitDepth(ID)){
		case "32bit":
			result = new Bitmap32Bit(cast(ubyte[])xmp.getBitmap(ID),xmp.getXsize(ID),xmp.getYsize(ID));
			break;
		case "16bit":
			ushort[] raw = xmp.get16bitBitmap(ID);
			ubyte[] clut = cast(ubyte[])xmp.getPalette(xmp.getPaletteMode(ID));
			ubyte[] res2;
			foreach(c; raw){
				ubyte[4] foo = *cast(ubyte[4]*)(clut.ptr + (c*4));
				res2 ~= foo;
			}
			result = new Bitmap32Bit(res2,xmp.getXsize(ID),xmp.getYsize(ID));
			break;
		case "8bit":
			ubyte[] raw = xmp.get8bitBitmap(ID);
			ubyte[] clut = cast(ubyte[])xmp.getPalette(xmp.getPaletteMode(ID));
			//writeln(clut);
			ubyte[] res2;
			foreach(c; raw){
				ubyte[4] foo = *cast(ubyte[4]*)(clut.ptr + (c*4));
				writeln(foo);
				res2 ~= foo;
			}
			result = new Bitmap32Bit(res2,xmp.getXsize(ID),xmp.getYsize(ID));
			break;
		default: break;
	}
	return result;
}

enum LookupMethod : uint{
	NearestValue	=	1,
	Dithering		=	2
}