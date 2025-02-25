/*
 * Copyright (C) 2015-2017, by Laszlo Szeremi under the Boost license.
 *
 * Pixel Perfect Engine, graphics.bitmap module
 */
module pixelperfectengine.graphics.raster;

import pixelperfectengine.graphics.layers;
import pixelperfectengine.graphics.bitmap;
import pixelperfectengine.system.file : loadShader;
//import bindbc.sdl;
import bindbc.opengl.gl;
import bindbc.opengl;
public import pixelperfectengine.graphics.common;
import pixelperfectengine.system.memory;
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
		// positions        colors            texture coords
		1.0f, -1.0f, 0.0f,	1.0f, 1.0f, 1.0f, 1.0f, 1.0f,	// bottom right
		1.0f, 1.0f, 0.0f,	1.0f, 1.0f, 1.0f, 1.0f, 0.0f,	// top right
		-1.0f, -1.0f, 0.0f,	1.0f, 1.0f, 1.0f, 0.0f, 1.0f,	// bottom left
		-1.0f, 1.0f, 0.0f,	1.0f, 1.0f, 1.0f, 0.0f, 0.0f,	// top left
	];
	uint[] indices = [
		0, 1, 2,
		1, 2, 3,
	];
	
	private ushort rasterWidth, rasterHeight;///Stores virtual screen resolution.
	public Bitmap32Bit[] cpu_FrameBuffer;///Framebuffers for CPU rendering
	//public void* 		fbData;			///Data of the currently selected framebuffer
	//public int			fbPitch;		///Pitch of the currently selected framebuffer
	public GLuint[] 	gl_FrameBufferTexture;	///Framebuffers for OpenGL rendering
	public GLuint[]		gl_DepthBuffer;
	public GLuint[]		gl_FrameBuffer;
	public GLuint[]		gl_Overlays;	///Used for hi-res overlay support
	public GLuint		gl_Palette;		///Palette stored as a 2D texture
	public GLuint		gl_PaletteNM;	///Palette for normal mapping
	public GLuint		gl_VertexBuffer;///Vertex buffer ID
	public GLuint		gl_VertexArray;	///Vertex array ID
	public GLuint		gl_VertexIndices;///Vertex index buffer ID
	public GLuint		gl_Program;		///OpenGL shader program
	/**
	 * Color format is ARGB, with each index having their own transparency.
	 */
	protected Color[] _palette;
	///Normal map format: x ; y
	protected short[] _paletteNM;
	alias LayerMap = TreeMap!(int, Layer);
	public LayerMap layerMap;		///Stores the layers by their priorities.
	public LayerMap hiresOverlays;	///High resolution overlays for those who need it.
	protected OSWindow oW;
	//private Layer[int] layerList;
	private bool r;					///Set to true if refresh is happening.
	protected int nOfBuffers;		///Number of framebuffers, 2 for double buffering.
	protected int updatedBuffer;	///Framebuffer currently being updated
	protected int displayedBuffer;///Framebuffer currently being displayed
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
	 *   paletteLength = Palette size, should be 65_536. (DEPRECATED PARAMETER)
	 *   buffers = Number of buffers, 2 recommended for double buffering, 1 recommended for GUI apps 
	 * especially if they're not constantly updating.
	 */
	public this (ushort w, ushort h, OSWindow oW, size_t paletteLength = 65_536, ubyte buffers = 2) {
		// assert(paletteLength <= 65_536);
		//Shader initialization block
		GLuint gl_VertexShader = glCreateShader(GL_VERTEX_SHADER);
		const(char)[] shaderProgram = loadShader("%SHADERS%/final_%SHDRVER%.vert");
		char* shaderProgramPtr = cast(char*)shaderProgram.ptr;
		glShaderSource(gl_VertexShader, 1, &shaderProgramPtr, null);
		glCompileShader(gl_VertexShader);
		gl_CheckShader(gl_VertexShader);
		GLuint gl_FragmentShader = glCreateShader(GL_FRAGMENT_SHADER);
		shaderProgram = loadShader("%SHADERS%/final_%SHDRVER%.frag");
		shaderProgramPtr = cast(char*)shaderProgram.ptr;
		glShaderSource(gl_FragmentShader, 1, &shaderProgramPtr, null);
		glCompileShader(gl_FragmentShader);
		gl_CheckShader(gl_FragmentShader);
		gl_Program = glCreateProgram();
		glAttachShader(gl_Program, gl_VertexShader);
		glAttachShader(gl_Program, gl_FragmentShader);
		glLinkProgram(gl_Program);
		gl_CheckProgram(gl_Program);
		glDeleteShader(gl_FragmentShader);
		glDeleteShader(gl_VertexShader);

		_palette = nogc_initNewArray!Color(65_536);
		_paletteNM = nogc_initNewArray!short(65_536 * 2);

		glGenTextures(1, &gl_Palette);
		glBindTexture(GL_TEXTURE_2D, gl_Palette);
		glTexImage2D(GL_TEXTURE_2D, 0, GL_RGBA, 256, 256, 0, GL_RGBA, GL_UNSIGNED_INT_8_8_8_8, palette.ptr);

		glGenTextures(1, &gl_PaletteNM);
		glBindTexture(GL_TEXTURE_2D, gl_PaletteNM);
		glTexImage2D(GL_TEXTURE_2D, 0, GL_RG, 256, 256, 0, GL_RG, GL_SHORT, palette.ptr);

		rasterWidth=w;
		rasterHeight=h;
		nOfBuffers = buffers;
		for (int i ; i < buffers ; i++) {
			//cpu_FrameBuffer ~= new Bitmap32Bit(w, h);
			GLuint texture, depthBuffer, frameBuffer;
			glGenFramebuffers(1, &frameBuffer);
			glBindFramebuffer(GL_FRAMEBUFFER, frameBuffer);

			glGenTextures(1, &texture);
			glBindTexture(GL_TEXTURE_2D, texture);
			glTexImage2D(GL_TEXTURE_2D, 0, GL_RGBA, w, h, 0, GL_RGBA, GL_UNSIGNED_INT_8_8_8_8, null);
			glTexParameteri(GL_TEXTURE_2D, GL_TEXTURE_MIN_FILTER, GL_NEAREST);
			glTexParameteri(GL_TEXTURE_2D, GL_TEXTURE_MAG_FILTER, GL_NEAREST);
			glTexParameteri(GL_TEXTURE_2D, GL_TEXTURE_WRAP_S, GL_CLAMP);
			glTexParameteri(GL_TEXTURE_2D, GL_TEXTURE_WRAP_T, GL_CLAMP);

			glGenRenderbuffers(1, &depthBuffer);
			glBindRenderbuffer(GL_RENDERBUFFER, depthBuffer);
			glRenderbufferStorage(GL_RENDERBUFFER, GL_DEPTH_COMPONENT, w, h);
			glFramebufferRenderbuffer(GL_FRAMEBUFFER, GL_DEPTH_ATTACHMENT, GL_RENDERBUFFER, depthBuffer);
			
			gl_FrameBufferTexture.nogc_append(texture);
			gl_DepthBuffer.nogc_append(depthBuffer);
			gl_FrameBuffer.nogc_append(frameBuffer);
		}
		glUseProgram(gl_Program);
		glUniform1i(glGetUniformLocation(gl_Program, "texture1"), 0);
		//glPixelStorei(GL_UNPACK_ALIGNMENT, 1);

		glGenVertexArrays(1, &gl_VertexArray);
		glGenBuffers(1, &gl_VertexBuffer);
		glGenBuffers(1, &gl_VertexIndices);

		glBindVertexArray(gl_VertexArray);

		glBindBuffer(GL_ARRAY_BUFFER, gl_VertexBuffer);
		glBufferData(GL_ARRAY_BUFFER, verticles.length * float.sizeof, verticles.ptr, GL_STATIC_DRAW);

		glBindBuffer(GL_ELEMENT_ARRAY_BUFFER, gl_VertexIndices);
		glBufferData(GL_ELEMENT_ARRAY_BUFFER, indices.length * int.sizeof, indices.ptr, GL_STATIC_DRAW);

		glEnableVertexAttribArray(0);
		glVertexAttribPointer(0, 3, GL_FLOAT, GL_FALSE, cast(int)(8 * float.sizeof), cast(void*)0);
		glEnableVertexAttribArray(1);
		glVertexAttribPointer(1, 3, GL_FLOAT, GL_FALSE, cast(int)(8 * float.sizeof), cast(void*)(3 * float.sizeof));
		glEnableVertexAttribArray(2);
		glVertexAttribPointer(2, 2, GL_FLOAT, GL_FALSE, cast(int)(8 * float.sizeof), cast(void*)(6 * float.sizeof));

		glBindVertexArray(0);

		frameTime = MonoTimeImpl!(ClockType.normal).currTime();
		framesPerSecond = 0.0;
		avgFPS = 0.0;
		this.oW = oW;
		//glDetachShader(gl_Program, gl_FragmentShader);
		//glDetachShader(gl_Program, gl_VertexShader);
		
	}
	~this() {
		glDeleteVertexArrays(1, &gl_VertexArray);
		glDeleteBuffers(1, &gl_VertexArray);
		glDeleteBuffers(1, &gl_VertexIndices);
		glDeleteProgram(gl_Program);
		glDeleteFramebuffers(cast(int)gl_FrameBuffer.length, gl_FrameBuffer.ptr);
		glDeleteTextures(cast(int)gl_FrameBufferTexture.length, gl_FrameBufferTexture.ptr);
		glDeleteRenderbuffers(cast(int)gl_DepthBuffer.length, gl_DepthBuffer.ptr);
		nogc_free(_palette);
		nogc_free(_paletteNM);
		nogc_free(gl_FrameBuffer);
		nogc_free(gl_FrameBufferTexture);
		nogc_free(gl_DepthBuffer);
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
	///Adds a RefreshListener to its list.
	public void addRefreshListener(RefreshListener r){
		rL ~= r;
	}
	///Sets the number of colors.
	public void setupPalette(int i) {
		_palette.length = i;
	}
	public void resizeRaster(ushort width, ushort height) {
		rasterWidth = width;
		rasterHeight = height;
		for (int i ; i < nOfBuffers ; i++) {
			cpu_FrameBuffer[i] = new Bitmap32Bit(rasterWidth, rasterHeight);
			glDeleteTextures(1, &gl_FrameBufferTexture[i]);
			glGenTextures(1, &gl_FrameBufferTexture[i]);
			glBindTexture(GL_TEXTURE_2D, gl_FrameBufferTexture[i]);
			glTexParameteri(GL_TEXTURE_2D, GL_TEXTURE_MIN_FILTER, GL_NEAREST);
			glTexParameteri(GL_TEXTURE_2D, GL_TEXTURE_MAG_FILTER, GL_NEAREST);
			glTexParameteri(GL_TEXTURE_2D, GL_TEXTURE_WRAP_S, GL_CLAMP);
			glTexParameteri(GL_TEXTURE_2D, GL_TEXTURE_WRAP_T, GL_CLAMP);
		}
		foreach (Layer key; layerMap) {
			key.setRasterizer(rasterWidth, rasterHeight);
		}
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
		displayedBuffer = updatedBuffer + 1;
		if(displayedBuffer >= nOfBuffers) displayedBuffer = 0;

		foreach (Layer layer ; layerMap) {
			layer.updateRaster
					(cpu_FrameBuffer[updatedBuffer].getPtr, cast(int)cpu_FrameBuffer[updatedBuffer].width * 4, _palette.ptr);
		}
		glClear(GL_COLOR_BUFFER_BIT | GL_DEPTH_BUFFER_BIT | GL_STENCIL_BUFFER_BIT);

		glBindTexture(GL_TEXTURE_2D, gl_FrameBufferTexture[displayedBuffer]);
		glTexImage2D(GL_TEXTURE_2D, 0, GL_RGBA, rasterWidth, rasterHeight, 0, GL_BGRA, GL_UNSIGNED_INT_8_8_8_8, 
				cpu_FrameBuffer[displayedBuffer].getPtr);

		glActiveTexture(GL_TEXTURE0);
		glBindTexture(GL_TEXTURE_2D, gl_FrameBufferTexture[displayedBuffer]);
		glUseProgram(gl_Program);
		glBindVertexArray(gl_VertexArray);
		glDrawElements(GL_TRIANGLES, 6, GL_UNSIGNED_INT, null);

		oW.gl_swapBuffers();
		r = false;
	}

	public void refresh_GL() @system {
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
		displayedBuffer = updatedBuffer + 1;
		if(displayedBuffer >= nOfBuffers) displayedBuffer = 0;

		foreach (Layer layer ; layerMap) {
			layer.renderToTexture_gl(gl_FrameBuffer[updatedBuffer], gl_Palette, gl_PaletteNM,
					[rasterWidth, rasterHeight, rasterWidth, rasterHeight], [0,0]);
		}
		oW.gl_makeCurrent();
		glClear(GL_COLOR_BUFFER_BIT | GL_DEPTH_BUFFER_BIT | GL_STENCIL_BUFFER_BIT);

		glBindTexture(GL_TEXTURE_2D, gl_FrameBufferTexture[displayedBuffer]);
		glTexImage2D(GL_TEXTURE_2D, 0, GL_RGBA, rasterWidth, rasterHeight, 0, GL_BGRA, GL_UNSIGNED_INT_8_8_8_8,
				cpu_FrameBuffer[displayedBuffer].getPtr);

		glActiveTexture(GL_TEXTURE0);
		glBindTexture(GL_TEXTURE_2D, gl_FrameBufferTexture[displayedBuffer]);
		glUseProgram(gl_Program);
		glBindVertexArray(gl_VertexArray);
		glDrawElements(GL_TRIANGLES, 6, GL_UNSIGNED_INT, null);

		oW.gl_swapBuffers();
		r = false;
	}



    ///Returns if the raster is refreshing.
    public bool isRefreshing(){
        return r;
    }
}
