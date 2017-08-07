/*
 * Copyright (C) 2015-2017, by Laszlo Szeremi under the Boost license.
 *
 * Pixel Perfect Engine, extbmp module
 */

module PixelPerfectEngine.extbmp.extbmp;

import std.xml;
import std.bitmanip;
import std.stdio;
import std.zlib;
import std.conv;
import std.file;

public import PixelPerfectEngine.extbmp.animation;
/**
 * Proprietary image format for the engine. Mainly created to get around the lack of 16bit indexed image formats. 
 * Stores most data in XML, binary is stored after the document. Most data is little endian, future versions might be able to specify big endian data in the binary, but due to
 * the main targets (x86 and ARM) are mainly little endian, it's unlikely.
 */
public class ExtendibleBitmap{
	public AnimationData[string] animData;	///Stores animation data. See documentation of AnimationData for more information.
	private void[] rawData, rawData0;		///The binary workfield.
	private string filename;				///Stores the current filename.
	private string[string] metaData;		///Stores metadata. Serialized as: [index] = value &lt = &gt &lt index &gt value &lt / index &gt
	private ReplaceData[string] dataReplacer;	///Datareplacers for the indexed 8bit bitmaps.
	private size_t[string] paletteOffset;	///The starting point of the palette.
	private size_t[string] paletteLength;	///The length of the palette.
	private int headerLength;		///The length of the header in bytes.
	private uint flags;				///See ExtBMPFlags for details.
	public string[] bitmapID;		///The ID of the bitmap. Used to identify the bitmaps in the file.
	public string[] bitdepth;		///Bitdepth of the given bitmap. Editing this might make the bitmap unusable.
	public string[] format;			///Format of the given bitmap. Editing this might make the bitmap unusable or cause graphic corruption.
	public string[] paletteMode;	///Palette of the given bitmap. Null if unindexed, default or the palette's name otherwise.
	private size_t[] offset;		///The starting point of the bitmap in the binary field.
	private int[] iX;			///The X size of the bitmap.
	private int[] iY;			///The X size of the bitmap.
	private size_t[] length;		///The size of the bitmap in the binary field in bytes.
	//private ushort[string] paletteOffset;
	/// Standard constructor for empty files.
	this(){

	}
	/// Loads file from a binary.
	this(void[] data){
		rawData = data;
		flags = *cast(uint*)rawData.ptr;
		headerLength = *cast(int*)rawData.ptr + 4;
		if((flags & ExtBMPFlags.CompressionMethodNull) == ExtBMPFlags.CompressionMethodNull){
			headerLoad();
		}else if((flags & ExtBMPFlags.CompressionMethodZLIB) == ExtBMPFlags.CompressionMethodZLIB){
			rawData0 = uncompress(rawData[8..rawData.length]);
			rawData.length = 8;
			rawData ~= rawData0;
			rawData0.length = 0;
			headerLoad();
		}
		rawData0 = rawData[(9 + headerLength)..rawData.length];
		rawData.length = 0;
	}
	/// Loads file from file.
	this(string filename){
		this.filename = filename;
		loadFile();
	}
	/// Sets the filename 
	public void setFileName(string s){
		filename = s;
	}
	/// Loads the file specified in field "filename"
	public void loadFile(){
		//writeln(filename);
		try{
			rawData = std.file.read(filename);
			flags = *cast(uint*)rawData.ptr;
			headerLength = *cast(int*)(rawData.ptr + 4);
			//if((flags & ExtBMPFlags.CompressionMethodNull) == ExtBMPFlags.CompressionMethodNull){
			headerLoad();
			/*}else if((flags & ExtBMPFlags.CompressionMethodZLIB) == ExtBMPFlags.CompressionMethodZLIB){
				rawData0 = uncompress(rawData[8..rawData.length-1]);
				rawData.length = 8;
				rawData ~= rawData0;
				rawData0.length = 0;
				headerLoad();
			}*/
			
			if(rawData.length > 8 + headerLength){
				rawData0 = rawData[8 + headerLength..rawData.length];
			}
			rawData.length = 0;
			//writeln(cast(string)rawData0);
		}catch(Exception e){
			writeln(e.toString);
		}
	}
	/// Saves the file to the place specified in field "filename".
	public void saveFile(){
		saveFile(filename);
	}
	/// Saves the file to the given location.
	public void saveFile(string f){
		//writeln(f);
		try{
			rawData.length=8;
			*cast(uint*)rawData.ptr = flags;
			headerSave();
			
			*cast(int*)(rawData.ptr+4) = headerLength;
			rawData ~= rawData0;
			//File file = File(f, "w");
			//file.rawWrite(rawData);

			std.file.write(f, rawData);
		}catch(Exception e){
			writeln(e.toString);
		}
		rawData.length = 0;
	}
	/// Deserializes the header data.
	private void headerLoad(){
		string s = cast(string)rawData[8..8 + headerLength];
		//writeln(s);
		Document d = new Document(s);
		foreach(Element e1; d.elements){
			if(e1.tag.name == "MetaData"){
				//writeln("MetaData found");
				foreach(Element e2; e1.elements){
					metaData[e2.tag.name] = e2.text;
				}
			}else if(e1.tag.name == "Bitmap"){
				//writeln("Bitmap found");
				bitmapID ~= e1.tag.attr["ID"];
				offset ~= to!int(e1.tag.attr["offset"]);
				iX ~= to!int(e1.tag.attr["sizeX"]);
				iY ~= to!int(e1.tag.attr["sizeY"]);
				length ~= to!int(e1.tag.attr["length"]);
				bitdepth ~= e1.tag.attr["bitDepth"];
				format ~= e1.tag.attr.get("format","");
				paletteMode ~= e1.tag.attr.get("paletteMode","");
				if(e1.tag.attr.get("format","") == "upconv"){
					dataReplacer[e1.tag.attr["ID"]] = new ReplaceData();
					foreach(Element e2; e1.elements){
						if(e1.tag.name == "ColorSwap"){
							dataReplacer[e1.tag.attr["ID"]].addReplaceAttr(to!ubyte(e2.tag.attr["from"]), to!ushort(e2.tag.attr["to"]));
						}
					}
				}
			}else if(e1.tag.name == "Palette"){
				//writeln("Palette found");
				//palettes[e1.tag.attr["ID"]] = PaletteData();
				paletteLength[e1.tag.attr["ID"]] = to!int(e1.tag.attr["length"]);
				//palettes[e1.tag.attr["ID"]].format = e1.tag.attr.get("format","");
				paletteOffset[e1.tag.attr["ID"]] = to!int(e1.tag.attr["offset"]);
			}else if(e1.tag.name == "AnimData"){
				animData[e1.tag.attr["ID"]] = AnimationData();
				foreach(Element e2; e1.elements){
					animData[e1.tag.attr["ID"]].addFrame(e2.tag.attr["ID"], to!int(e2.tag.attr["length"]));
				}
			}
		}
	}
	/// Serializes the header data.
	private void headerSave(){
		auto doc = new Document(new Tag("HEADER"));
		auto e0 = new Element("MetaData");
		foreach(string s; metaData.byKey()){
			e0 ~= new Element(s, metaData[s]);
		}

		doc ~= e0;
		for(int i; i < bitmapID.length; i++){
			auto e1 = new Element("Bitmap");
			e1.tag.attr["ID"] = bitmapID[i];
			e1.tag.attr["offset"] = to!string(offset[i]);
			e1.tag.attr["sizeX"] = to!string(iX[i]);
			e1.tag.attr["sizeY"] = to!string(iY[i]);
			e1.tag.attr["bitDepth"] = bitdepth[i];
			e1.tag.attr["length"] = to!string(length[i]);
			if(format[i] != ""){
				e1.tag.attr["format"] = format[i];
			}
			/*if(paletteMode[i] != ""){
				e1.tag.attr["paletteMode"] = paletteMode[i];
			}*/
			if(dataReplacer.get(bitmapID[i], null) !is null){
				for(int j; j < dataReplacer[bitmapID[i]].src.length; j++){
					auto e2 = new Element("ColorSwap");
					e2.tag.attr["from"] = to!string(dataReplacer[bitmapID[i]].src[j]);
					e2.tag.attr["to"] = to!string(dataReplacer[bitmapID[i]].dest[j]);
					e1 ~= e2;
				}
			}
			doc ~= e1;
		}

		foreach(string s; paletteLength.byKey()){
			auto e1 = new Element("Palette");
			e1.tag.attr["ID"] = s;
			e1.tag.attr["length"] = to!string(paletteLength[s]);
			e1.tag.attr["offset"] = to!string(paletteOffset[s]);
			/*if(palettes[s].format != "")
				e1.tag.attr["format"] = palettes[s].format;*/
			doc ~= e1;
		}

		foreach(string s; animData.byKey()){
			auto e1 = new Element("AnimData");
			e1.tag.attr["ID"] = s;
			for(int i; i < animData[s].duration.length; i++){
				auto e2 = new Element("Frame");
				e2.tag.attr["ID"] = animData[s].ID[i];
				e2.tag.attr["length"] = to!string(animData[s].duration[i]);
				e1 ~= e2;
			}
			doc ~= e1;
		}
		string h = doc.toString();
		headerLength = h.length;
		//writeln(h);
		writeln(headerLength);
		rawData ~= cast(void[])h;
	}
	/// Returns the first instance of the ID.
	public int searchForID(string ID){
		for(int i; i < bitmapID.length; i++){
			if(bitmapID[i] == ID){
				return i;
			}
		}
		return -1;
	}
	public deprecated string[] getIDs(){
		return bitmapID;
	}
	/// Adds a bitmap to the file (any supported formats).
	public void addBitmap(void[] data, int x, int y, string bitDepth, string ID, string format = ""){
		int o = rawData0.length;
		rawData0 ~= data;
		offset ~= o;
		iX ~= x;
		iY ~= y;
		bitmapID ~= ID;
		bitdepth ~= bitDepth;
		length ~= data.length;
		this.format ~= format;
	}
	/// Adds a bitmap to the file (16bit).
	public void addBitmap(ushort[] data, int x, int y, string bitDepth, string ID, string format = ""){
		int o = rawData0.length;
		rawData0 ~= cast(void[])data;
		offset ~= o;
		iX ~= x;
		iY ~= y;
		bitmapID ~= ID;
		bitdepth ~= bitDepth;
		length ~= data.length * 2;
		this.format ~= format;
	}
	/// Adds a bitmap to the file (8bit or 32bit).
	public void addBitmap(ubyte[] data, int x, int y, string bitDepth, string ID, string format = "", ReplaceData rd = null){
		int o = rawData0.length;
		rawData0 ~= cast(void[])data;
		offset ~= o;
		iX ~= x;
		iY ~= y;
		bitmapID ~= ID;
		bitdepth ~= bitDepth;
		length ~= data.length;
		this.format ~= format;

	}
	/// Adds a palette to the file (32bit only, ARGB).
	public void addPalette(void[] data, string ID){
		if(paletteLength.get(ID, -1)==-1){
			paletteOffset[ID] = rawData0.length;
			rawData0 ~= data;
			paletteLength[ID] = data.length;
		}else{

		}
		writeln(cast(ubyte[])data);
	}
	/// Removes the palette with the given ID.
	public void removePalette(string ID){
		removeRangeFromBinary(paletteOffset[ID],paletteLength[ID]);
		paletteLength.remove(ID);
		paletteOffset.remove(ID);
	}
	/// Gets the bitmap with the given ID (all formats).
	public void[] getBitmap(string ID){
		int pitch;
		int n = searchForID(ID);
		switch(bitdepth[n]){
			case "1bit": pitch = 1; break;
			case "8bit": pitch = 8; break;
			case "16bit": pitch = 16; break;
			case "32bit": pitch = 32; break;
			default: break;
		}

		int l = iX[n]*iY[n]*(pitch/8);
		if(pitch == 1){
			BitArray ba = BitArray(rawData0[offset[n]..offset[n]+l], l);
			return cast(void[])ba;
		}
		return rawData0[offset[n]..offset[n]+l];
	}
	public void[] getBitmapRaw(int n){
		int pitch;
		//int n = searchForID(ID);
		switch(bitdepth[n]){
			case "1bit": pitch = 1; break;
			case "8bit": pitch = 8; break;
			case "16bit": pitch = 16; break;
			case "32bit": pitch = 32; break;
			default: break;
		}
		
		int l = iX[n]*iY[n]*(pitch/8);
		if(pitch == 1){
			BitArray ba = BitArray(rawData0[offset[n]..offset[n]+l], l);
			return cast(void[])ba;
		}
		return rawData0[offset[n]..offset[n]+l];
	}
	public ubyte[] getBitmap(int n){
		int pitch;
		//int n = searchForID(ID);
		/*switch(bitdepth[n]){
			case "1bit": pitch = 1; break;
			case "8bit": pitch = 8; break;
			case "16bit": pitch = 16; break;
			case "32bit": pitch = 32; break;
			default: break;
		}*/

		//int l = (iX[n]*iY[n]*pitch)/8;
		/*if(pitch == 1){
			BitArray ba = BitArray(rawData0[offset[n]..offset[n]+l], l);
			return cast(void[])ba;
		}*/
		writeln(offset[n],',',offset[n]+length[n]);
		return cast(ubyte[])(rawData0[offset[n]..offset[n]+length[n]]);
	}
	/// Gets the bitmap with the given ID (8bit).
	public ubyte[] get8bitBitmap(string ID){
		int n = searchForID(ID);
		//int l = iX[n]*iY[n];
		return cast(ubyte[])rawData0[offset[n]..offset[n]+length[n]];
	}
	/// Gets the bitmap with the given ID (16bit or 8bit Huffman encoded).
	public ushort[] get16bitBitmap(string ID){
		int n = searchForID(ID);
		//int l = iX[n]*iY[n];
		ushort[] d;
		if(bitdepth[n] == "16bit"){

		}else{
			if(dataReplacer.get(ID,null) is null){
				for(int i ; i < length[n]; i++){
					d ~= *cast(ubyte*)(rawData0.ptr + offset[n] + i);
				}
			}else{
				d = dataReplacer[ID].decodeBitmap(cast(ubyte[])rawData0[offset[n]..offset[n]+length[n]]);
			}
		}
		return d;
	}
	/// Removes the bitmap from the file by ID.
	public void removeBitmap(string ID){
		import std.algorithm.mutation;
		int i = searchForID(ID);
		removeRangeFromBinary(offset[i],length[i]);
		offset = remove(offset, i);
		length = remove(length, i);
		paletteMode = remove(paletteMode, i);
		bitdepth = remove(bitdepth, i);
		format = remove(format, i);
		bitmapID = remove(bitmapID, i);
		iX = remove(iX, i);
		iY = remove(iY, i);
	}
	/// Removes the bitmap from the file by index.
	public void removeBitmap(int i){
		import std.algorithm.mutation;
		removeRangeFromBinary(offset[i],length[i]);
		offset = remove(offset, i);
		length = remove(length, i);
		paletteMode = remove(paletteMode, i);
		bitdepth = remove(bitdepth, i);
		format = remove(format, i);
		bitmapID = remove(bitmapID, i);
		iX = remove(iX, i);
		iY = remove(iY, i);
	}
	/// Returns the palette with the given ID.
	public void[] getPalette(string ID){
		if(paletteLength.get(ID, -1) == -1){
			ID = "default";
		}
		return rawData0[paletteOffset[ID]..(paletteOffset[ID]+paletteLength[ID])];
	}
	/// Returns the palette for the bitmap if exists.
	public string getPaletteMode(string ID){
		return paletteMode[searchForID(ID)];
	}
	/// Returns the X size by ID.
	public int getXsize(string ID){
		return iX[searchForID(ID)];
	}
	/// Returns the X size by number.
	public int getXsize(int i){
		return iX[i];
	}
	/// Returns the Y size by ID.
	public int getYsize(string ID){
		return iY[searchForID(ID)];
	}
	/// Returns the X size by number.
	public int getYsize(int i){
		return iY[i];
	}
	/// Returns the bitdepth of the image.
	public string getBitDepth(string ID){
		return bitdepth[searchForID(ID)];
	}
	/// Returns the pixel format of the image.
	public string getFormat(string ID){
		return format[searchForID(ID)];
	}
	/// Returns true if file doesn't contain any images.
	public bool isEmpty(){
		return (bitmapID.length == 0);
	}
	/// Removes a given range from the binary field.
	private void removeRangeFromBinary(size_t offset, size_t length){
		if(length == 0){
			return;
		}
		if(offset == 0){
			rawData0 = rawData0[length..rawData0.length];
		}else if(offset + length == rawData0.length){
			rawData0 = rawData0[0..offset];
		}else{
			rawData0 = rawData0[0..offset] ~ rawData0[(offset+length)..rawData0.length];
		}
		foreach(string s ; paletteOffset.byKey){
			if(paletteOffset[s] > offset){
				paletteOffset[s] -= length;
			}
		}
		for (int i ; i < bitmapID.length ; i++){
			if(this.offset[i] > offset){
				this.offset[i] -= length;
			}
		}
	}
}
/**
* Does a Huffman encoding/decoding to convert between 8bit and 16bit.
*/

