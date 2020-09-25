module windows.rasterwindow;

/*
 * rasterWindow.d
 *
 * Outputs layers to a window with the capability of temporarily removing them
 */
import PixelPerfectEngine.concrete.window;
import PixelPerfectEngine.graphics.layers;
import PixelPerfectEngine.graphics.raster : PaletteContainer;
import CPUblit.composing;
import CPUblit.draw;
import CPUblit.colorlookup;
import PixelPerfectEngine.system.inputHandler : MouseButton, ButtonState;

import document;
debug import std.stdio;

/**
 * Implements a subraster using a window. Has the capability of skipping over individual layers.
 */
public class RasterWindow : Window, PaletteContainer {
	protected Bitmap32Bit trueOutput, rasterOutput;
	protected Color[] paletteLocal;
	protected Color* paletteShared;
	//protected Layer[int] layers;
	protected int[] layerList;
	protected int rasterX, rasterY;
	protected dstring documentName;
	protected MapDocument document;
	protected bool _closeProtect;
	/**
	 * Creates a new RasterWindow.
	 */
	public this(int x, int y, Color* paletteShared, dstring documentName, MapDocument document){
		rasterX = x;
		rasterY = y;
		trueOutput = new Bitmap32Bit(x + 2,y + 18);
		rasterOutput = new Bitmap32Bit(x + 2, y + 18);
		super(Coordinate(0, 0, x + 2, y + 18), documentName, ["paletteButtonA", "settingsButtonA", "rightArrowA",
				"leftArrowA", "downArrowA", "upArrowA",]);
		this.paletteShared = paletteShared;
		this.documentName = documentName;
		this.document = document;
		_closeProtect = true;
	}
	/**
	 * Overrides the original getOutput function to return a 32 bit bitmap instead.
	 */
	public override @property ABitmap getOutput(){
		return trueOutput;
	}
	/**
	 * Returns the palette of the object.
	 */
	public @property Color[] palette() @safe pure nothrow @nogc {
		return paletteLocal;
	}
	///Returns the given palette index.
	public Color getPaletteIndex(ushort index) @safe pure nothrow @nogc const {
		return paletteLocal[index];
	}
	///Sets the given palette index to the given value.
	public Color setPaletteIndex(ushort index, Color value) @safe pure nothrow @nogc {
		return paletteLocal[index] = value;
	}
	/**
	 * Adds a palette chunk to the end of the main palette.
	 */
	public Color[] addPaletteChunk(Color[] paletteChunk) @safe {
		return paletteLocal ~= paletteChunk;
	}
	/**
	 * Loads a palette into the object.
	 * Returns the new palette of the object.
	 */
	public Color[] loadPalette(Color[] palette) @safe {
		return paletteLocal = palette;
	}
	/**
	 * Loads a palette chunk into the object.
	 * The offset determines where the palette should be loaded.
	 * If it points to an existing place, the indices after that will be overwritten until the whole palette will be copied.
	 * If it points to the end or after it, then the palette will be made longer, and will pad with values #00000000 if needed.
	 * Returns the new palette of the object.
	 */
	public Color[] loadPaletteChunk(Color[] paletteChunk, ushort offset) @safe {
		if (paletteLocal.length < offset + paletteChunk.length) {
			paletteLocal.length = paletteLocal.length + (offset - paletteLocal.length) + paletteChunk.length;
		}
		assert(paletteLocal.length >= offset + paletteChunk.length, "Palette error!");
		for (int i ; i < paletteChunk.length ; i++) {
			paletteLocal[i + offset] = paletteChunk[i];
		}
		return paletteLocal;
	}
	/**
	 * Clears an area of the palette with zeroes.
	 * Returns the original area.
	 */
	public Color[] clearPaletteChunk(ushort lenght, ushort offset) @safe {
		Color[] backup = paletteLocal[offset..offset + lenght].dup;
		for (int i = offset ; i < offset + lenght ; i++) {
			paletteLocal[i] = Color(0);
		}
		return backup;
	}
	public override void passMouseEvent(int x, int y, int state, ubyte button) {
		StyleSheet ss = getStyleSheet;
		if(y >= ss.drawParameters["WindowHeaderHeight"] && y < trueOutput.height - 1 && x > 0 && x < trueOutput.width - 1) {
			y -= ss.drawParameters["WindowHeaderHeight"];
			x--;
			document.passMouseEvent(x, y, state, button);
		}else
			super.passMouseEvent(x, y, state, button);
	}
	public override void draw(bool drawHeaderOnly = false){
		if(output.output.width != position.width || output.output.height != position.height){
			output = new BitmapDrawer(position.width(), position.height());
			trueOutput = new Bitmap32Bit(position.width(), position.height());
			rasterOutput = new Bitmap32Bit(position.width() - 2, position.height() - 18);
		}

		drawHeader();
		for(int y ; y < 16 ; y++){	//copy 8 bit bitmap with color lookup
			colorLookup(output.output.getPtr + (y * position.width), trueOutput.getPtr + (y * position.width), paletteShared,
					position.width);
		}
		updateRaster();
		/*if(drawHeaderOnly)
			return;*/
		//draw the borders. we do not need fills or drawing elements
		uint* ptr = cast(uint*)trueOutput.getPtr;
		StyleSheet ss = getStyleSheet;
		drawLine!uint(0, 16, 0, position.height - 1, paletteShared[ss.getColor("windowascent")].base, ptr, trueOutput.width);
		drawLine!uint(0, 16, position.width - 1, 16, paletteShared[ss.getColor("windowascent")].base, ptr, trueOutput.width);
		drawLine!uint(position.width - 1, 16, position.width - 1, position.height - 1,
				paletteShared[ss.getColor("windowdescent")].base, ptr, trueOutput.width);
		drawLine!uint(0, position.height - 1, position.width - 1, position.height - 1,
				paletteShared[ss.getColor("windowdescent")].base, ptr, trueOutput.width);
	}
	/**
	 * Updates the raster of the window.
	 */
	public void updateRaster() {
		//clear raster screen
		for (int y = 16 ; y < trueOutput.height - 1 ; y++) {
			for (int x = 1 ; x < trueOutput.width - 1 ; x++) {
				trueOutput.writePixel (x, y, Color(0,0,0,0));
			}
		}
		//debug writeln(paletteLocal);
		//update each layer individually
		for(int i ; i < layerList.length ; i++){
			//document.mainDoc[layerList[i]].updateRaster(rasterOutput.getPtr, rasterX * 4, paletteLocal.ptr);
			document.mainDoc[layerList[i]].updateRaster((trueOutput.getPtr + (17 * trueOutput.width) + 1), trueOutput.width * 4,
					paletteLocal.ptr);
		}
		for (int i = 16 ; i < trueOutput.height - 1 ; i++) {
			helperFunc(trueOutput.getPtr + 1 + trueOutput.width * i, trueOutput.width - 2);
		}
	}
	/**
	 * Adds a new layer then reorders the display list.
	 */
	public void addLayer(int p) {
		import std.algorithm.sorting : sort;
		layerList ~= p;
		layerList.sort();
	}
	/**
	 * Removes a layer then reorders the display list.
	 */
	public void removeLayer(int p) {
		import std.algorithm.mutation : remove;
		for (int i ; i < layerList.length ; i++) {
			if (layerList[i] == p) {
				layerList.remove(i);
				return;
			}
		}
	}
	/**
	 * Copies and sets all alpha values to 255 to avoid transparency issues
	 */
	protected @nogc void helperFunc(void* src, size_t length) pure{
		import PixelPerfectEngine.system.platform;
		static if(USE_INTEL_INTRINSICS){
			import inteli.emmintrin;
			immutable ubyte[16] ALPHA_255_VEC = [255,0,0,0,255,0,0,0,255,0,0,0,255,0,0,0];
			while(length > 4){
				_mm_storeu_si128(cast(__m128i*)src, _mm_loadu_si128(cast(__m128i*)src) |
						_mm_loadu_si128(cast(__m128i*)(cast(void*)ALPHA_255_VEC.ptr)));
				src += 16;
				//dest += 16;
				length -= 4;
			}
			while(length){
				*cast(uint*)src = *cast(uint*)src | 0xFF_00_00_00;
				src += 4;
				//dest += 4;
				length--;
			}
		}else{
			while(length){
				*cast(uint*)src = *cast(uint*)src | 0xFF_00_00_00;
				src += 4;
				dest += 4;
				length--;
			}
		}
	}
	/**
	 * Overrides the original onExit function for safe close.
	 */
	public override void close() {
		if (_closeProtect) {

		} else {
			super.close;
		}
	}
	/**
	 * Implements the scroll buttons and the palette edit button.
	 */
	public override void extraButtonEvent (int num, ubyte button, int state) {
		if (state == ButtonState.RELEASED) {
			document.setContScroll(0,0);
		} else {
			switch (num) {
				case 6:
					break;
				case 5:
					break;
				case 2:
					document.setContScroll(1,0);
					break;
				case 3:
					document.setContScroll(-1,0);
					break;
				case 0:
					document.setContScroll(0,1);
					break;
				case 1:
					document.setContScroll(0,-1);
					break;
				default:
					break;
			}
		}
	}
	
	

	

	public void loadLayers () {
		foreach (key; document.mainDoc.layeroutput.byKey) {
			document.mainDoc.layeroutput[key].setRasterizer(rasterX, rasterY);
			addLayer(key);
		}
	}
}
