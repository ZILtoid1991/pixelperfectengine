/*
 * Copyright (C) 2015-2017, by Laszlo Szeremi under the Boost license.
 *
 * Pixel Perfect Engine, graphics.bitmap module
 */
module pixelperfectengine.graphics.raster;

import pixelperfectengine.graphics.outputscreen;
import pixelperfectengine.graphics.layers;
import pixelperfectengine.graphics.bitmap;
//import bindbc.sdl;
import bindbc.opengl.gl;
import bindbc.opengl;
public import pixelperfectengine.graphics.common;
import std.conv;
import std.algorithm.sorting;
import std.algorithm.mutation;
import core.time;
import collections.treemap;
import iota.window.oswindow;
import iota.window.types;

///The raster calls it every time it finishes the drawing to the framebuffers.
///Used to signal the output screen to switch out the framebuffers.
public interface RefreshListener {
    public void refreshFinished();
}

///Used to read the output from the raster and show it on the screen.
/* public interface IRaster{
    public SDL_Texture* getOutput();
} */
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
	 * The `offset` determines where the palette should be loaded.
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
public class Raster : PaletteContainer {
	float[] verticles = [
		// positions		// texture coords
		1.0f, -1.0f, 0.0f,	1.0f, 0.0f,	// bottom right
		1.0f, 1.0f, 0.0f,	1.0f, 1.0f,	// top right
		-1.0f, -1.0f, 0.0f,	0.0f, 0.0f,	// bottom left
		-1.0f, 1.0f, 0.0f,	0.0f, 1.0f,	// top left
	];
	
