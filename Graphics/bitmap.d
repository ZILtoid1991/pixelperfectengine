module graphics.bitmap;
//import std.bitmanip;

import system.exc;

/*
 *Copyright (C) 2015, by Laszlo Szeremi under the Boost license.
 *
 *VDP Engine, bitmap module
 */


public class Bitmap16Bit{
//	private BitArray collisionModel;
    private ushort[] pixels;
    private int iX;
    private int iY;
    //Creates an empty bitmap.
    this(int x, int y){
        iX=x;
        iY=y;
        pixels.length=x*y;
    }
    //Creates a bitmap from an array.
    this(ushort[] p, int x, int y){
		if (p.length < x * y)
			throw new BitmapFormatException("Incorrect Bitmap size exception!");
        iX=x;
        iY=y;
        pixels=p;
        
    }
    //Returns the pixel at the given position.
    public ushort readPixel(int x, int y){

        return pixels[x+(iX*y)];

    }
	public ushort[] readRow(int row){

		return pixels[(iX*row) .. ((iX*row)+iX)];
	}
	public ushort[] readRowReverse(int row){
		row = iY-row-1;
		return pixels[(iX*row) .. ((iX*row)+iX)];
	}
	public ushort[] readChunk(int row, int offsetL, int offsetR){
		return pixels[((iX*row)+offsetL) .. ((iX*row)+iX-offsetR)];
	}
	public ushort* getPtr(){
		return pixels.ptr;
	}
    //Writes the pixel at the given position.
    public void writePixel(int x, int y, ushort color){
        pixels[x+(iX*y)]=color;
	}
    //Resizes the bitmap.
    //Might result in corrupting the data. Intended for use with effects.
    public void resize(int x, int y){
        pixels.length=x*y;
    }
   
	public void clear(){
		for(int i ; i < pixels.length ; i++)
			pixels[0] = 0;
	}
	//Getters for each sizes.
    public int getX(){
        return iX;
    }
    public int getY(){
        return iY;
    }
    //Flips the bitmap.
    public void swapX(){
        /*ushort foo;
        for(int i; i<iY; i++){
            for(int j; j<iX/2; j++){
                foo=pixels[j+(iX*i)];
                pixels[j+(iX*i)]=pixels[(iX*i)+iX-j];
                pixels[(iX*i)+iX-j]=foo;
            }
        }*/
    }
    public void swapY(){
		ushort[] bar;

		for(int y = iY -1 ; y >= 0 ; y--){
			bar ~= readRow(y);
		}
		pixels = bar;
    }
	/*public bool isTransparent(int x, int y){
		return collisionModel[x+(iX*y)];
	}
	public BitArray getRowForDetection(int row, int from, int length, ubyte extraBits){
		BitArray ba = BitArray();
		if((extraBits == 1 || extraBits == 3) && collisionModel[(iX*row)+from-1]){
			ba ~= true;
		}else{
			ba ~= false;
		}
		ba ~= collisionModel[(iX*row)+from..(iX*row)+from+length];
		if((extraBits == 2 || extraBits == 3) && collisionModel[(iX*row)+from+length+1]){
			ba ~= true;
		}else{
			ba ~= false;
		}
		return ba;
	}*/
	public bool[] generateStandardCollisionModel(){
		bool[] ba;
		foreach(ushort c; pixels){
			if(c == 0){
				ba ~= false;
			}else{
				ba ~= true;
			}
		}
		return ba;
	}
	/*public void useExternalCollisionModel(BitArray ba){
		if(ba.length() != iX * iY){
			throw new BitmapFormatException("Collision model has a different size.");
		}
		collisionModel = ba;
	}*/
}
public class Bitmap32Bit{
	//private BitArray collisionModel;
	private ubyte[] pixels;
	private int iX, iY;

	public this(int x, int y){
		iX = x;
		iY = y;
		pixels.length = x * y * 4;
	}

	public this(ubyte[] p, int x, int y){
		if (p.length < x * y * 4)
			throw new BitmapFormatException("Incorrect Bitmap size exception!");
		iX = x;
		iY = y;
		this.pixels = pixels;
	}

	public ubyte[4] readPixel(int x, int y){
		
		return *cast(ubyte[4]*)(pixels.ptr + x+(iX*y)*4);
		
	}
	public ubyte[] readRow(int row){
		
		return pixels[(iX*row*4) .. ((iX*row)+iX)*4];
	}
	public ubyte[] readRowReverse(int row){
		row = iY-row-1;
		return pixels[(iX*row*4) .. ((iX*row)+iX)*4];
	}
	public ubyte[] readChunk(int row, int offsetL, int offsetR){
		return pixels[((iX*row)+offsetL)*4 .. ((iX*row)+iX-offsetR)*4];
	}
	//Writes the pixel at the given position.
	public void writePixel(int x, int y, ubyte r, ubyte g, ubyte b, ubyte a){
		pixels[x * (4 * y * iX)] = a;
		pixels[x * (4 * y * iX) + 1] = r;
		pixels[x * (4 * y * iX) + 2] = g;
		pixels[x * (4 * y * iX) + 3] = b;
	}

	public ubyte* getPtr(){
		return pixels.ptr;
	}

	public ubyte[] getRawdata(){
		return pixels;
	}

	public bool[] generateStandardCollisionModel(){
		bool[] ba;
		for(int i; i < pixels.length; i+=4){
			if(pixels[i] == 0){
				ba ~= false;
			}else{
				ba ~= true;
			}
		}
		return ba;
	}
	//Getters for each sizes.
	public int getX(){
		return iX;
	}
	public int getY(){
		return iY;
	}

}
/*public interface Collidable{
	public bool isTransparent(int x, int y);
	public BitArray getRowForDetection(int row, int from, int length, ubyte extraBits);
}*/
