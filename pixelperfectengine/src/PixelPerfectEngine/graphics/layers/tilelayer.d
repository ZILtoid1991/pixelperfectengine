/*
 * Copyright (C) 2015-2020, by Laszlo Szeremi under the Boost license.
 *
 * Pixel Perfect Engine, graphics.layers.tilelayer module
 */

module pixelperfectengine.graphics.layers.tilelayer;

public import pixelperfectengine.graphics.layers.base;
import collections.treemap;

public class TileLayer : Layer, ITileLayer {
	/**
	 * Implements a single tile to be displayed.
	 * Is ordered in a BinarySearchTree for fast lookup.
	 */
	protected struct DisplayListItem {
		ABitmap tile;			///reference counting only
		void* pixelDataPtr;		///points to the pixeldata
		//Color* palettePtr;		///points to the palette if present
		wchar ID;				///ID, mainly as a padding to 32 bit alignment
		ubyte wordLength;		///to avoid calling the more costly classinfo
		/**
		 * Sets the maximum accessable color amount by the bitmap.
		 * By default, for 4 bit bitmaps, it's 4, and it enables 256 * 16 color palettes.
		 * This limitation is due to the way how the MappingElement struct works.
		 * 8 bit bitmaps can assess the full 256 * 256 palette space.
		 * Lower values can be described to avoid wasting palettes space in cases when the
		 * bitmaps wouldn't use their full capability.
		 */
		ubyte paletteSh;		
		///Default ctor
		this(wchar ID, ABitmap tile, ubyte paletteSh = 0) pure @safe {
			//palettePtr = tile.getPalettePtr();
			//this.paletteSel = paletteSel;
			this.ID = ID;
			this.tile=tile;
			if(typeid(tile) is typeid(Bitmap4Bit)){
				wordLength = 4;
				this.paletteSh = paletteSh ? paletteSh : 4;
				pixelDataPtr = (cast(Bitmap4Bit)(tile)).getPtr;
			}else if(typeid(tile) is typeid(Bitmap8Bit)){
				wordLength = 8;
				this.paletteSh = paletteSh ? paletteSh : 8;
				pixelDataPtr = (cast(Bitmap8Bit)(tile)).getPtr;
			}else if(typeid(tile) is typeid(Bitmap16Bit)){
				wordLength = 16;
				pixelDataPtr = (cast(Bitmap16Bit)(tile)).getPtr;
			}else if(typeid(tile) is typeid(Bitmap32Bit)){
				wordLength = 32;
				pixelDataPtr = (cast(Bitmap32Bit)(tile)).getPtr;
			}else{
				throw new TileFormatException("Bitmap format not supported!");
			}
		}
		string toString() const {
			import std.conv : to;
			string result = to!string(cast(ushort)ID) ~ " ; " ~ to!string(pixelDataPtr) ~ " ; " ~ to!string(wordLength);
			return result;
		}
	}
	protected int			tileX;	///Tile width
	protected int			tileY;	///Tile height
	protected int			mX;		///Map width
	protected int			mY;		///Map height
	protected size_t		totalX;	///Total width of the tilelayer in pixels
	protected size_t		totalY;	///Total height of the tilelayer in pixels
	protected MappingElement[] mapping;///Contains the mapping data
	//private wchar[] mapping;
	//private BitmapAttrib[] tileAttributes;
	protected Color[] 		src;		///Local buffer
	alias DisplayList = TreeMap!(wchar, DisplayListItem, true);
	protected DisplayList displayList;	///displaylist using a BST to allow skipping elements
	/**
	 * Enables the TileLayer to access other parts of the palette if needed.
	 * Does not effect 16 bit bitmaps, but effects all 4 and 8 bit bitmap
	 * within the layer, so use with caution to avoid memory leakages.
	 */
	public ushort			paletteOffset;
	/**
	 * Sets the warp mode of the layer.
	 * Can repeat the whole layer, a single tile, or be turned off completely.
	 */
	public WarpMode			warpMode;
	public ubyte		masterVal;		///Sets the master alpha value for the layer
	///Emulates horizontal blanking interrupt effects, like per-line scrolling.
	///line no -1 indicates that no lines have been drawn yet.
	public @nogc void delegate(int line, ref int sX0, ref int sY0) hBlankInterrupt;
	///Constructor. tX , tY : Set the size of the tiles on the layer.
	this(int tX, int tY, RenderingMode renderMode = RenderingMode.AlphaBlend){
		tileX=tX;
		tileY=tY;
		setRenderingMode(renderMode);
		src.length = tileX;
	}
	///Gets the the ID of the given element from the mapping. x , y : Position.
	public MappingElement readMapping(int x, int y) @nogc @safe pure nothrow const {
		final switch (warpMode) with (WarpMode) {
			case Off:
				if(x < 0 || y < 0 || x >= mX || y >= mY){
					return MappingElement(0xFFFF);
				}
				break;
			case MapRepeat:
				//x *= x > 0 ? 1 : -1;
				x = cast(uint)x % mX;
				//y *= y > 0 ? 1 : -1;
				y = cast(uint)y % mY;
				break;
			case TileRepeat:
				if(x < 0 || y < 0 || x >= mX || y >= mY){
					return MappingElement(0x0000);
				}
				break;
		}
		return mapping[x+(mX*y)];
	}
	///Writes to the map. x , y : Position. w : ID of the tile.
	public void writeMapping(int x, int y, MappingElement w) @nogc @safe pure nothrow {
		if(x >= 0 && y >= 0 && x < mX && y < mY)
			mapping[x+(mX*y)]=w;
	}
	/**
	 * Writes a text to the map.
	 * This function is a bit rudamentary, as it doesn't handle word breaks, and needs per-line writing.
	 * Requires the text to be in 16 bit format
	 */
	public void writeTextToMap(const int x, const int y, const ubyte color, wstring text, 
			BitmapAttrib atrb = BitmapAttrib.init) @nogc @safe pure nothrow {
		for (int i ; i < text.length ; i++) {
			writeMapping(x + i, y, MappingElement(text[i], atrb, color));
		}
	}
	///Writes to the map. x , y : Position. w : ID of the tile.
	/*@nogc public void writeTileAttribute(int x, int y, BitmapAttrib ba){
		tileAttributes[x+(mX*y)]=ba;
	}*/
	///Loads a mapping from an array. x , y : Sizes of the mapping. map : an array representing the elements of the map.
	///x*y=map.length
	public void loadMapping(int x, int y, MappingElement[] mapping) @safe pure {
		assert (x * y == mapping.length);
		mX=x;
		mY=y;
		this.mapping = mapping;
		totalX=mX*tileX;
		totalY=mY*tileY;
	}
	///Adds a tile to the tileSet. t : The tile. id : The ID in wchar to differentiate between different tiles.
	public void addTile(ABitmap tile, wchar id, ubyte paletteSh = 0) {
		if(tile.width==tileX && tile.height==tileY) {
			displayList[id] = DisplayListItem(id, tile, paletteSh);
		}else{
			throw new TileFormatException("Incorrect tile size!", __FILE__, __LINE__, null);
		}
	}
	///Returns a tile from the displaylist
	public ABitmap getTile(wchar id) {
		return displayList[id].tile;
	}
	///Removes the tile with the ID from the set.
	public void removeTile(wchar id) {
		displayList.remove(id);
	}
	///Returns which tile is at the given pixel
	public MappingElement tileByPixel(int x, int y) @nogc @safe pure nothrow const {
		x = cast(uint)x / tileX;
		y = cast(uint)y / tileY;
		return readMapping(x, y);
	}

