/*
 * Copyright (C) 2015-2020, by Laszlo Szeremi under the Boost license.
 *
 * Pixel Perfect Engine, graphics.layers.trnstilelayer module
 */

module pixelperfectengine.graphics.layers.trnstilelayer;

public import pixelperfectengine.graphics.layers.base;
import pixelperfectengine.system.etc;
import pixelperfectengine.system.exc;
import collections.treemap;
import inteli.emmintrin;

/**
 * Implements a modified TileLayer with transformability with capabilities similar to MODE7.
 * <br/>
 * Transform function:
 * [x',y'] = ([A,B,C,D] * ([x,y] + [sX,sY] - [x_0,y_0])>>>8 + [x_0,y_0]
 * <br/>
 * All basic transform values are integer based, 256 equals with 1.0
 * <br/>
 * Restrictions compared to standard TileLayer:
 * <ul>
 * <li>Tiles must have any of the following sizes: 8, 16, 32, 64; since this layer needs to do modulo computations for each pixel.</li>
 * <li>In future versions, map sizes for this layer will be restricted to power of two sizes to make things faster</li>
 * <li>Maximum layer size in pixels are restricted to 65536*65536 due to architectural limitations. Accelerated versions might raise
 * this limitation.</li>
 * </ul>
 * HDMA emulation supported through delegate hBlankInterrupt.
 */
public class TransformableTileLayer(BMPType = Bitmap16Bit, int TileX = 8, int TileY = 8) : Layer, ITileLayer{
		/*if(isPowerOf2(TileX) && isPowerOf2(TileY))*/
	protected struct DisplayListItem {
		BMPType	tile;		///For reference counting
		void* 	pixelSrc;	///Used for quicker access to the Data
		wchar 	ID;			///ID, mainly used as a padding and secondary identification
		/**
		 * Sets the maximum accessable color amount by the bitmap.
		 * By default, for 4 bit bitmaps, it's 4, and it enables 256 * 16 color palettes.
		 * This limitation is due to the way how the MappingElement struct works.
		 * 8 bit bitmaps can assess the full 256 * 256 palette space.
		 * Lower values can be described to avoid wasting palettes space in cases when the
		 * bitmaps wouldn't use their full capability.
		 * Not used with 16 bit indexed and 32 bit direct color bitmaps.
		 */
		ubyte	palShift;
		ubyte 	reserved;	///Padding for 32 bit
		this (wchar ID, BMPType tile, ubyte paletteSh = 0) pure @trusted @nogc nothrow {
			void _systemWrapper() pure @system @nogc nothrow {
				pixelSrc = cast(void*)tile.getPtr();
			}
			this.ID = ID;
			this.tile = tile;
			static if (is(BMPType == Bitmap4Bit)) this.palShift = paletteSh ? paletteSh : 4;
			else static if (is(BMPType == Bitmap8Bit)) this.palShift = paletteSh ? paletteSh : 8;
			_systemWrapper;
		}
		string toString() const {
			import std.conv : to;
			string result = to!string(cast(ushort)ID) ~ " ; " ~ to!string(pixelSrc);
			return result;
		}
	}
	alias DisplayList = TreeMap!(wchar, DisplayListItem, true);
	protected DisplayList displayList;
	protected short[4] transformPoints;	/** Defines how the layer is being transformed */
	protected short[2] tpOrigin;		/** Transform point */
	protected Bitmap32Bit backbuffer;	///used to store current screen output
	/*static if(BMPType.mangleof == Bitmap8Bit.mangleof){
		protected ubyte[] src;
		protected Color* palettePtr;	///Shared palette
	}else static if(BMPType.mangleof == Bitmap16Bit.mangleof){
		protected ushort[] src;*/
	static if(is(BMPType == Bitmap4Bit) || is(BMPType == Bitmap8Bit) ||	is(BMPType == Bitmap16Bit)){
		protected ushort[] src;
	}else static if(is(BMPType == Bitmap32Bit)){

	}else static assert(false,"Template parameter " ~ BMPType.mangleof ~ " not supported by TransformableTileLayer!");
	//TO DO: Replace these with a single 32 bit value
	protected bool		needsUpdate;	///Set to true if backbuffer needs an update (might be replaced with flags)
	public WarpMode		warpMode;		///Repeats the whole layer if set to true
	public ubyte		masterVal;		///Sets the master alpha value for the layer
	public ushort		paletteOffset;	///Offsets the palette by the given amount
	protected int mX, mY;				///"Inherited" from TileLayer
	static if(TileX == 8)
		protected immutable int shiftX = 3;
	else static if(TileX == 16)
		protected immutable int shiftX = 4;
	else static if(TileX == 32)
		protected immutable int shiftX = 5;
	else static if(TileX == 64)
		protected immutable int shiftX = 6;
	else static assert(false,"Unsupported horizontal tile size!");
	static if(TileY == 8)
		protected immutable int shiftY = 3;
	else static if(TileY == 16)
		protected immutable int shiftY = 4;
	else static if(TileY == 32)
		protected immutable int shiftY = 5;
	else static if(TileY == 64)
		protected immutable int shiftY = 6;
	else static assert(false,"Unsupported vertical tile size!");
	protected int totalX, totalY;
	protected MappingElement[] mapping;
	
