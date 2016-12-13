/*
 *Copyright (C) 2015, by Laszlo Szeremi under the Boost license.
 *
 *VDP Engine, raster module
 */
module graphics.raster;

import graphics.layers;
import graphics.bitmap;
import derelict.sdl2.sdl;
//public import graphics.color;
import std.conv;
import std.stdio;

//Used to invoke the blitting when the raster finished its work.
public interface RefreshListener{
    public void refreshFinished();
}

//Used to read the output from the raster and show it on the screen.
public interface IRaster{
    public SDL_Texture* getOutput();
}

///Handles multiple layers onto one framebuffer.
public class Raster : IRaster{
    private ushort rX, rY;
    //public SDL_Surface* workpad;
	public SDL_Texture*[] frameBuffer;
	public void*[] fbData;
	public int[] fbPitch;
    //IMPORTANT: Color 0 is used as a default and writes it to the raster if it can't find a layer with non-transparent pixel at a given position
    //public Color[ushort] palette;
	//private ubyte[ushort] colorR;
	//private ubyte[ushort] colorG;
	//private ubyte[ushort] colorB;
	public ubyte[] palette; //FORMAT ARGB
    private ILayer[] layerList;
    private bool r;
	private int[2] doubleBufferRegisters;
    private RefreshListener[int] rL;
	//public Bitmap16Bit[2] frameBuffer;

    //Default constructor. x and y : represent the resolution of the raster.
    public this(ushort x, ushort y, SDL_Renderer* renderer){
        //workpad = SDL_CreateRGBSurface(SDL_SWSURFACE, x, y, 32, 0x000000ff, 0x0000ff00, 0x00ff0000, 0xff000000);
        rX=x;
        rY=y;
		/*frameBuffer[0] = new Bitmap16Bit(x,y);
		frameBuffer[1] = new Bitmap16Bit(x,y);*/
		/*frameBuffer ~= SDL_CreateRGBSurface(SDL_SWSURFACE, x, y, 32, 0x000000ff, 0x0000ff00, 0x00ff0000, 0xff000000);
		frameBuffer ~= SDL_CreateRGBSurface(SDL_SWSURFACE, x, y, 32, 0x000000ff, 0x0000ff00, 0x00ff0000, 0xff000000);*/
		frameBuffer ~= SDL_CreateTexture(renderer, SDL_PIXELFORMAT_BGRX8888, SDL_TEXTUREACCESS_STREAMING, x, y);
		frameBuffer ~= SDL_CreateTexture(renderer, SDL_PIXELFORMAT_BGRX8888, SDL_TEXTUREACCESS_STREAMING, x, y);
		fbData ~= null;
		fbData ~= null;
		fbPitch ~= 0;
		fbPitch ~= 0;
		doubleBufferRegisters[0] = 1;
		doubleBufferRegisters[1] = 0;
	}

	~this(){
		foreach(SDL_Texture* t ; frameBuffer){
			SDL_DestroyTexture(t);
		}
	}
    //Adds a RefreshListener to its list.
    public void addRefreshListener(RefreshListener r, int i){
        rL[i] = r;
    }
	//Writes a color at the last position
	public void addColor(ubyte r, ubyte g, ubyte b, ubyte a = 255)	{
		/*colorR[c] = r;
		colorG[c] = g;
		colorB[c] = b;*/

		palette ~= a;
		palette ~= r;
		palette ~= g;
		palette ~= b;
		//palette[c][3] = [r,g,b];
	}

	public void editColor(ushort c, ubyte r, ubyte g, ubyte b, ubyte a = 255){
		palette[c*3] = a;
		palette[(c*3)+1] = r;
		palette[(c*3)+2] = g;
		palette[(c*3)+3] = b;
	}
	//Sets the number of colors.
	public void setupPalette(int i){
		palette.length = i * 3;
	}

	/*public void clearFramebuffer(){
		frameBuffer.destroy();
	}*/
    //Replaces the layer at the given number.
    public void replaceLayer(ILayer l, int i){
		l.setRasterizer(rX, rY);
        layerList[i] = l;
    }
    //Adds a layer at the highest available priority. 0 is highest.
    public void addLayer(ILayer l){
		l.setRasterizer(rX, rY);
        layerList ~= l;
    }
    
    public void refresh(){

        r = true;
		//this.clearFramebuffer();
		if(doubleBufferRegisters[0] == 0){
			doubleBufferRegisters[0] = 1;
			doubleBufferRegisters[1] = 0;
		}else{
			doubleBufferRegisters[0] = 0;
			doubleBufferRegisters[1] = 1;
		}
		//SDL_LockSurface(frameBuffer[doubleBufferRegisters[0]]);

		SDL_LockTexture(frameBuffer[doubleBufferRegisters[0]], null, &fbData[doubleBufferRegisters[0]], &fbPitch[doubleBufferRegisters[0]]);
		//SDL_SetSurfaceRLE(frameBuffer[doubleBufferRegisters[0]], 1);

		for(int i ; i < layerList.length ; i++){
			layerList[i].updateRaster(fbData[doubleBufferRegisters[0]], fbPitch[doubleBufferRegisters[0]], palette);
		}
        
		//writeToWorkpad(frameBuffer[doubleBufferRegisters[1]]);


		//frameBuffer[doubleBufferRegisters[1]] = frameBuffer[doubleBufferRegisters[0]];
		
		//SDL_SetSurfaceRLE(frameBuffer[doubleBufferRegisters[0]], 0);
		//SDL_UnlockSurface(frameBuffer[doubleBufferRegisters[0]]);
		SDL_UnlockTexture(frameBuffer[doubleBufferRegisters[0]]);
        r = false;

        foreach(r; rL){
            r.refreshFinished;
        }
		//frameBuffer.clear();
    }

	/*public void getPixel(ushort i, ushort j){
		int layerNum = 0;
		bool next;
		do{
			
			if(layerNum == layerList.length){
				writeToWorkpad(i,j,0);
				next = true;
			}
			else{
				PixelData pd = layerList[layerNum].getPixelData(i,j);
				
				if(!pd.alpha){
					//writeln(0);
					writeToWorkpad(i,j,pd.color);
					next = true;
				}
				else{
					layerNum++;
				}
			}
		}while(!next);
	}*/
    //Returns the workpad.
    public SDL_Texture* getOutput(){
		if(fbData[0] !is null)
			return frameBuffer[0];
		return frameBuffer[1];
    }
    //Writes a pixel to the given place.
    
    //Returns if the raster is refreshing.
    public bool isRefreshing(){
        return r;
    }
}
