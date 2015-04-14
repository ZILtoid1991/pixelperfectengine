module system.tgaconv;

import std.stdio;
import std.file;
import std.conv;
import std.algorithm;

import graphics.raster;
import graphics.bitmap;
import system.exc;
import system.file;

import tga.io.readers;
import tga.model;

//Use setupPalette method on the raster before importing
void importColorMapFromTGA(File file, Raster raster){
	importColorMapFromTGA(file, raster, 0);
}

void importColorMapFromTGA(File file, Raster raster, ushort offset){
	Image targa = readImage(file);
	if(targa.header.colorMapType == 0){
		throw new BitmapFormatException("Colormap not present in imported TGA file!", __FILE__, __LINE__, null);
	}
	Pixel[] palette = targa.colorMap;
	for(int i ; i < palette.length ; i++){
		raster.editColor(to!ushort(i+offset), palette[i].r(), palette[i].g(), palette[i].b());
	}
}

int lookFor(Pixel a, Pixel[] b){
	for(int i ; i < b.length ; i++){
		if(b[i] == a) return i;
	}
	return -1;
}

Bitmap16Bit importBitmapFromTGA(File file, ushort colorOffset){
	Image targa = readImage(file);
	if(targa.header.pixelDepth == 24 || targa.header.pixelDepth == 32){
		throw new BitmapFormatException("Bit depth larger than 16 bit is not supported in the engine!", __FILE__, __LINE__, null);
	}
	Bitmap16Bit bmp = new Bitmap16Bit(targa.header.width, targa.header.height);
	for(int y ; y < targa.header.height ; y++){
		for(int x ; x < targa.header.width ; x++){
			ushort c = to!ushort(lookFor(targa.pixels[x+(targa.header.width*y)], targa.colorMap)+colorOffset);
			bmp.writePixel(x, y, c);
		}
	}
	bmp.swapY();
	return bmp;
}

Bitmap16Bit[] importMultipleBitmapFromTGA(File file, int offsetX, int offsetY){
	Image targa = readImage(file);
	if(targa.header.pixelDepth == 24 || targa.header.pixelDepth == 32){
		throw new BitmapFormatException("Bit depth larger than 16 bit is not supported in the engine!", __FILE__, __LINE__, null);
	}
	if(targa.header.width%offsetX != 0 || targa.header.height%offsetY != 0){
		throw new BitmapFormatException("Image doesn't have the correct size!", __FILE__, __LINE__, null);
	}
	Bitmap16Bit[] bmp;
	bmp.length = (targa.header.width/offsetX) * (targa.header.height/offsetY);
	for(int iY ; iY < targa.header.height/offsetY ; iY++){
		for(int iX ; iX < targa.header.width/offsetX ; iX++){
			bmp[iX+(iY*targa.header.width/offsetX)] = new Bitmap16Bit(offsetX, offsetY);
			for(int y ; y < offsetY ; y++){
				for(int x ; x < offsetX; x++){
					ushort c = to!ushort(lookFor(targa.pixels[(iX*offsetX)+x+((iY*offsetY*targa.header.width)+y*targa.header.width)], targa.colorMap));
					bmp[iX+(iY*(targa.header.width/offsetX))].writePixel(x,y,c);
				}
			}
		}
	}
	return bmp;
}