	protected int4 _tileAmpersand;      ///Used for quick modulo by power of two to calculate tile positions.
	protected short8 _increment;
	protected __m128i _mapAmpersand;    ///Used for quick modulo by power of two to read maps
	//protected __m128i _mapShift;		///Used for quick divide by power of two to read maps
	
	alias HBIDelegate = 
			@nogc nothrow void delegate(ref short[4] localABCD, ref short[2] localsXsY, ref short[2] localx0y0, short y);
	/**
	 * Called before each line being redrawn. Can modify global values for each lines.
	 */
	public HBIDelegate hBlankInterrupt;

	this (RenderingMode renderMode = RenderingMode.AlphaBlend) {
		A = 256;
		B = 0;
		C = 0;
		D = 256;
		x_0 = 0;
		y_0 = 0;
		_tileAmpersand = [TileX - 1, TileY - 1, TileX - 1, TileY - 1];
		//_mapShift = [shiftX, shiftY, shiftX, shiftY];
		masterVal = ubyte.max;
		setRenderingMode(renderMode);
		needsUpdate = true;
		//static if (BMPType.mangleof == Bitmap4Bit.mangleof) _paletteOffset = 4;
		//else static if (BMPType.mangleof == Bitmap8Bit.mangleof) _paletteOffset = 8;
		for(int i ; i < 8 ; i+=2)
			_increment[i] = 2;
	}


	
	override public void setRasterizer(int rX,int rY) {
		super.setRasterizer(rX,rY);
		backbuffer = new Bitmap32Bit(rX, rY);
		static if(BMPType.mangleof == Bitmap8Bit.mangleof || BMPType.mangleof == Bitmap16Bit.mangleof){
			src.length = rX;
		}
	}

