/*
 *Copyright (C) 2015, by Laszlo Szeremi under the Boost license.
 *
 *VDP Engine, raster module
 */
module graphics.raster;

import graphics.layers;
import graphics.bitmap;
import derelict.sdl2.sdl;
public import graphics.color;
import std.conv;
import std.stdio;

//Used to invoke the blitting when the raster finished its work.
public interface RefreshListener{
    public void refreshFinished();
}

//Used to read the output from the raster and show it on the screen.
public interface IRaster{
    public SDL_Surface* getOutput();
}

//Reads the data from the layers, then writes it to an SDL_Surface.
public class Raster : IRaster{
    private ushort rX, rY;
    public SDL_Surface* workpad;
    //IMPORTANT: Color 0 is used as a default and writes it to the raster if it can't find a layer with non-transparent pixel at a given position
    public Color[ushort] palette;
    private ILayer[] layerList;
    private bool r;
    private RefreshListener[int] rL;


    //Default constructor. x and y : represent the resolution of the raster.
    public this(ushort x, ushort y){
        workpad = SDL_CreateRGBSurface(SDL_SWSURFACE, x, y, 32, 0x000000ff, 0x0000ff00, 0x00ff0000, 0xff000000);
        rX=x;
        rY=y;
    }
    //Adds a RefreshListener to its list.
    public void addRefreshListener(RefreshListener r, int i){
        rL[i] = r;
    }
    //Replaces the layer at the given number.
    public void replaceLayer(ILayer l, int i){
        layerList[i] = l;
    }
    //Adds a layer at the highest available priority. 0 is highest.
    public void addLayer(ILayer l){
        layerList ~= l;
    }
    //Draws the objects from the layers to the raster.
    //Reads a pixel from the layer with the highest priority, it it's not transparent then it writes to the workpad.
    //If it's transparent then tests the next layer's pixel at the same position.
    //If it can't find a layer with non-transparent pixel, it writes the color with the ID of 0.
    public void refresh(){
        r = true;
        SDL_LockSurface(workpad);
        int layerNum;
        for(ushort i = 0; i < rY; i++){

            for(ushort j = 0; j < rX; j++){
                layerNum = 0;
                bool next;
                do{

                    if(layerNum == layerList.length){
                        writeToWorkpad(j,i,0);
                        next = true;
                    }
                    else{
                        PixelData pd = layerList[layerNum].getPixelData(j,i);

                        if(!pd.alpha){
                            //writeln(0);
                            writeToWorkpad(j,i,pd.color);
                            next = true;
                        }
                        else{
                            layerNum++;
                        }
                    }
                }while(!next);
            }

        }
        SDL_UnlockSurface(workpad);
        r = false;
        foreach(r; rL){
            (&r).refreshFinished;
        }
    }
    //Returns the workpad.
    public SDL_Surface* getOutput(){
        return workpad;
    }
    //Writes a pixel to the given place.
    void writeToWorkpad(int x, int y, ushort color){
//        if(!(color == 0))        writeln(color);
        ubyte *p = cast(ubyte*)this.workpad.pixels + y * workpad.pitch + x * 4;
        //writeln(x);
        //writeln(y);
        *p = palette[color].getB();
        p = p +1;
        *p = palette[color].getG();
        p = p +1;
        *p = palette[color].getR();
        p = p +1;
        *p = 255;


    }
    //Returns if the raster is refreshing.
    public bool isRefreshing(){
        return r;
    }
}
