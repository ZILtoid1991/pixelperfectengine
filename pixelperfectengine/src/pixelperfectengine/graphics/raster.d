/*
 * Copyright (C) 2015-2017, by Laszlo Szeremi under the Boost license.
 *
 * Pixel Perfect Engine, graphics.bitmap module
 */
module pixelperfectengine.graphics.raster;

import pixelperfectengine.graphics.outputscreen;
import pixelperfectengine.graphics.layers;
import pixelperfectengine.graphics.bitmap;
import bindbc.sdl;
public import pixelperfectengine.graphics.common;
import std.conv;
import std.algorithm.sorting;
import std.algorithm.mutation;
import core.time;
import collections.treemap;

///The raster calls it every time it finishes the drawing to the framebuffers.
public interface RefreshListener{
    public void refreshFinished();
}

///Used to read the output from the raster and show it on the screen.
public interface IRaster{
    public SDL_Texture* getOutput();
}
/**
 * Defines palette handling functions.
 * It provides various functions for safe palette handling.
 */
public interface PaletteContainer {
	/**
	 * Returns the palette of the object.
	 */
	public @property Color[] palette() @safe pure nothrow @nogc;
	///Returns the given palette index.
	public Color getPaletteIndex(ushort index) @safe pure nothrow @nogc const;
	///Sets the given palette index to the given value.
	public Color setPaletteIndex(ushort index, Color value) @safe pure nothrow @nogc;
	/**
	 * Adds a palette chunk to the end of the main palette.
	 */
	public Color[] addPaletteChunk(Color[] paletteChunk) @safe;
	/**
	 * Loads a palette into the object.
	 * Returns the new palette of the object.
	 */
	public Color[] loadPalette(Color[] palette) @safe;
	/**
	 * Loads a palette chunk into the object.
	 * The offset determines where the palette should be loaded.
	 * If it points to an existing place, the indices after that will be overwritten until the whole palette will be copied.
	 * If it points to the end or after it, then the palette will be made longer, and will pad with values #00000000 if needed.
	 * Returns the new palette of the object.
	 */
	public Color[] loadPaletteChunk(Color[] paletteChunk, ushort offset) @safe;
	/**
	 * Clears an area of the palette with zeroes.
	 * Returns the original area.
	 */
	public Color[] clearPaletteChunk(ushort lenght, ushort offset) @safe;
}

///Handles multiple layers onto one framebuffer.
public class Raster : IRaster, PaletteContainer{
    private ushort rX, rY;		///Stores screen resolution. Set overscan resolutions at OutputWindow
    //public SDL_Surface* workpad;
	public SDL_Texture*[] frameBuffer;
	public void* fbData;
	public int fbPitch;
	/**
	 * Color format is ARGB, with each index having their own transparency.
	 */
    protected Color[] _palette;
	alias LayerMap = TreeMap!(int, Layer);
	///Stores the layers by their priorities.
	public LayerMap layerMap;
    //private Layer[int] layerList;	
	private int[] threads;
    private bool r;
	protected ubyte nOfBuffers;		///Number of framebuffers, 2 for double buffering.
	protected ubyte updatedBuffer;	///Framebuffer currently being updated
	protected ubyte displayedBuffer;///Framebuffer currently being displayed
	//private int[2] doubleBufferRegisters;
    private RefreshListener[] rL;
	private MonoTime frameTime, frameTime_1;
	private Duration delta_frameTime;
	private real framesPerSecond, avgFPS;
	//public Bitmap16Bit[2] frameBuffer;

