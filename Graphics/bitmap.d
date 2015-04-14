module graphics.bitmap;
import std.stdio;

/*
 *Copyright (C) 2015, by Laszlo Szeremi under the Boost license.
 *
 *VDP Engine, bitmap module
 */


public class Bitmap16Bit{

    private ushort pixels[];
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
        iX=x;
        iY=y;
        pixels=p;
        //writeln(pixels.length);
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
    //Writes the pixel at the given position.
    public void writePixel(int x, int y, ushort color){
        pixels[x+(iX*y)]=color;
	}
    //Resizes the bitmap.
    //Might result in corrupting the data. Intended for use with effects.
    public void resize(int x, int y){
        pixels.length=x*y;
    }
    //Getters for each sizes.
	public void clear(){
		for(int i ; i < pixels.length ; i++)
			pixels[0] = 0;
	}
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


}