	override public @nogc void updateRaster(void* workpad,int pitch,Color* palette) {
		//import core.stdc.stdio;
		if(needsUpdate){
			needsUpdate = false;
			//clear buffer
			//backbuffer.clear();
			Color* dest = backbuffer.getPtr();
			short[2] sXsY = [cast(short)sX,cast(short)sY];
			short[4] localTP = transformPoints;
			short[2] localTPO = tpOrigin;
			//write new data into it
			for(short y; y < rasterY; y++){
				if(hBlankInterrupt !is null){
					hBlankInterrupt(localTP, sXsY, localTPO, y);
				}
				short8 _sXsY, _localTP, _localTPO;
				for(int i; i < 8; i++){
					_sXsY[i] = sXsY[i & 1];
					_localTP[i] = localTP[i & 3];
					_localTPO[i] = localTPO[i & 1];
				}
				short8 xy_in;
				for(int i = 1; i < 8; i += 2){
					xy_in[i] = y;
				}
				xy_in[4] = 1;
				xy_in[6] = 1;
				int4 _localTPO_0;
				for(int i; i < 4; i++){
					_localTPO_0[i] = localTPO[i & 1];
				}
				for(short x; x < rasterX; x++){
					int4 xy = _mm_srai_epi32(_mm_madd_epi16(cast(int4)_localTP, cast(int4)(xy_in + _sXsY - _localTPO)),8)
							+ _localTPO_0;
					/+MappingElement currentTile0 = tileByPixelWithoutTransform(xy[0],xy[1]),
							currentTile[1] = tileByPixelWithoutTransform(xy[2],xy[3]);+/
					MappingElement[2] currentTile = tileByPixelWithoutTransform(xy);
					xy &= _tileAmpersand;
					if(currentTile[0].tileID != 0xFFFF){
						const DisplayListItem d = displayList[currentTile[0].tileID];
						static if(is(BMPType == Bitmap4Bit)){
							ubyte* tsrc = cast(ubyte*)d.pixelSrc;
						}else static if(is(BMPType == Bitmap8Bit)){
							ubyte* tsrc = cast(ubyte*)d.pixelSrc;
						}else static if(is(BMPType == Bitmap16Bit)){
							ushort* tsrc = cast(ushort*)d.pixelSrc;
						}else static if(is(BMPType == Bitmap32Bit)){
							Color* tsrc = cast(Color*)d.pixelSrc;
						}
						xy[0] = xy[0] & (TileX - 1);
						xy[1] = xy[1] & (TileY - 1);
						const int totalOffset = xy[0] + xy[1] * TileX;
						static if(BMPType.mangleof == Bitmap4Bit.mangleof){
							src[x] = cast(ushort)((totalOffset & 1 ? tsrc[totalOffset>>1]>>4 : tsrc[totalOffset>>1] & 0x0F) | 
									currentTile[0].paletteSel<<d.palShift);
						}else static if(BMPType.mangleof == Bitmap8Bit.mangleof ){
							src[x] = cast(ushort)(tsrc[totalOffset] | currentTile[0].paletteSel<<d.palShift);
						}else static if(BMPType.mangleof == Bitmap16Bit.mangleof){
							src[x] = tsrc[totalOffset];
						}else{
							*dest = *tsrc;
							dest++;
						}
					}else{
						static if(BMPType.mangleof == Bitmap8Bit.mangleof || BMPType.mangleof == Bitmap16Bit.mangleof ||
								BMPType.mangleof == Bitmap4Bit.mangleof){
							src[x] = 0;
						}else{
							(*dest).raw = 0;
						}
					}
					x++;
					if(currentTile[1].tileID != 0xFFFF){
						const DisplayListItem d = displayList[currentTile[1].tileID];
						static if(is(BMPType == Bitmap4Bit)){
							ubyte* tsrc = cast(ubyte*)d.pixelSrc;
						}else static if(is(BMPType == Bitmap8Bit)){
							ubyte* tsrc = cast(ubyte*)d.pixelSrc;
						}else static if(is(BMPType == Bitmap16Bit)){
							ushort* tsrc = cast(ushort*)d.pixelSrc;
						}else static if(is(BMPType == Bitmap32Bit)){
							Color* tsrc = cast(Color*)d.pixelSrc;
						}
						xy[2] = xy[2] & (TileX - 1);
						xy[3] = xy[3] & (TileY - 1);
						const int totalOffset = xy[2] + xy[3] * TileX;
						static if(BMPType.mangleof == Bitmap4Bit.mangleof){
							src[x] = cast(ushort)((totalOffset & 1 ? tsrc[totalOffset>>1]>>4 : tsrc[totalOffset>>1] & 0x0F) | 
									currentTile[1].paletteSel<<d.palShift);
						} else static if(BMPType.mangleof == Bitmap8Bit.mangleof ) {
							src[x] = cast(ushort)(tsrc[totalOffset] | currentTile[1].paletteSel<<d.palShift);
						} else static if(BMPType.mangleof == Bitmap16Bit.mangleof) {
							src[x] = tsrc[totalOffset];
						} else {
							*dest = *tsrc;
							dest++;
						}
					} else {
						static if(BMPType.mangleof == Bitmap8Bit.mangleof || BMPType.mangleof == Bitmap16Bit.mangleof ||
								BMPType.mangleof == Bitmap4Bit.mangleof){
							src[x] = 0;
						} else {
							(*dest).raw = 0;
						}
					}
					xy_in += _increment;

				}
				/+else {
					for(short x; x < rasterX; x++){
						int[2] xy = transformFunctionInt([x,y], localTP, localTPO, sXsY);
						//printf("[%i,%i]",xy[0],xy[1]);
						MappingElement currentTile = tileByPixelWithoutTransform(xy[0],xy[1]);
						if(currentTile.tileID != 0xFFFF){
							const DisplayListItem d = displayList[currentTile.tileID];
							static if(BMPType.mangleof == Bitmap4Bit.mangleof){
								ubyte* tsrc = cast(ubyte*)d.pixelSrc;
							}else static if(BMPType.mangleof == Bitmap8Bit.mangleof){
								ubyte* tsrc = cast(ubyte*)d.pixelSrc;
							}else static if(BMPType.mangleof == Bitmap16Bit.mangleof){
								ushort* tsrc = cast(ushort*)d.pixelSrc;
							}else static if(BMPType.mangleof == Bitmap32Bit.mangleof){
								Color* tsrc = cast(Color*)d.pixelSrc;
							}
							xy[0] = xy[0] & (TileX - 1);
							xy[1] = xy[1] & (TileY - 1);
							const int totalOffset = xy[0] + xy[1] * TileX;
							static if(BMPType.mangleof == Bitmap4Bit.mangleof){
								src[x] = (totalOffset & 1 ? tsrc[totalOffset>>1]>>4 : tsrc[totalOffset>>1] & 0x0F) | currentTile.paletteSel<<_paletteOffset;
							}else static if(BMPType.mangleof == Bitmap8Bit.mangleof ){
								src[x] = tsrc[totalOffset] | currentTile.paletteSel<<_paletteOffset;
							}else static if(BMPType.mangleof == Bitmap16Bit.mangleof){
								src[x] = tsrc[totalOffset];
							}else{
								*dest = *tsrc;
								dest++;
							}
						}else{
							static if(BMPType.mangleof == Bitmap8Bit.mangleof || BMPType.mangleof == Bitmap16Bit.mangleof ||
									BMPType.mangleof == Bitmap4Bit.mangleof){
								src[x] = 0;
							}else{
								(*dest).raw = 0;
							}
						}
					}
				}+/
				static if(BMPType.mangleof == Bitmap4Bit.mangleof || BMPType.mangleof == Bitmap8Bit.mangleof || 
						BMPType.mangleof == Bitmap16Bit.mangleof){
					mainColorLookupFunction(src.ptr, cast(uint*)dest, cast(uint*)palette + paletteOffset, rasterX);
					dest += rasterX;
				}
			}
		}
		//render surface onto the raster
		void* p0 = workpad;
		Color* c = backbuffer.getPtr();
		for(int y; y < rasterY; y++){
			mainRenderingFunction(cast(uint*)c, cast(uint*)p0, rasterX, masterVal);
			c += rasterX;
			p0 += pitch;
		}

	}
	///Returns which tile is at the given pixel
	public MappingElement tileByPixel(int x, int y) @nogc @safe pure nothrow const {
		//static if (USE_INTEL_INTRINSICS) {
		//	return MappingElement.init;
		//} else {
		int[2] xy = transformFunctionInt([cast(short)x,cast(short)y],transformPoints,tpOrigin,[cast(short)sX,cast(short)sY]);
		return tileByPixelWithoutTransform(xy[0],xy[1]);
		//}
		
	}
	///Returns which tile is at the given pixel.
	final protected MappingElement tileByPixelWithoutTransform(int x, int y) @nogc @safe pure nothrow const {
		x >>>= shiftX;
		y >>>= shiftY;
		final switch (warpMode) with (WarpMode) {
			case Off:
				if (x >= mX || y >= mY || x < 0 || y < 0) return MappingElement(0xFFFF);
				break;
			case MapRepeat:
				x &= _mapAmpersand[0];
				y &= _mapAmpersand[1];
				break;
			case TileRepeat:
				if (x >= mX || y >= mY || x < 0 || y < 0) return MappingElement(0x0000);
				break;
		}
		return mapping[x + y * mX];
	}
	///Returns two tiles to speed up rendering.
	final protected MappingElement[2] tileByPixelWithoutTransform(__m128i params) @nogc @safe pure nothrow const {
		//params >>>= mapShift;
		params[0] >>= shiftX;
		params[2] >>= shiftX;
		params[1] >>= shiftY;
		params[3] >>= shiftY;
		MappingElement[2] result;
		final switch (warpMode) with (WarpMode) {
			case Off:
				if (params[0] >= mX || params[1] >= mY || params[0] < 0 || params[1] < 0) result[0] = MappingElement(0xFFFF);
				else result[0] = mapping[params[0] + params[1] * mX];
				if (params[2] >= mX || params[3] >= mY || params[2] < 0 || params[3] < 0) result[1] = MappingElement(0xFFFF);
				else result[1] = mapping[params[2] + params[3] * mX];
				return result;
			case MapRepeat:
				params &= _mapAmpersand;
				result[0] = mapping[params[0] + params[1] * mX];
				result[1] = mapping[params[2] + params[3] * mX];
				return result;
			case TileRepeat:
				if (params[0] >= mX || params[1] >= mY || params[0] < 0 || params[1] < 0) result[0] = MappingElement(0x0000);
				else result[0] = mapping[params[0] + params[1] * mX];
				if (params[2] >= mX || params[3] >= mY || params[2] < 0 || params[3] < 0) result[1] = MappingElement(0x0000);
				else result[1] = mapping[params[2] + params[3] * mX];
				return result;
		}
	}
	/**
	 * Horizontal scaling. Greater than 256 means zooming in, less than 256 means zooming out.
	 */
	public @nogc @property pure @safe short A(){
		return transformPoints[0];
	}
	/**
	 * Horizontal shearing.
	 */
	public @nogc @property pure @safe short B(){
		return transformPoints[1];
	}
	/**
	 * Vertical shearing.
	 */
	public @nogc @property pure @safe short C(){
		return transformPoints[2];
	}
	/**
	 * Vertical scaling. Greater than 256 means zooming in, less than 256 means zooming out.
	 */
	public @nogc @property pure @safe short D(){
		return transformPoints[3];
	}
	/**
	 * Horizontal transformation offset.
	 */
	public @nogc @property pure @safe short x_0(){
		return tpOrigin[0];
	}
	/**
	 * Vertical transformation offset.
	 */
	public @nogc @property pure @safe short y_0(){
		return tpOrigin[1];
	}
	/**
	 * Horizontal scaling. Greater than 256 means zooming in, less than 256 means zooming out.
	 */
	public @nogc @property pure @safe short A(short newval){
		transformPoints[0] = newval;
		needsUpdate = true;
		return transformPoints[0];
	}
	/**
	 * Horizontal shearing.
	 */
	public @nogc @property pure @safe short B(short newval){
		transformPoints[1] = newval;
		needsUpdate = true;
		return transformPoints[1];
	}
	/**
	 * Vertical shearing.
	 */
	public @nogc @property pure @safe short C(short newval){
		transformPoints[2] = newval;
		needsUpdate = true;
		return transformPoints[2];
	}
	/**
	 * Vertical scaling. Greater than 256 means zooming in, less than 256 means zooming out.
	 */
	public @nogc @property pure @safe short D(short newval){
		transformPoints[3] = newval;
		needsUpdate = true;
		return transformPoints[3];
	}
	/**
	 * Horizontal transformation offset.
	 */
	public @nogc @property pure @safe short x_0(short newval){
		tpOrigin[0] = newval;
		//tpOrigin[2] = newval;
		needsUpdate = true;
		return tpOrigin[0];
	}
	/**
	 * Vertical transformation offset.
	 */
	public @nogc @property pure @safe short y_0(short newval){
		tpOrigin[1] = newval;
		//tpOrigin[3] = newval;
		needsUpdate = true;
		return tpOrigin[1];
	}
	override public void scroll(int x,int y) {
		super.scroll(x,y);
		needsUpdate = true;
	}
	override public void relScroll(int x,int y) {
		super.relScroll(x,y);
		needsUpdate = true;
	}
	public MappingElement[] getMapping() @nogc @safe pure nothrow {
		return mapping;
	}
	/+public MappingElement readMapping(int x, int y) @nogc @safe pure nothrow const {
		return mapping[(y * mX) + x];
	}+/
	public int getTileWidth() @nogc @safe pure nothrow const {
		return TileX;
	}
	public int getTileHeight() @nogc @safe pure nothrow const {
		return TileY;
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
	///Gets the the ID of the given element from the mapping. x , y : Position.
	public MappingElement readMapping(int x, int y) @nogc @safe pure nothrow const {
		if(!warpMode){
			if(x < 0 || y < 0 || x >= mX || y >= mY){
				return MappingElement(0xFFFF);
			}
		}else{
			x = x % mX;
			y = y % mY;
		}
		return mapping[x+(mX*y)];
	}
	///Writes to the map. x , y : Position. w : ID of the tile.
	@nogc public void writeMapping(int x, int y, MappingElement w) {
		mapping[x+(mX*y)]=w;
	}
	public void addTile(ABitmap tile, wchar id, ubyte paletteSh = 0) {
		if(typeid(tile) !is typeid(BMPType)){
			throw new TileFormatException("Incorrect type of tile!");
		}
		if(tile.width == TileX && tile.height == TileY){
			displayList[id] = DisplayListItem(id, cast(BMPType)tile, paletteSh);
		}else{
			throw new TileFormatException("Incorrect tile size!", __FILE__, __LINE__, null);
		}
	}
	///Returns a tile from the displaylist
	public ABitmap getTile(wchar id) {
		return displayList[id].tile;
	}
	///Removes the tile with the ID from the set.
	public void removeTile(wchar id){
		displayList.remove(id);
	}
	///Loads a mapping from an array. x , y : Sizes of the mapping. map : an array representing the elements of the map.
	///x*y=map.length
	public void loadMapping(int x, int y, MappingElement[] mapping) {
		if (!isPowerOf2(x) || !isPowerOf2(y)) 
			throw new MapFormatException("Map sizes are not power of two!");
		if (x * y != mapping.length) 
			throw new MapFormatException("Incorrect map sizes!");
		mX=x;
		mY=y;
		_mapAmpersand[0] = x - 1;
		_mapAmpersand[1] = y - 1;
		_mapAmpersand[2] = x - 1;
		_mapAmpersand[3] = y - 1;
		this.mapping = mapping;
		totalX=mX*TileX;
		totalY=mY*TileY;
	}
	public void clearTilemap() @nogc @safe pure nothrow {
		for (size_t i ; i < mapping.length ; i++) {
			mapping[i] = MappingElement.init;
		}
	}
}