    private ushort rasterWidth, rasterHeight;///Stores virtual screen resolution.
    public Bitmap32Bit[] cpu_FrameBuffer;///Framebuffers for CPU rendering
	//public void* 		fbData;			///Data of the currently selected framebuffer
	//public int			fbPitch;		///Pitch of the currently selected framebuffer
	public GLuint[] 	gl_FrameBuffer;	///Framebuffers for OpenGL rendering
	public GLuint		gl_VertexArray;	///
	/**
	 * Color format is ARGB, with each index having their own transparency.
	 */
    protected Color[] _palette;
	alias LayerMap = TreeMap!(int, Layer);
	public LayerMap layerMap;		///Stores the layers by their priorities.
	public LayerMap hiresOverlays;	///High resolution overlays for those who need it.
	protected OSWindow oW;
    //private Layer[int] layerList;	
    private bool r;					///Set to true if refresh is happening.
	protected ubyte nOfBuffers;		///Number of framebuffers, 2 for double buffering.
	protected ubyte updatedBuffer;	///Framebuffer currently being updated
	protected ubyte displayedBuffer;///Framebuffer currently being displayed
	//private int[2] doubleBufferRegisters;
    private RefreshListener[] rL;				///Contains RefreshListeners associated with this raster.
	private MonoTime frameTime, frameTime_1;	///Timestamps of frame occurences
	public Duration delta_frameTime;			///Current time delta between two frames
	private double framesPerSecond, avgFPS;		///Current and average fps counter
	//public Bitmap16Bit[2] frameBuffer;
	/** 
	 * Creates a raster output with the supplied parameters.
	 * Params:
	 *   w = Raster width.
	 *   h = Raster height.
	 *   oW = The OS window for the target.
	 *   paletteLength = Palette size, should be 65_536.
	 *   buffers = Number of buffers, 2 recommended for double buffering, 1 recommended for GUI apps 
	 * especially if they're not constantly updating.
	 */
    public this (ushort w, ushort h, OSWindow oW, size_t paletteLength = 65_536, ubyte buffers = 2) {
		assert(paletteLength <= 65_536);
		_palette.length = paletteLength;
        rasterWidth=w;
        rasterHeight=h;
		nOfBuffers = buffers;
		glTexParameteri(GL_TEXTURE_2D, GL_TEXTURE_MIN_FILTER, GL_LINEAR);
		glTexParameteri(GL_TEXTURE_2D, GL_TEXTURE_MAG_FILTER, GL_NEAREST);
		for (int i ; i < buffers ; i++) {
			cpu_FrameBuffer ~= new Bitmap32Bit(w, h);
			GLuint texture;
			glGenTextures(1, &texture);
			glBindTexture(GL_TEXTURE_2D, texture);
			glTexImage2D(GL_TEXTURE_2D, 0, GL_BGRA, rasterWidth, rasterHeight, 0, GL_BGRA, GL_UNSIGNED_BYTE, 
					cpu_FrameBuffer[i].getPtr);
			gl_FrameBuffer ~= texture;
		}
		glGenVertexArrays(1, &gl_VertexArray);
		frameTime = MonoTimeImpl!(ClockType.normal).currTime();
		framesPerSecond = 0.0;
		avgFPS = 0.0;
		this.oW = oW;
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
		if (paletteChunk.length + offset > _palette.length) 
			_palette.length = offset + paletteChunk.length;
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
	public @property double fps() @safe @nogc pure nothrow const {
		return framesPerSecond;
	}
	/**
	 * Returns the current average FPS count.
	 */
	public @property double avgfps() @safe @nogc pure nothrow const {
		return avgFPS;
	}
	/**
	 * Resets the avgFPS to zero.
	 */
	public void resetAvgfps() @safe @nogc pure nothrow {
		avgFPS = 0;
	}
	~this(){
		
	}
    ///Adds a RefreshListener to its list.
    public void addRefreshListener(RefreshListener r){
        rL ~= r;
    }
	///Sets the number of colors.
	public void setupPalette(int i) {
		_palette.length = i;
	}
    ///Adds a layer at the given priority.
    public void addLayer(Layer l, int i) @safe pure nothrow {
		l.setRasterizer(rasterWidth, rasterHeight);
		layerMap[i] = l;
    }
	public void loadLayers(R)(R layerRange) @safe pure nothrow {
		foreach (int key, Layer value; layerRange) {
			addLayer(value, key);
		}
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
    public void refresh() @system {
		import std.stdio : writeln;
        r = true;
		
		//get frame duration
		frameTime_1 = frameTime;
		frameTime = MonoTimeImpl!(ClockType.normal).currTime();
		delta_frameTime = frameTime - frameTime_1;
		const real delta_frameTime0 = cast(real)(delta_frameTime.total!"usecs"());
		framesPerSecond = 1 / (delta_frameTime0 / 1_000_000);
		if(avgFPS) avgFPS = (avgFPS + framesPerSecond) / 2;
		else avgFPS = framesPerSecond;

		updatedBuffer++;
		if(updatedBuffer >= nOfBuffers) updatedBuffer = 0;

		foreach (Layer layer ; layerMap) {
			layer.updateRaster
					(cpu_FrameBuffer[updatedBuffer].getPtr, cast(int)cpu_FrameBuffer[updatedBuffer].width, _palette.ptr);
		}
		glClear(GL_COLOR_BUFFER_BIT | GL_DEPTH_BUFFER_BIT | GL_STENCIL_BUFFER_BIT);
		glBindTexture(GL_TEXTURE_2D, gl_FrameBuffer[updatedBuffer]);
		glActiveTexture(GL_TEXTURE0);
		glTexImage2D(GL_TEXTURE_2D, 0, GL_BGRA, rasterWidth, rasterHeight, 0, GL_BGRA, GL_UNSIGNED_BYTE, 
				cpu_FrameBuffer[updatedBuffer].getPtr);
		glBindVertexArray(gl_VertexArray);
		glVertexAttribPointer(0, 4, GL_FLOAT, GL_FALSE, 5 * float.sizeof, verticles.ptr);
		glEnableVertexAttribArray(0);
		glDrawArrays(GL_TRIANGLES, 0, 3);
		glDrawArrays(GL_TRIANGLES, 1, 3);
		glDisableVertexAttribArray(0);
		oW.gl_swapBuffers();

        r = false;

        foreach(r; rL){
            r.refreshFinished;
        }
		
    }

/* 
    ///Returns the workpad.
    public SDL_Texture* getOutput() @nogc @safe pure nothrow {
		if (displayedBuffer == updatedBuffer) displayedBuffer++;
		if (displayedBuffer >= nOfBuffers) displayedBuffer = 0;
		return frameBuffer[displayedBuffer++];
		//return frameBuffer[0];
    } */


    ///Returns if the raster is refreshing.
    public bool isRefreshing(){
        return r;
    }
}
