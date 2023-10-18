module pixelperfectengine.graphics.layers.spritelayer;

public import pixelperfectengine.graphics.layers.base;

import collections.treemap;
import collections.sortedlist;
import std.bitmanip : bitfields;
import bitleveld.datatypes;

/**
 * General-purpose sprite controller and renderer.
 */
public class SpriteLayer : Layer, ISpriteLayer {
	/**
	 * Helps to determine the displaying properties and order of sprites.
	 */
	public struct DisplayListItem {
		Box		position;			/// Stores the position relative to the origin point. Actual display position is determined by the scroll positions.
		Box		slice;				/// To compensate for the lack of scanline interrupt capabilities, this enables chopping off parts of a sprite.
		void*	pixelData;			/// Points to the pixel data.
		/**
		 * From version 0.10.0 onwards, each sprites can have their own rendering function set up to
		 * allow different effect on a single layer.
		 * If not specified otherwise, the layer's main rendering function will be used instead.
		 * Custom rendering functions can be written by the user, it requires knowledge of writing
		 * pixel shader-like functions using fixed-point arithmetics. Use of vector optimizatons
		 * techniques (SSE2, AVX, NEON, etc) are needed for optimal performance.
		 */
		@nogc pure nothrow void function(uint* src, uint* dest, size_t length, ubyte value) renderFunc;
		int		width;				/// Width of the sprite
		int		height;				/// Height of the sprite
		int		scaleHoriz;			/// Horizontal scaling
		int		scaleVert;			/// Vertical scaling
		int		priority;			/// Used for automatic sorting and identification.
		/**
		 * Selects the palette of the sprite.
		 * Amount of accessable color depends on the palette access shifting value. A value of 8 enables 
		 * 256 * 256 color palettes, and a value of 4 enables 4096 * 16 color palettes.
		 * `paletteSh` can be set lower than what the bitmap is capable of storing at its maximum, this
		 * can enable the packing of more palettes within the main one, e.g. a `paletteSh` value of 7
		 * means 512 * 128 color palettes, while the bitmaps are still stored in the 8 bit "chunky" mode
		 * instead of 7 bit planar that would require way more processing power. However this doesn't 
		 * limit the bitmap's ability to access 256 colors, and this can result in memory leakage if
		 * the developer isn't careful enough.
		 */
		ushort	paletteSel;
		//ubyte	flags;				/// Flags packed into a single byte (bitmapType, paletteSh)
		mixin(bitfields!(
			ubyte, "paletteSh", 4,
			ubyte, "bmpType", 4,
		));
		ubyte	masterAlpha = ubyte.max;/// Sets the master alpha value of the sprite, e.g. opacity
		/** 
		 * Creates a display list item according to the newer architecture.
		 * Params:
		 *   x = X position of the sprite.
		 *   y = Y position of the sprite.
		 *   sprite = The bitmap to be used as the sprite.
		 *   pri = Priority identifier.
		 *   paletteSel = Selects a given palette.
		 *   paletteSh = Determines how many bits are being used.
		 *   alpha = The transparency of the sprite.
		 *   scaleHoriz = Horizontal scaling of the sprite. 1024 is the base value, anything less will stretch, greater will shrink the sprite.
		 *   scaleVert = Ditto for vertical.
		 */
		this(int x, int y, ABitmap sprite, int priority, ushort paletteSel = 0, ubyte paletteSh = 0, ubyte alpha = ubyte.max, 
				int scaleHoriz = 1024, int scaleVert = 1024) pure @trusted nothrow {
			this.width = sprite.width();
			this.height = sprite.height();
			this.position = Box.bySize(x, y, cast(int)scaleNearestLength(width, scaleHoriz), 
					cast(int)scaleNearestLength(height, scaleVert));
			this.priority = priority;
			this.paletteSel = paletteSel;
			this.scaleVert = scaleVert;
			this.scaleHoriz = scaleHoriz;
			slice = Box(0,0,sprite.width,sprite.height);
			if (typeid(sprite) is typeid(Bitmap2Bit)) {
				bmpType = BitmapTypes.Bmp2Bit;
				this.paletteSh = paletteSh ? paletteSh : 2;
				pixelData = (cast(Bitmap2Bit)(sprite)).getPtr;
			} else if (typeid(sprite) is typeid(Bitmap4Bit)) {
				bmpType = BitmapTypes.Bmp4Bit;
				this.paletteSh = paletteSh ? paletteSh : 4;
				pixelData = (cast(Bitmap4Bit)(sprite)).getPtr;
			} else if (typeid(sprite) is typeid(Bitmap8Bit)) {
				bmpType = BitmapTypes.Bmp8Bit;
				this.paletteSh = paletteSh ? paletteSh : 8;
				pixelData = (cast(Bitmap8Bit)(sprite)).getPtr;
			} else if (typeid(sprite) is typeid(Bitmap16Bit)) {
				bmpType = BitmapTypes.Bmp16Bit;
				pixelData = (cast(Bitmap16Bit)(sprite)).getPtr;
			} else if (typeid(sprite) is typeid(Bitmap32Bit)) {
				bmpType = BitmapTypes.Bmp32Bit;
				pixelData = (cast(Bitmap32Bit)(sprite)).getPtr;
			}
		}
		/**
		 * Resets the slice to its original position.
		 */
		void resetSlice() pure @nogc @safe nothrow {
			slice.left = 0;
			slice.top = 0;
			slice.right = position.width - 1;
			slice.bottom = position.height - 1;
		}
		/**
		 * Replaces the sprite with a new one.
		 * If the sizes are mismatching, the top-left coordinates are left as is, but the slicing is reset.
		 */
		void replaceSprite(ABitmap sprite) @trusted pure nothrow {
			//this.sprite = sprite;
			//palette = sprite.getPalettePtr();
			if(this.width != sprite.width || this.height != sprite.height){
				this.width = sprite.width;
				this.height = sprite.height;
				position.right = position.left + cast(int)scaleNearestLength(width, scaleHoriz);
				position.bottom = position.top + cast(int)scaleNearestLength(height, scaleVert);
				resetSlice();
			}
			if (typeid(sprite) is typeid(Bitmap2Bit)) {
				bmpType = BitmapTypes.Bmp2Bit;
				//paletteSh = 2;
				pixelData = (cast(Bitmap2Bit)(sprite)).getPtr;
			} else if (typeid(sprite) is typeid(Bitmap4Bit)) {
				bmpType = BitmapTypes.Bmp4Bit;
				//paletteSh = 4;
				pixelData = (cast(Bitmap4Bit)(sprite)).getPtr;
			} else if (typeid(sprite) is typeid(Bitmap8Bit)) {
				bmpType = BitmapTypes.Bmp8Bit;
				//paletteSh = 8;
				pixelData = (cast(Bitmap8Bit)(sprite)).getPtr;
			} else if (typeid(sprite) is typeid(Bitmap16Bit)) {
				bmpType = BitmapTypes.Bmp16Bit;
				pixelData = (cast(Bitmap16Bit)(sprite)).getPtr;
			} else if (typeid(sprite) is typeid(Bitmap32Bit)) {
				bmpType = BitmapTypes.Bmp32Bit;
				pixelData = (cast(Bitmap32Bit)(sprite)).getPtr;
			}
		}
		@nogc int opCmp(const DisplayListItem d) const pure @safe nothrow {
			return priority - d.priority;
		}
		@nogc bool opEquals(const DisplayListItem d) const pure @safe nothrow {
			return priority == d.priority;
		}
		@nogc int opCmp(const int pri) const pure @safe nothrow {
			return priority - pri;
		}
		@nogc bool opEquals(const int pri) const pure @safe nothrow {
			return priority == pri;
		}
		