    ///Default constructor. x and y : represent the resolution of the raster.
    public this(ushort x, ushort y, OutputScreen oW, size_t paletteLength, ubyte buffers = 2){
        //workpad = SDL_CreateRGBSurface(SDL_SWSURFACE, x, y, 32, 0x000000ff, 0x0000ff00, 0x00ff0000, 0xff000000);
		//this.threads = threads;
		assert(paletteLength <= 65_536);
		_palette.length = paletteLength;
		SDL_Renderer* renderer = oW.renderer;
        rX=x;
        rY=y;
		nOfBuffers = buffers;
		for (int i ; i < buffers ; i++)
			frameBuffer ~= SDL_CreateTexture(renderer, SDL_PIXELFORMAT_BGRX8888, SDL_TEXTUREACCESS_STREAMING, x, y);
		/+doubleBufferRegisters[0] = 1;
		doubleBufferRegisters[1] = 0;+/
		oW.setMainRaster(this);
		addRefreshListener(oW);
		frameTime = MonoTimeImpl!(ClockType.normal).currTime();
		framesPerSecond = 0.0;
		avgFPS = 0.0;
	}
	/**
	 * Returns a copy of the palette of the object.
	 */
	public @property Color[] palette() @safe pure nothrow @nogc {
		return _palette;
	}
	public Color getPaletteIndex(ushort index) @safe pure nothrow @nogc const {
		return _palette[index];
	}
	public Color setPaletteIndex(ushort index, Color val) @safe pure nothrow @nogc {
		return _palette[index] = val;
	}
	/**
	 * Loads a palette into the object.
	 * Returns the new palette of the object.
	 */
	public Color[] loadPalette(Color[] palette) @safe {
		return _palette = palette;
	}
	/**
	 * Adds a palette chunk to the end of the main palette.
	 */
	public Color[] addPaletteChunk(Color[] paletteChunk) @safe {
		return _palette ~= paletteChunk;
	}
	/**
	 * Loads a palette chunk into the object.
	 * The offset determines where the palette should be loaded.
	 * If it points to an existing place, the indices after that will be overwritten until the whole palette will be copied.
	 * If it points to the end or after it, then the palette will be made longer, and will pad with values 0x00_00_00_00 if needed.
	 * Returns the new palette of the object.
	 */
	public Color[] loadPaletteChunk(Color[] paletteChunk, ushort offset) @safe {
		if (paletteChunk.length + offset < _palette.length) 
			_palette.length += (offset - _palette.length) + paletteChunk.length;
		for (int i = offset, j ; j < paletteChunk.length ; i++, j++) 
			_palette[i] = paletteChunk[j];
		return _palette;
	}
	/**
	 * Clears an area of the palette with zeroes.
	 * Returns the original area.
	 */
	public Color[] clearPaletteChunk(ushort lenght, ushort offset) @safe {
		Color[] backup = _palette[offset..offset + lenght].dup;
		for (int i = offset ; i < offset + lenght ; i++) {
			_palette[i] = Color(0);
		}
		return backup;
	}
	/**
	 * Returns the current FPS count.
	 */
	public @property real fps() @safe @nogc pure nothrow const {
		return framesPerSecond;
	}
	/**
	 * Returns the current average FPS count.
	 */
	public @property real avgfps() @safe @nogc pure nothrow const {
		return avgFPS;
	}
	/**
	 * Resets the avgFPS to zero.
	 */
	public void resetAvgfps() @safe @nogc pure nothrow {
		avgFPS = 0;
	}
	~this(){
		foreach(SDL_Texture* t ; frameBuffer){
			if(t)
				SDL_DestroyTexture(t);
		}
	}
    ///Adds a RefreshListener to its list.
    public void addRefreshListener(RefreshListener r){
        rL ~= r;
    }
	///Edits the given color index.
	///Will be set deprecated in 0.10.0
	public void editColor(ushort c, Color val){
		_palette[c] = val;
	}
	///Sets the number of colors.
	///Will be set deprecated in 0.10.0
	public void setupPalette(int i) {
		_palette.length = i;
	}
    ///Replaces the layer at the given number.
	///Deprecated!
    public deprecated void replaceLayer(Layer l, int i){
		addLayer(l, i);
    }
    ///Adds a layer at the given priority.
    public void addLayer(Layer l, int i) @safe pure nothrow {
		l.setRasterizer(rX, rY);
		layerMap[i] = l;
    }
	///Removes a layer at the given priority.
	public void removeLayer(int n) @safe pure nothrow {
		layerMap.remove(n);
	}
	public Layer getLayer(int n) @nogc @safe pure nothrow {
		return layerMap[n];
	}
	/**
	 * Refreshes the whole framebuffer.
	 */
    public void refresh() {
		import std.stdio : writeln;
        r = true;
		
		//get frame duration
		frameTime_1 = frameTime;
		frameTime = MonoTimeImpl!(ClockType.normal).currTime();
		delta_frameTime = frameTime - frameTime_1;
		const real delta_frameTime0 = cast(real)(delta_frameTime.total!"usecs"());
		framesPerSecond = 1 / (delta_frameTime0 / 1_000_000);
		if(avgFPS)
			avgFPS = (avgFPS + framesPerSecond) / 2;
		else
			avgFPS = framesPerSecond;

		updatedBuffer++;
		if(updatedBuffer >= nOfBuffers) updatedBuffer = 0;

		SDL_LockTexture(frameBuffer[updatedBuffer], null, &fbData, &fbPitch);

		/+for(int i ; i < layerPriorityHandler.length ; i++){
			layerList[i].updateRaster(fbData, fbPitch, palette.ptr);
		}+/
		foreach (Layer layer ; layerMap) {
			layer.updateRaster(fbData, fbPitch, palette.ptr);
		}

		SDL_UnlockTexture(frameBuffer[updatedBuffer]);
        r = false;

        foreach(r; rL){
            r.refreshFinished;
        }
		
    }


    ///Returns the workpad.
    public SDL_Texture* getOutput() @nogc @safe pure nothrow {
		if (displayedBuffer == updatedBuffer) displayedBuffer++;
		if (displayedBuffer >= nOfBuffers) displayedBuffer = 0;
		return frameBuffer[displayedBuffer++];
		//return frameBuffer[0];
    }


    ///Returns if the raster is refreshing.
    public bool isRefreshing(){
        return r;
    }
}