	public @nogc override void updateRaster(void* workpad, int pitch, Color* palette) {
		import std.stdio : printf;
		int sX0 = sX, sY0 = sY;
		if (hBlankInterrupt !is null)
			hBlankInterrupt(-1, sX0, sY0);

		for (int line  ; line < rasterY ; line++) {
			if (hBlankInterrupt !is null)
				hBlankInterrupt(line, sX0, sY0);
			if ((sY0 >= 0 && sY0 < totalY) || warpMode != WarpMode.Off) {
				int sXlocal = sX0;
				int sYAbs = sY0 & int.max;
				const sizediff_t offsetP = line * pitch;	// The offset of the line that is being written
				void* w0 = workpad + offsetP;
				const int offsetY = sYAbs % tileY;		//Offset of the current line of the tiles in this line
				const int offsetX0 = tileX - ((cast(uint)sXlocal + rasterX) % tileX);		//Scroll offset of the rightmost column
				const int offsetX = (cast(uint)sXlocal % tileX);		//Scroll offset of the leftmost column
				int tileXLength = offsetX ? tileX - offsetX : tileX;
				for (int col ; col < rasterX ; ) {
					//const int sXCurr = col && sX < 0 ? sXlocal - tileXLength : sXlocal;
					const MappingElement currentTile = tileByPixel(sXlocal, sYAbs);
					if (currentTile.tileID != 0xFFFF) {
						const DisplayListItem tileInfo = displayList[currentTile.tileID];
						const int offsetX1 = col ? 0 : offsetX;
						const int offsetY0 = currentTile.attributes.vertMirror ? tileY - offsetY - 1 : offsetY;
						if (col + tileXLength > rasterX) {
							tileXLength -= offsetX0;
						}
						final switch (tileInfo.wordLength) {
							case 4:
								ubyte* tileSrc = cast(ubyte*)tileInfo.pixelDataPtr + (offsetX1 + (offsetY0 * tileX)>>>1);
								main4BitColorLookupFunction(tileSrc, cast(uint*)src, (cast(uint*)palette) + 
										(currentTile.paletteSel<<tileInfo.paletteSh) + paletteOffset, tileXLength, offsetX1 & 1);
								if(currentTile.attributes.horizMirror){//Horizontal mirroring
									flipHorizontal(src);
								}
								mainRenderingFunction(cast(uint*)src,cast(uint*)w0,tileXLength,masterVal);
								break;
							case 8:
								ubyte* tileSrc = cast(ubyte*)tileInfo.pixelDataPtr + offsetX1 + (offsetY0 * tileX);
								main8BitColorLookupFunction(tileSrc, cast(uint*)src, (cast(uint*)palette) + 
										(currentTile.paletteSel<<tileInfo.paletteSh) + paletteOffset, tileXLength);
								if(currentTile.attributes.horizMirror){//Horizontal mirroring
									flipHorizontal(src);
								}
								mainRenderingFunction(cast(uint*)src,cast(uint*)w0,tileXLength,masterVal);
								break;
							case 16:
								ushort* tileSrc = cast(ushort*)tileInfo.pixelDataPtr + offsetX1 + (offsetY0 * tileX);
								mainColorLookupFunction(tileSrc, cast(uint*)src, (cast(uint*)palette), tileXLength);
								if(currentTile.attributes.horizMirror){//Horizontal mirroring
									flipHorizontal(src);
								}
								mainRenderingFunction(cast(uint*)src,cast(uint*)w0,tileXLength,masterVal);
								break;
							case 32:
								Color* tileSrc = cast(Color*)tileInfo.pixelDataPtr + offsetX1 + (offsetY0 * tileX);
								if(!currentTile.attributes.horizMirror) {
									mainRenderingFunction(cast(uint*)tileSrc,cast(uint*)w0,tileXLength,masterVal);
								} else {
									copy(cast(uint*)tileSrc, cast(uint*)src, tileXLength);
									flipHorizontal(src);
									mainRenderingFunction(cast(uint*)src,cast(uint*)w0,tileXLength,masterVal);
								}
								break;

						}

					}
					sXlocal += tileXLength;
					col += tileXLength;
					w0 += tileXLength<<2;

					tileXLength = tileX;
				}
			}
			sY0++;
		}
	}
	public MappingElement[] getMapping() @nogc @safe pure nothrow {
		return mapping;
	}
	public int getTileWidth() @nogc @safe pure nothrow const {
		return tileX;
	}
	public int getTileHeight() @nogc @safe pure nothrow const {
		return tileY;
	}
	public int getMX() @nogc @safe pure nothrow const {
		return mX;
	}
	public int getMY() @nogc @safe pure nothrow const {
		return mY;
	}
	public size_t getTX() @nogc @safe pure nothrow const {
		return totalX;
	}
	public size_t getTY() @nogc @safe pure nothrow const {
		return totalY;
	}
	/// Sets the warp mode.
	/// Returns the new warp mode that is being used.
	public WarpMode setWarpMode(WarpMode mode) @nogc @safe pure nothrow {
		return warpMode = mode;
	}
	/// Returns the currently used warp mode.
	public WarpMode getWarpMode() @nogc @safe pure nothrow const {
		return warpMode;
	}
}