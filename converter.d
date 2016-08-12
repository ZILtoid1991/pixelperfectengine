module converter;

import imageformats;

import graphics.bitmap;

Bitmap32Bit importBitmapFromFile(string filename){
	IFImage source = read_image(filename, ColFmt.RGBA);
	Bitmap32Bit result = new Bitmap32Bit(source.w, source.h);
	for(int y; y < result.getY; y++){
		for(int x; x < result.getX; x++){
			ubyte[4] p = *cast(ubyte[4]*)(source.pixels.ptr + (y * result.getX) + x);
			result.writePixel(x,y,p[0],p[1],p[2],p[3]);

		}
	}
	return result;
}



Bitmap32Bit[] sliceBitmap(Bitmap32Bit source, int sizeX, int sizeY){
	if(source.getX()%sizeX != 0 || source.getY%sizeY != 0){
		throw new Exception("Image doesn't have the correct size!", __FILE__, __LINE__, null);
	}
	Bitmap32Bit[] bmp;
	bmp.length = (source.getX()/sizeX) * (source.getY/sizeY);
	for(int iY ; iY < source.getY/sizeY ; iY++){
		for(int iX ; iX < source.getX()/sizeX ; iX++){
			bmp[iX+(iY*source.getX()/sizeX)] = new Bitmap32Bit(sizeX, sizeY);
			for(int y ; y < sizeY ; y++){
				for(int x ; x < sizeX; x++){
					ubyte[4] pixel = source.readPixel(x+(iX*sizeX),y+(iY*sizeY));
					bmp[iX+(iY*(source.getX()/sizeX))].writePixel(x,y,pixel[1],pixel[2],pixel[3],pixel[0]);
				}
			}

		}
	}
	return bmp;
}

Bitmap16Bit[] sliceBitmap(Bitmap16Bit source, int sizeX, int sizeY){
	if(source.getX()%sizeX != 0 || source.getY%sizeY != 0){
		throw new Exception("Image doesn't have the correct size!", __FILE__, __LINE__, null);
	}
	Bitmap16Bit[] bmp;
	bmp.length = (source.getX()/sizeX) * (source.getY/sizeY);
	for(int iY ; iY < source.getY/sizeY ; iY++){
		for(int iX ; iX < source.getX()/sizeX ; iX++){
			bmp[iX+(iY*source.getX()/sizeX)] = new Bitmap16Bit(sizeX, sizeY);
			for(int y ; y < sizeY ; y++){
				for(int x ; x < sizeX; x++){
					bmp[iX+(iY*(source.getX()/sizeX))].writePixel(x,y,source.readPixel(x+(iX*sizeX),y+(iY*sizeY)));
				}
			}

		}
	}
	return bmp;
}

Bitmap16Bit convertBitmapTo16Bit(Bitmap32Bit source, ubyte[] palette, LookupMethod method = LookupMethod.NearestValue){
	return null;
}

enum LookupMethod : uint{
	NearestValue	=	1,
	AreaAverage		=	2,
	Dithering		=	3
}