module graphics.bitmap;
import std.stdio;

/*
 *Copyright (C) 2015, by Laszlo Szeremi under the Boost license.
 *
 *VDP Engine, bitmap module
 */


public class Bitmap16Bit{

    private ushort pixels[];
    private ushort iX;
    private ushort iY;
    //Creates an empty bitmap.
    this(ushort x, ushort y){
        iX=x;
        iY=y;
        pixels.length=x*y;
    }
    //Creates a bitmap from an array.
    this(ushort[] p, ushort x, ushort y){
        iX=x;
        iY=y;
        pixels=p;
        //writeln(pixels.length);
    }
    //Returns the pixel at the given position.
    public ushort readPixel(ushort x, ushort y){

        return pixels[x+(iX*y)];

    }
    //Writes the pixel at the given position.
    public void writePixel(ushort x, ushort y, ushort color){
        pixels[x+(iX*y)]=color;
    }
    //Resizes the bitmap.
    //Might result in corrupting the data. Intended for use with effects.
    public void resize(ushort x, ushort y){
        pixels.length=x*y;
    }
    //Getters for each sizes.
    public ushort getX(){
        return iX;
    }
    public ushort getY(){
        return iY;
    }
    //Flips the bitmap.
    public void swapX(){
        ushort foo;
        for(int i; i<iY; i++){
            for(int j; j<iX/2; j++){
                foo=pixels[j+(iX*i)];
                pixels[j+(iX*i)]=pixels[(iX*i)+iX-j];
                pixels[(iX*i)+iX-j]=foo;
            }
        }
    }
    public void swapY(){
        ushort foo;
        for(int i; i<iX; i++){
            for(int j; j<iY/2; j++){
                foo=pixels[j+(iY*i)];
                pixels[j+(iY*i)]=pixels[(iY*i)+iY-j];
                pixels[(iY*i)+iY-j]=foo;
            }
        }
    }


}
