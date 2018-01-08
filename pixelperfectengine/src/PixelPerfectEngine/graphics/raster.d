/*
 * Copyright (C) 2015-2017, by Laszlo Szeremi under the Boost license.
 *
 * Pixel Perfect Engine, graphics.bitmap module
 */
module PixelPerfectEngine.graphics.raster;

import PixelPerfectEngine.graphics.outputScreen;
import PixelPerfectEngine.graphics.layers;
import PixelPerfectEngine.graphics.bitmap;
import derelict.sdl2.sdl;
public import PixelPerfectEngine.graphics.common;
import std.conv;
import std.algorithm.sorting;
import std.algorithm.mutation;
import core.time;

///The raster calls it every time it finishes the drawing to the framebuffers.
public interface RefreshListener{
    public void refreshFinished();
}

///Used to read the output from the raster and show it on the screen.
public interface IRaster{
    public SDL_Texture* getOutput();
}

///Handles multiple layers onto one framebuffer.
public class Raster : IRaster{
    private ushort rX, rY;		///Stores screen resolution
    //public SDL_Surface* workpad;
	public SDL_Texture*[] frameBuffer;
	public void*[] fbData;
	public int[] fbPitch;
    public Color[] palette; ///FORMAT IS ARGB. Master palette, layers or bitmaps can define their own palettes if needed.
    private Layer[int] layerList;	///Stores the layers by their priorities.
	private int[] layerPriorityHandler, threads;
    private bool r;
	private int[2] doubleBufferRegisters;
    private RefreshListener[] rL;
	private MonoTime frameTime, frameTime_1;
	private Duration delta_frameTime;
	private real framesPerSecond, avgFPS;
	//public Bitmap16Bit[2] frameBuffer;

    ///Default constructor. x and y : represent the resolution of the raster.
    public this(ushort x, ushort y, OutputScreen oW, int[] threads = [0]){
        //workpad = SDL_CreateRGBSurface(SDL_SWSURFACE, x, y, 32, 0x000000ff, 0x0000ff00, 0x00ff0000, 0xff000000);
		this.threads = threads;
		SDL_Renderer* renderer = oW.renderer;
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
		oW.setMainRaster(this);
		addRefreshListener(oW);
	}
	public @nogc @property real fps(){
		return framesPerSecond;
	}
	public @nogc @property real avgfps(){
		return avgFPS;
	}
	public @nogc void resetAvgfps(){
		avgFPS = 0;
	}
	~this(){
		foreach(SDL_Texture* t ; frameBuffer){
			if(t)
				SDL_DestroyTexture(t);
		}
	}
    //Adds a RefreshListener to its list.
    public void addRefreshListener(RefreshListener r){
        rL ~= r;
    }
	///Writes a color at the last position
	public void addColor(Color val){
		palette ~= val;
	}

	public void editColor(ushort c, Color val){
		palette[c] = val;
	}
	//Sets the number of colors.
	public void setupPalette(int i){
		palette.length = i;
	}
    ///Replaces the layer at the given number.
    public void replaceLayer(Layer l, int i){
		l.setRasterizer(rX, rY);
        layerList[i] = l;
    }
    ///Adds a layer at the given priority.
    public void addLayer(Layer l, int i){
		l.setRasterizer(rX, rY);
        layerList[i] = l;
		layerPriorityHandler ~= i;
		layerPriorityHandler.sort();
    }
	public void removeLayer(int n){
		layerList.remove(n);
		int[] newlayerPriorityHandler;
		for(int i; i < layerPriorityHandler.length; i++){
			//writeln(0);
			if(layerPriorityHandler[i] != n){
				newlayerPriorityHandler ~= layerPriorityHandler[i];

			}
		}
		layerPriorityHandler = newlayerPriorityHandler;
	}
	/**
	 * Refreshes the whole framebuffer. 
	 */
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

		SDL_LockTexture(frameBuffer[doubleBufferRegisters[0]], null, &fbData[doubleBufferRegisters[0]], &fbPitch[doubleBufferRegisters[0]]);

		for(int i ; i < layerPriorityHandler.length ; i++){
			layerList[layerPriorityHandler[i]].updateRaster(fbData[doubleBufferRegisters[0]], fbPitch[doubleBufferRegisters[0]], palette.ptr, threads);
		}
        
		SDL_UnlockTexture(frameBuffer[doubleBufferRegisters[0]]);
        r = false;

        foreach(r; rL){
            r.refreshFinished;
        }
		//get frame duration
		frameTime_1 = frameTime;
		frameTime = MonoTimeImpl!(ClockType.normal).currTime();
		delta_frameTime = frameTime_1 - frameTime;
		real delta_frameTime0 = to!real(delta_frameTime.total!"hnsecs"());
		framesPerSecond = framesPerSecond + 1 / (delta_frameTime0 / 10000);
		if(avgFPS)
			avgFPS = (avgFPS + framesPerSecond) / 2;
		else
			avgFPS = framesPerSecond;
    }

	
    ///Returns the workpad.
    public SDL_Texture* getOutput(){
		if(fbData[0] !is null)
			return frameBuffer[0];
		return frameBuffer[1];
    }
    
    
    ///Returns if the raster is refreshing.
    public bool isRefreshing(){
        return r;
    }
}