		string toString() const {
			import std.conv : to;
			return "{Position: " ~ position.toString ~ ";\nDisplayed portion: " ~ slice.toString ~";\nPriority: " ~
				to!string(priority) ~ "; PixelData: " ~ to!string(pixelData) ~ 
				"; PaletteSel: " ~ to!string(paletteSel) ~ "; bmpType: " ~ to!string(bmpType) ~ "}";
		}
	}
	//alias DisplayList = TreeMap!(int, DisplayListItem);
	alias DisplayList = SortedList!(DisplayListItem, "a < b", false);
	protected DisplayList		allSprites;			///All sprites of this layer
	//protected OnScreenList		displayedSprites;	///Sprites that are being displayed
	protected Color[2048]		src;				///Local buffer for scaling
	//size_t[8] prevSize;
	///Default ctor
	public this(RenderingMode renderMode = RenderingMode.AlphaBlend) nothrow @safe {
		setRenderingMode(renderMode);
		//Bug workaround: Sometimes when attempting to append an element to a zero-length array, it causes an exception
		//to be thrown, due to access errors. This bug is unstable, and as such hard to debug for (memory leakage issue?)
		//displayedSprites.reserve(128);
		//src[0].length = 1024;
	}
	/**
	 * Checks all sprites for whether they're on screen or not.
	 * Called every time the layer is being scrolled.
	 */
	public void checkAllSprites() @safe nothrow {
		foreach (key; allSprites) {
			checkSprite(key);
		}
	}
	/**
	 * Checks whether a sprite would be displayed on the screen, then updates the display list.
	 * Returns true if it's on screen.
	 */
	public bool checkSprite(int n) @safe nothrow {
		return checkSprite(allSprites[n]);
	}
	///Ditto.
	protected bool checkSprite(DisplayListItem sprt) @safe nothrow {
		//assert(sprt.bmpType != BitmapTypes.Undefined && sprt.pixelData, "DisplayList error!");
		if(sprt.slice.width && sprt.slice.height 
				&& (sprt.position.right > sX && sprt.position.bottom > sY && 
				sprt.position.left < sX + rasterX && sprt.position.top < sY + rasterY)) {
			//displayedSprites.put(sprt.priority);
			return true;
		} else {
			//displayedSprites.removeByElem(sprt.priority);
			return false;
		}
	}
	/**
	 * Searches the DisplayListItem by priority and returns it.
	 * Can be used for external use without any safety issues.
	 */
	public DisplayListItem getDisplayListItem(int n) @nogc pure @trusted nothrow {
		return allSprites[n];
	}
	/*
	 * Searches the DisplayListItem by priority and returns it.
	 * Intended for internal use, as it returns it as a reference value.
	 
	protected final DisplayListItem* getDisplayListItem_internal(int n) @nogc pure @safe nothrow {
		return allSprites.searchByPtr(n);
	}*/
	/+override public void setRasterizer(int rX,int rY) {
		super.setRasterizer(rX,rY);
	}+/
	///Returns the displayed portion of the sprite.
	public Coordinate getSlice(int n) @nogc pure @trusted nothrow {
		return getDisplayListItem(n).slice;
	}
	///Writes the displayed portion of the sprite.
	///Returns the new slice, if invalid (greater than the bitmap, etc.) returns Coordinate.init.
	public Coordinate setSlice(int n, Coordinate slice) @trusted nothrow {
		DisplayListItem* sprt = allSprites.searchByPtr(n);
		if(sprt) {
			sprt.slice = slice;
			checkSprite(*sprt);
			return sprt.slice;
		} else {
			return Coordinate.init;
		}
	}
	///Returns the selected paletteID of the sprite.
	public ushort getPaletteID(int n) @nogc pure @trusted nothrow {
		return allSprites.searchBy(n).paletteSel;
	}
	///Sets the paletteID of the sprite. Returns the new ID, which is truncated to the possible values with a simple binary and operation
	///Palette must exist in the parent Raster, otherwise AccessError might happen during 
	public ushort setPaletteID(int n, ushort paletteID) @nogc pure @trusted nothrow {
		DisplayListItem* item = allSprites.searchByPtr(n);
		if (item is null) return 0;
		return item.paletteSel = paletteID;
	}
	/** 
	 * Returns the sprite rendering function.
	 * Params:
	 *   n = Sprite priority ID.
	 */
	public RenderFunc getSpriteRenderingFunc(int n) @nogc @trusted pure nothrow {
		return allSprites[n].renderFunc;
	}
	/** 
	 * Sets the sprite's rendering function from a predefined ones.
	 * Params:
	 *   n = Sprite priority ID.
	 *   mode = The rendering mode. (init for layer default)
	 * Returns: The new rendering function.
	 */
	public RenderFunc setSpriteRenderingMode(int n, RenderingMode mode) @nogc @trusted pure nothrow {
		DisplayListItem* item = allSprites.searchByPtr(n);
		if (item is null) return null;
		return item.renderFunc = mode == RenderingMode.init ? mainRenderingFunction : getRenderingFunc(mode);
	}
	/** 
	 * Sets the sprite's rendering function. Can be a custom one.
	 * Params:
	 *   n = Sprite priority ID.
	 *   mode = The rendering mode. (init for layer default)
	 * Returns: The new rendering function.
	 */
	public RenderFunc setSpriteRenderingFunc(int n, RenderFunc func) @nogc @trusted pure nothrow {
		DisplayListItem* item = allSprites.searchByPtr(n);
		if (item is null) return null;
		return item.renderFunc = func;
	}
	/** 
	 * Creates a sprite from a bitmap with the given data, then places it to the display list. (New architecture)
	 * Params:
	 *   sprt = The bitmap to be used as the sprite.
	 *   n = Priority ID of the sprite. Both identifies the sprite and decides it's display priority. Larger numbers will be drawn first, 
	 * and thus will appear behind of smaller numbers, which also include negatives.
	 *   x = X position of the sprite (top-left corner).
	 *   y = Y position of the sprite (top-left corner).
	 *   paletteSel = Selects a given palette.
	 *   paletteSh = Determines how many bits are being used, and thus the palette size for selection.
	 *   alpha = The transparency of the sprite.
	 *   scaleHoriz = Horizontal scaling of the sprite. 1024 is the base value, anything less will stretch, greater will shrink the sprite.
	 *   scaleVert = Ditto for vertical.
	 *   renderMode = Determines the rendering mode of the sprite. By default, it's determined by the layer itself. Any of the default 
	 * other methods can be selected here, or a specially written rendering function can be specified with a different function.
	 * Returns: The current area of the sprite.
	 */
	public Box addSprite(ABitmap sprt, int n, int x, int y, ushort paletteSel = 0, ubyte paletteSh = 0, 
			ubyte alpha = ubyte.max, int scaleHoriz = 1024, int scaleVert = 1024, RenderingMode renderMode = RenderingMode.init) 
			@safe nothrow {
		DisplayListItem d = DisplayListItem(x, y, sprt, n, paletteSel, paletteSh, alpha, scaleHoriz, scaleVert);
		if (renderMode == RenderingMode.init)
			d.renderFunc = mainRenderingFunction;
		else
			d.renderFunc = getRenderingFunc(renderMode);
		//synchronized{
		allSprites.put(d);
		//checkSprite(d);
		//}
		return d.position;
	}
	/**
	 * Adds a sprite to the layer.
	 */
	/+public void addSprite(ABitmap s, int n, Box c, ushort paletteSel = 0, int scaleHoriz = 1024, 
				int scaleVert = 1024) @safe nothrow {
		DisplayListItem d = DisplayListItem(c, s, n, paletteSel, scaleHoriz, scaleVert);
		d.renderFunc = mainRenderingFunction;
		synchronized
			allSprites[n] = d;
		checkSprite(d);
	}+/
	///Ditto
	/+public void addSprite(ABitmap s, int n, int x, int y, ushort paletteSel = 0, int scaleHoriz = 1024, 
				int scaleVert = 1024) @safe nothrow {
		DisplayListItem d = DisplayListItem(Box.bySize(x, y, cast(int)scaleNearestLength(s.width, scaleHoriz), 
					cast(int)scaleNearestLength(s.height, scaleVert)), s, n, paletteSel, scaleHoriz, 
				scaleVert);
		d.renderFunc = mainRenderingFunction;
		synchronized
			allSprites[n] = d;
		checkSprite(d);
	}+/
	/**
	 * Replaces the bitmap of the given sprite.
	 */
	public void replaceSprite(ABitmap s, int n) @trusted nothrow {
		DisplayListItem* item = allSprites.searchByPtr(n);
		if (item is null) return;
		item.replaceSprite(s);
	}
	///Ditto with move
	public void replaceSprite(ABitmap s, int n, int x, int y) @trusted nothrow {
		DisplayListItem* item = allSprites.searchByPtr(n);
		if (item is null) return;
		item.replaceSprite(s);
		item.position.move(x, y);
	}
	///Ditto with move
	public void replaceSprite(ABitmap s, int n, Coordinate c) @trusted nothrow {
		DisplayListItem* item = allSprites.searchByPtr(n);
		if (item is null) return;
		item.replaceSprite(s);
		item.position = c;
	}
	/**
	 * Removes a sprite from both displaylists by priority.
	 */
	public void removeSprite(int n) @safe nothrow {
		allSprites.removeBy(n);
	}
	///Clears all sprite from the layer.
	public void clear() @safe nothrow {
		allSprites = DisplayList.init;
	}
	/**
	 * Moves a sprite to the given position.
	 */
	public void moveSprite(int n, int x, int y) @trusted nothrow {
		DisplayListItem* item = allSprites.searchByPtr(n);
		if (item is null) return;
		item.position.move(x, y);
	}
	/**
	 * Moves a sprite by the given amount.
	 */
	public void relMoveSprite(int n, int x, int y) @trusted nothrow {
		DisplayListItem* item = allSprites.searchByPtr(n);
		if (item is null) return;
		item.position.relMove(x, y);
		//checkSprite(*sprt);
	}
	/* ///Sets the rendering function for the sprite (defaults to the layer's rendering function)
	public void setSpriteRenderingMode(int n, RenderingMode mode) @safe nothrow {
		DisplayListItem* item = allSprites.searchByPtr(n);
		if (item is null) return 0;
		item.renderFunc = getRenderingFunc(mode);
	} */
	public @nogc Box getSpriteCoordinate(int n) @trusted nothrow {
		DisplayListItem* sprt = allSprites.searchByPtr(n);
		if(!sprt) return Box.init;
		return sprt.position;
	}
	///Scales sprite horizontally. Returns the new size, or -1 if the scaling value is invalid, or -2 if spriteID not found.
	public int scaleSpriteHoriz(int n, int hScl) @trusted nothrow { 
		DisplayListItem* sprt = allSprites.searchByPtr(n);
		if(!sprt) return -2;
		else if(!hScl) return -1;
		else {
			sprt.scaleHoriz = hScl;
			const int newWidth = cast(int)scaleNearestLength(sprt.width, hScl);
			sprt.slice.right = newWidth;
			sprt.position.right = sprt.position.left + newWidth;
			checkSprite(*sprt);
			return newWidth;
		}
	}
	///Scales sprite vertically. Returns the new size, or -1 if the scaling value is invalid, or -2 if spriteID not found.
	public int scaleSpriteVert(int n, int vScl) @trusted nothrow {
		DisplayListItem* sprt = allSprites.searchByPtr(n);
		if(!sprt) return -2;
		else if(!vScl) return -1;
		else {
			sprt.scaleVert = vScl;
			const int newHeight = cast(int)scaleNearestLength(sprt.height, vScl);
			sprt.slice.bottom = newHeight;
			sprt.position.bottom = sprt.position.top + newHeight;
			checkSprite(*sprt);
			return newHeight;
		}
	}
	///Gets the sprite's current horizontal scale value
	public int getScaleSpriteHoriz(int n) @nogc @trusted nothrow {
		DisplayListItem* item = allSprites.searchByPtr(n);
		if (item is null) return 0;
		return item.scaleHoriz;
	}
	///Gets the sprite's current vertical scale value
	public int getScaleSpriteVert(int n) @nogc @trusted nothrow {
		DisplayListItem* item = allSprites.searchByPtr(n);
		if (item is null) return 0;
		return item.scaleVert;
	}
	public override LayerType getLayerType() @nogc @safe pure nothrow const {
		return LayerType.Sprite;
	}
	public override @nogc void updateRaster(void* workpad, int pitch, Color* palette) {
		/*
		 * BUG 1: If sprite is wider than 2048 pixels, it'll cause issues (mostly memory leaks) due to a hack. (Fixed!)
		 * BUG 2: Obscuring the top part of a sprite when scaleVert is not 1024 will cause glitches. (Fixed!!!)
		 * TO DO: Replace AVL tree with an automatically sorting array with keying abilities.
		 */
		foreach (i ; allSprites) {
			if(!(i.slice.width && i.slice.height 
					&& (i.position.right > sX && i.position.bottom > sY && 
					i.position.left < sX + rasterX && i.position.top < sY + rasterY))) continue;
			const int left = i.position.left + i.slice.left;
			const int top = i.position.top + i.slice.top;
			const int right = i.position.left + i.slice.right;
			const int bottom = i.position.top + i.slice.bottom;
			int offsetXA = sX > left ? sX - left : 0;//Left hand side offset, zero if not obscured
			const int offsetXB = sX + rasterX < right ? right - (sX + rasterX) : 0; //Right hand side offset, zero if not obscured
			const int offsetYA = sY > top ? sY - top : 0;		//top offset of sprite, zero if not obscured
			const int offsetYB = sY + rasterY < bottom ? bottom - (sY + rasterY) + 1 : 1;	//bottom offset of sprite, zero if not obscured
			const int sizeX = i.slice.width();		//total displayed width after slicing
			const int offsetX = left - sX;
			const int length = sizeX - offsetXA - offsetXB - 1; //total displayed width after considering screen borders
			const int offsetY = sY < top ? (top-sY)*pitch : 0;	//used if top portion of the sprite is off-screen
			const int scaleVertAbs = i.scaleVert * (i.scaleVert < 0 ? -1 : 1);	//absolute value of vertical scaling, used in various calculations
			const int scaleHorizAbs = i.scaleHoriz * (i.scaleHoriz < 0 ? -1 : 1);
			const int offsetYA0 = (offsetYA * scaleVertAbs)>>>10;		//amount of skipped lines in the bitmap source
			const int sizeXOffset = i.width * (i.scaleVert < 0 ? -1 : 1);
			int offsetTarget;													//the target fractional lines
			int offset = (offsetYA * scaleVertAbs) & 1023;						//the current amount of fractional lines, also contains the fractional offset bias by defauls
			//const size_t p0offset = (i.scaleHoriz > 0 ? offsetXA : offsetXB); //determines offset based on mirroring
			//const int scalelength = i.position.width < 2048 ? i.width : 2048;	//limit width to 2048, the minimum required for this scaling method to work
			void* dest = workpad + (offsetX + offsetXA)*4 + offsetY;
			final switch (i.bmpType) with (BitmapTypes) {
				case Bmp2Bit:
					ubyte* p0 = cast(ubyte*)i.pixelData + i.width * ((i.scaleVert < 0 ? (i.height - offsetYA0 - 1) : offsetYA0)>>2);
					const size_t _pitch = i.width>>>2;
					for (int y = offsetYA ; y < i.slice.height - offsetYB ; ) {
						/+horizontalScaleNearest4BitAndCLU(p0, src.ptr, palette + (i.paletteSel<<i.paletteSh), scalelength, offsetXA & 1,
								i.scaleHoriz);+/
						horizontalScaleNearestAndCLU(QuadArray(p0[0.._pitch], i.width), src.ptr, palette + (i.paletteSel<<i.paletteSh), 
								length, i.scaleHoriz, offsetXA * scaleHorizAbs);
						offsetTarget += 1024;
						for (; offset < offsetTarget && y < i.slice.height - offsetYB ; offset += scaleVertAbs) {
							y++;
							i.renderFunc(cast(uint*)src.ptr, cast(uint*)dest, length, i.masterAlpha);
							dest += pitch;
						}
						p0 += _pitch;
					}
					break;
				case Bmp4Bit:
					ubyte* p0 = cast(ubyte*)i.pixelData + i.width * ((i.scaleVert < 0 ? (i.height - offsetYA0 - 1) : offsetYA0)>>1);
					const size_t _pitch = i.width>>>1;
					for (int y = offsetYA ; y < i.slice.height - offsetYB ; ) {
						/+horizontalScaleNearest4BitAndCLU(p0, src.ptr, palette + (i.paletteSel<<i.paletteSh), scalelength, offsetXA & 1,
								i.scaleHoriz);+/
						horizontalScaleNearestAndCLU(NibbleArray(p0[0.._pitch], i.width), src.ptr, palette + (i.paletteSel<<i.paletteSh), 
								length, i.scaleHoriz, offsetXA * scaleHorizAbs);
						offsetTarget += 1024;
						for (; offset < offsetTarget && y < i.slice.height - offsetYB ; offset += scaleVertAbs) {
							y++;
							i.renderFunc(cast(uint*)src.ptr, cast(uint*)dest, length, i.masterAlpha);
							dest += pitch;
						}
						p0 += _pitch;
					}
					break;
				case Bmp8Bit:
					ubyte* p0 = cast(ubyte*)i.pixelData + i.width * (i.scaleVert < 0 ? (i.height - offsetYA0 - 1) : offsetYA0);
					for (int y = offsetYA ; y < i.slice.height - offsetYB ; ) {
						//horizontalScaleNearestAndCLU(p0, src.ptr, palette + (i.paletteSel<<i.paletteSh), scalelength, i.scaleHoriz);
						horizontalScaleNearestAndCLU(p0[0..i.width], src.ptr, palette + (i.paletteSel<<i.paletteSh), length, i.scaleHoriz,
								offsetXA * scaleHorizAbs);
						offsetTarget += 1024;
						for (; offset < offsetTarget && y < i.slice.height - offsetYB ; offset += scaleVertAbs) {
							y++;
							i.renderFunc(cast(uint*)src.ptr, cast(uint*)dest, length, i.masterAlpha);
							dest += pitch;
						}
						p0 += sizeXOffset;
					}
					break;
				case Bmp16Bit:
					ushort* p0 = cast(ushort*)i.pixelData + i.width * (i.scaleVert < 0 ? (i.height - offsetYA0 - 1) : offsetYA0);
					for (int y = offsetYA ; y < i.slice.height - offsetYB ; ) {
						//horizontalScaleNearestAndCLU(p0, src.ptr, palette, scalelength, i.scaleHoriz);
						horizontalScaleNearestAndCLU(p0[0..i.width], src.ptr, palette, length, i.scaleHoriz, offsetXA * scaleHorizAbs);
						offsetTarget += 1024;
						for (; offset < offsetTarget && y < i.slice.height - offsetYB ; offset += scaleVertAbs) {
							y++;
							i.renderFunc(cast(uint*)src.ptr, cast(uint*)dest, length, i.masterAlpha);
							dest += pitch;
						}
						p0 += sizeXOffset;
					}
					break;
				case Bmp32Bit:
					Color* p0 = cast(Color*)i.pixelData + i.width * (i.scaleVert < 0 ? (i.height - offsetYA0 - 1) : offsetYA0);
					for (int y = offsetYA ; y < i.slice.height - offsetYB ; ) {
						horizontalScaleNearest(p0[0..i.width], src, length, i.scaleHoriz, offsetXA * scaleHorizAbs);
						offsetTarget += 1024;
						for (; offset < offsetTarget && y < i.slice.height - offsetYB; offset += scaleVertAbs) {
							y++;
							i.renderFunc(cast(uint*)src.ptr, cast(uint*)dest, length, i.masterAlpha);
							dest += pitch;
						}
						p0 += sizeXOffset;
					}
					//}
					break;
				case Undefined, Bmp1Bit, Planar:
					break;
			}

			//}
		}
		//foreach(int threadOffset; threads.parallel)
			//free(src[threadOffset]);
	}
	///Absolute scrolling.
	public override void scroll(int x, int y) @safe nothrow {
		sX = x;
		sY = y;
		//checkAllSprites;
	}
	///Relative scrolling. Positive values scrolls the layer left and up, negative values scrolls the layer down and right.
	public override void relScroll(int x, int y) @safe nothrow {
		sX += x;
		sY += y;
		//checkAllSprites;
	}
}