public class ReplaceData{
	ubyte[] src;
	ushort[] dest;
	this(){
		
	}
	/// Adds a new replaceattribute
	void addReplaceAttr(ubyte f, ushort t){
		this.src ~= f;
		this.dest ~= t;
	}
	/// Decodes bitmap with the preprogrammed dictionary.
	ushort[] decodeBitmap(ubyte[] data){
		ushort[] result;
		result.length = data.length;
		for(int i; i < data.length; i++){
			result[i] = lookupForDecoding(data[i]);
		}
		return result;
	}
	/// Decodes bitmap with the preprogrammed dictionary.
	ubyte[] encodeBitmap(ushort[] data){
		ubyte[] result;
		result.length = data.length;
		for(int i; i < data.length; i++){
			result[i] = lookupForEncoding(data[i]);
		}
		return result;
	}

	private ushort lookupForDecoding(ubyte b){
		for(int i; i < src.length; i++){
			if(src[i] == b){
				return dest[i];
			}
		}
		return b;
	}

	private ubyte lookupForEncoding(ushort s){
		for(int i; i < src.length; i++){
			if(dest[i] == s){
				return src[i];
			}
		}
		return to!ubyte(s);
	}
	
}

public enum ExtBMPFlags : uint{
	CompressionMethodNull	=	1,		///No compression.
	CompressionMethodZLIB	=	2,		///Compression using DEFLATE.
	CompressionMethodLZMA	=	3,		///Compression using Lempel-Zif-Markov algorithm.
	LongHeader              =   16,		///For headers over 2 gigabyte.
	LongFile                =   32		///For files over 2 gigabyte.
	/*ZLIBCompressionLevel0 = 16,
	ZLIBCompressionLevel1 = 32,
	ZLIBCompressionLevel2 = 48,
	ZLIBCompressionLevel3 = 64,
	ZLIBCompressionLevel4 = 80,
	ZLIBCompressionLevel5 = 96,
	ZLIBCompressionLevel6 = 112,
	ZLIBCompressionLevel7 = 128,
	ZLIBCompressionLevel8 = 144,
	ZLIBCompressionLevel9 = 160,*/
}