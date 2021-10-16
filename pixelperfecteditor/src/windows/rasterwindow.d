module windows.rasterwindow;

/*
 * rasterWindow.d
 *
 * Outputs layers to a window with the capability of temporarily removing them
 */
import pixelperfectengine.concrete.window;
import pixelperfectengine.graphics.layers;
import pixelperfectengine.graphics.raster : PaletteContainer;
import CPUblit.composing;
static import CPUblit.draw;
import CPUblit.colorlookup;
import pixelperfectengine.system.input.types : MouseButton, ButtonState;
import collections.sortedlist;

import document;
debug import std.stdio;

/**
 * Implements a subraster using a window. Has the capability of skipping over individual layers.
 */
public class RasterWindow : Window, PaletteContainer {
	alias DisplayList = SortedList!(int, "a < b", false);
	public DisplayList	hiddenLayers;	///List of hidden layers
	public DisplayList	soloedLayers;	///List of soloed layers
	protected Bitmap32Bit trueOutput, rasterOutput;
	protected Color[] paletteLocal;
	protected Color* paletteShared;
	public Color		selColor;		///Selection invert color (red by default)
	public Color		selArmColor;	///Selection armed color (blue by default)
	protected uint statusFlags;
	protected static enum MOVE_ARMED = 1 << 0; 		///Redirect mouse events to document
	protected static enum CLOSE_PROTECT = 1 << 1;
	protected static enum SELECTION_ARMED = 1 << 2;	///Selection is armed, draw box, and redirect event to document
	protected static enum SHOW_SELECTION = 1 << 3;	///Shows selection
	//protected int[] layerList;
	public int rasterX, rasterY;		///Raster sizes
	protected dstring documentName;
	protected MapDocument document;
	///The selection area on the screen. Converted from the parent document's own absolute values
	public Box selection;
	protected RadioButtonGroup modeSel;
	/**
	 * Creates a new RasterWindow.
	 */
	public this(int x, int y, Color* paletteShared, dstring documentName, MapDocument document){
		rasterX = x;
		rasterY = y;
		trueOutput = new Bitmap32Bit(x + 2,y + 18);
		rasterOutput = new Bitmap32Bit(x + 2, y + 18);
		ISmallButton[] smallButtons;
		const int windowHeaderHeight = getStyleSheet.drawParameters["WindowHeaderHeight"] - 1;
		modeSel = new RadioButtonGroup();
		smallButtons ~= closeButton();
		smallButtons ~= new SmallButton("settingsButtonB", "settingsButtonA", "settings", Box(0, 0, windowHeaderHeight, 
				windowHeaderHeight));
		smallButtons ~= new SmallButton("paletteButtonB", "paletteButtonA", "palette", Box(0, 0, windowHeaderHeight, 
				windowHeaderHeight));
		smallButtons ~= new RadioButton("selMoveButtonB", "selMoveButtonA", "selMove", 
				Box(0, 0, windowHeaderHeight, windowHeaderHeight), modeSel);
		smallButtons ~= new RadioButton("tilePlacementButtonB", "tilePlacementButtonA", "tile", 
				Box(0, 0, windowHeaderHeight, windowHeaderHeight), modeSel);
		smallButtons ~= new RadioButton("objPlacementButtonB", "objPlacementButtonA", "obj", 
				Box(0, 0, windowHeaderHeight, windowHeaderHeight), modeSel);
		smallButtons ~= new RadioButton("sprtPlacementButtonB", "sprtPlacementButtonA", "sprt", 
				Box(0, 0, windowHeaderHeight, windowHeaderHeight), modeSel);
		modeSel.onToggle = &onModeToggle;

		//smallButtons ~= new SmallButton("settingsButtonB", "settingsButtonA", "settings", Box(0, 0, 16, 16));
		super(Box(0, 0, x + 1, y + 17), documentName, smallButtons);
		foreach (ISmallButton key; smallButtons) {
			WindowElement we = cast(WindowElement)key;
			we.onDraw = &clrLookup;
		}
		this.paletteShared = paletteShared;
		this.documentName = documentName;
		this.document = document;
		statusFlags |= CLOSE_PROTECT;
		modeSel.latchPos(0);
		selColor = Color(0xff,0x00,0x00,0x00);
		selArmColor = Color(0x00,0x00,0xff,0x00);
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
	//public override void passMouseEvent(int x, int y, int state, ubyte button) {
	///Passes mouse click event
	public override void passMCE(MouseEventCommons mec, MouseClickEvent mce) {
		StyleSheet ss = getStyleSheet;
		if (mce.y >= position.top + ss.drawParameters["WindowHeaderHeight"] && mce.y < position.bottom &&
				mce.x > position.left && mce.x < position.right) {
			mce.y -= ss.drawParameters["WindowHeaderHeight"] + position.top;
			mce.x -= position.left - 1;
			document.passMCE(mec, mce);
		} else {
			super.passMCE(mec, mce);
		}
	}
	///Passes mouse move event
	public override void passMME(MouseEventCommons mec, MouseMotionEvent mme) {
		StyleSheet ss = getStyleSheet;
		if (statusFlags & (MOVE_ARMED | SELECTION_ARMED) && /+mme.buttonState == (1<<MouseButton.Mid) &&+/ 
				mme.y >= position.top + ss.drawParameters["WindowHeaderHeight"] && mme.y < position.bottom &&
				mme.x > position.left && mme.x < position.right) {
			mme.y -= ss.drawParameters["WindowHeaderHeight"] + position.top;
			mme.x -= position.left - 1;
			document.passMME(mec, mme);
			
		} else {
			super.passMME(mec, mme);
		}
	}
	/**
	 * Copy 8 bit bitmap with color lookup.
	 */
	protected void clrLookup() {
		for(int y ; y < 16 ; y++){	//
			colorLookup(output.output.getPtr + (y * position.width), trueOutput.getPtr + (y * position.width), paletteShared,
					position.width);
		}
	}
	public override void draw(bool drawHeaderOnly = false){
		if(output.output.width != position.width || output.output.height != position.height){
			output = new BitmapDrawer(position.width(), position.height());
			trueOutput = new Bitmap32Bit(position.width(), position.height());
			rasterOutput = new Bitmap32Bit(position.width() - 2, position.height() - 18);
		}

		drawHeader();
		clrLookup();
		updateRaster();
		if (statusFlags & SELECTION_ARMED) {
			
		}
		/*if(drawHeaderOnly)
			return;*/
		//draw the borders. we do not need fills or drawing elements
		uint* ptr = cast(uint*)trueOutput.getPtr;
		StyleSheet ss = getStyleSheet;
		CPUblit.draw.drawLine!uint(0, 16, 0, position.height - 1, paletteShared[ss.getColor("windowascent")].base, ptr, 
				trueOutput.width);
		CPUblit.draw.drawLine!uint(0, 16, position.width - 1, 16, paletteShared[ss.getColor("windowascent")].base, ptr, 
				trueOutput.width);
		CPUblit.draw.drawLine!uint(position.width - 1, 16, position.width - 1, position.height - 1,
				paletteShared[ss.getColor("windowdescent")].base, ptr, trueOutput.width);
		CPUblit.draw.drawLine!uint(0, position.height - 1, position.width - 1, position.height - 1,
				paletteShared[ss.getColor("windowdescent")].base, ptr, trueOutput.width);
	}
	/**
	 * Clears both displaylists.
	 */
	public void clearDisplayLists() {
		hiddenLayers = DisplayList([]);
		soloedLayers = DisplayList([]);
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
		//update each layer individually
		foreach (int i, Layer l ; document.mainDoc.layeroutput) {
			if ((i !in hiddenLayers && !soloedLayers.length) || (i in soloedLayers && soloedLayers.length))
				l.updateRaster((trueOutput.getPtr + (17 * trueOutput.width) + 1), trueOutput.width * 4, paletteLocal.ptr);
		}
		/+for(int i ; i < layerList.length ; i++){
			//document.mainDoc[layerList[i]].updateRaster(rasterOutput.getPtr, rasterX * 4, paletteLocal.ptr);
			document.mainDoc[layerList[i]].updateRaster((trueOutput.getPtr + (17 * trueOutput.width) + 1), trueOutput.width * 4,
					paletteLocal.ptr);
		}+/
		for (int i = 16 ; i < trueOutput.height - 1 ; i++) {
			helperFunc(trueOutput.getPtr + 1 + trueOutput.width * i, trueOutput.width - 2);
		}
		import CPUblit.composing.specblt : xorBlitter;
		uint* p = cast(uint*)trueOutput.getPtr;
		if (statusFlags & SELECTION_ARMED) {
			for (int y = selection.top + 16 ; y <= selection.bottom + 16 ; y++) {
				xorBlitter!uint(p + 1 + trueOutput.width * y + selection.left, selection.width, selArmColor.base);
			}
		} else if (statusFlags & SHOW_SELECTION) {
			for (int y = selection.top + 16 ; y <= selection.bottom + 16 ; y++) {
				xorBlitter!uint(p + 1 + trueOutput.width * y + selection.left, selection.width, selColor.base);
			}
		}
	}
	/+/**
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
	}+/
	/**
	 * Copies and sets all alpha values to 255 to avoid transparency issues
	 */
	protected @nogc void helperFunc(void* src, size_t length) pure nothrow {
		import pixelperfectengine.system.platform;
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
				*cast(uint*)src = *cast(uint*)src | 0x00_00_00_FF;
				src += 4;
				//dest += 4;
				length--;
			}
		}else{
			while(length){
				*cast(uint*)src = *cast(uint*)src | 0x00_00_00_FF;
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
		if (statusFlags & CLOSE_PROTECT) {

		} else {
			super.close;
		}
	}
	
	///Called when selection needs to be armed.
	public void armSelection() @nogc @safe pure nothrow {
		statusFlags |= SELECTION_ARMED;
	}
	///Called when selection needs to be disarmed.
	public void disarmSelection() @nogc @safe pure nothrow {
		statusFlags &= ~SELECTION_ARMED;
	}
	///Returns true if selection is armed
	public bool isSelectionArmed() const @nogc @safe pure nothrow {
		return statusFlags & SELECTION_ARMED ? true : false;
	}
	///Called when selection needs to be disarmed.
	public bool showSelection(bool val) @nogc @safe pure nothrow {
		if (val) statusFlags |= SHOW_SELECTION;
		else statusFlags &= ~SHOW_SELECTION;
		return statusFlags & SHOW_SELECTION ? true : false;
	}
	///Returns true if selection is displayed
	public bool showSelection() const @nogc @safe pure nothrow {
		return statusFlags & SHOW_SELECTION ? true : false;
	}
	///Enables or disables move
	public bool moveEn(bool val) @nogc @safe pure nothrow {
		if (val) statusFlags |= MOVE_ARMED;
		else statusFlags &= ~MOVE_ARMED;
		return statusFlags & MOVE_ARMED;
	}
	///Called when the document settings window is needed to be opened.
	public void onDocSettings(Event ev) {

	}
	///Called when any of the modes are selected.
	public void onModeToggle(Event ev) {
		switch (modeSel.value) {
			case "tile":
				document.mode = MapDocument.EditMode.tilePlacement;
				break;
			case "obj":
				document.mode = MapDocument.EditMode.boxPlacement;
				break;
			case "sprt":
				document.mode = MapDocument.EditMode.spritePlacement;
				break;
			default:
				document.mode = MapDocument.EditMode.selectDragScroll;
				break;
		}
		document.clearSelection();
	}

	public void loadLayers () {
		foreach (key; document.mainDoc.layeroutput) {
			key.setRasterizer(rasterX, rasterY);
			//addLayer(key);
		}
	}
}
