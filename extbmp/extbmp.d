module extbmp.extbmp;

import std.xml;
import std.bitmanip;
import std.stdio;
import std.zlib;
import std.conv;

public import extbmp.animation;

public class ExtendibleBitmap{


	public AnimationData[string] animData;
	private void[] rawData, rawData0;
	private string filename;
	private string[string] metaData;
	private ReplaceData[string] dataReplacer;
	private PaletteData[string] palettes;
	private int[string] paletteOffset;
	private int headerLenght;
	private uint flags;
	public string[] bitmapID, bitdepth, format, paletteMode;
	private int[] offset, iX, iY;
	//private ushort[string] paletteOffset;
	this(){

	}
	this(void[] data){
		rawData = data;
		flags = *cast(uint*)rawData.ptr;
		headerLenght = *cast(int*)rawData.ptr + 4;
		if((flags & ExtBMPFlags.CompressionMethodNull) == ExtBMPFlags.CompressionMethodNull){
			headerLoad();
		}else if((flags & ExtBMPFlags.CompressionMethodZLIB) == ExtBMPFlags.CompressionMethodZLIB){
			rawData0 = uncompress(rawData[8..rawData.length-1]);
			rawData.length = 8;
			rawData ~= rawData0;
			rawData0.length = 0;
			headerLoad();
		}
		rawData0 = rawData[9 + headerLenght..rawData.length-1];
		rawData.length = 0;
	}
	this(string filename){
		this.filename = filename;
		loadFile();
	}
	public void setFileName(string s){
		filename = s;
	}
	public void loadFile(){
		rawData = std.file.read(filename);
		flags = *cast(uint*)rawData.ptr;
		headerLenght = *cast(int*)rawData.ptr + 4;
		if((flags & ExtBMPFlags.CompressionMethodNull) == ExtBMPFlags.CompressionMethodNull){
			headerLoad();
		}else if((flags & ExtBMPFlags.CompressionMethodZLIB) == ExtBMPFlags.CompressionMethodZLIB){
			rawData0 = uncompress(rawData[8..rawData.length-1]);
			rawData.length = 8;
			rawData ~= rawData0;
			rawData0.length = 0;
			headerLoad();
		}
		rawData0 = rawData[9 + headerLenght..rawData.length-1];
		rawData.length = 0;
	}
	public void saveFile(){
		saveFile(filename);
	}
	public void saveFile(string f){
		writeln(f);
		try{
			rawData.length=8;
			*cast(uint*)rawData.ptr = flags;
			headerSave();
			headerLenght = rawData.length-8;
			*cast(int*)(rawData.ptr+4) = headerLenght;
			rawData ~= rawData0;
			//File file = File(f, "w");
			//file.rawWrite(rawData);

			std.file.write(f, rawData);
		}catch(Exception e){
			writeln(e.toString);
		}
	}
	private void headerLoad(){
		string s = cast(string)rawData[8..8 + headerLenght];
		Document d = new Document(s);
		foreach(Element e1; d.elements){
			if(e1.tag.name == "MetaData"){
				foreach(Element e2; e1.elements){
					metaData[e2.tag.name] = e2.text;
				}
			}else if(e1.tag.name == "Bitmap"){
				bitmapID ~= e1.tag.attr["ID"];
				offset ~= to!int(e1.tag.attr["offset"]);
				iX ~= to!int(e1.tag.attr["sizeX"]);
				iY ~= to!int(e1.tag.attr["sizeY"]);
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
				palettes[e1.tag.attr["ID"]] = PaletteData();
				palettes[e1.tag.attr["ID"]].length = to!int(e1.tag.attr["length"]);
				palettes[e1.tag.attr["ID"]].format = e1.tag.attr.get("format","");
				paletteOffset[e1.tag.attr["ID"]] = to!int(e1.tag.attr["offset"]);
			}else if(e1.tag.name == "AnimData"){
				animData[e1.tag.attr["ID"]] = AnimationData();
				foreach(Element e2; e1.elements){
					animData[e1.tag.attr["ID"]].addFrame(e2.tag.attr["ID"], to!int(e2.tag.attr["length"]));
				}
			}
		}
	}
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
			if(format[i] != ""){
				e1.tag.attr["format"] = format[i];
			}
			if(paletteMode[i] != ""){
				e1.tag.attr["paletteMode"] = paletteMode[i];
			}
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

		foreach(string s; palettes.byKey()){
			auto e1 = new Element("Palette");
			e1.tag.attr["ID"] = s;
			e1.tag.attr["length"] = to!string(palettes[s].length);
			e1.tag.attr["offset"] = to!string(paletteOffset[s]);
			if(palettes[s].format != "")
				e1.tag.attr["format"] = palettes[s].format;
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
		rawData ~= cast(void[])doc.toString();
	}
	private int searchForID(string ID){
		for(int i; i < bitmapID.length; i++){
			if(bitmapID[i] == ID){
				return i;
			}
		}
		return -1;
	}
	public string[] getIDs(){
		return bitmapID;
	}
	/*public string[] getIDs(string s){}*/
	public void addBitmap(void[] data, int x, int y, string bitDepth, string ID, string format = ""){
		int o = rawData0.length;
		rawData0 ~= data;
		offset ~= o;
		iX ~= x;
		iY ~= y;
		bitmapID ~= ID;
		bitdepth ~= bitDepth;
		this.format ~= format;
	}
	public void addBitmap(ushort[] data, int x, int y, string bitDepth, string ID, string format = ""){
		int o = rawData0.length;
		rawData0 ~= cast(void[])data;
		offset ~= o;
		iX ~= x;
		iY ~= y;
		bitmapID ~= ID;
		bitdepth ~= bitDepth;
		this.format ~= format;
	}
	public void addBitmap(ubyte[] data, int x, int y, string bitDepth, string ID, string format = "", ReplaceData rd = null){
		int o = rawData0.length;
		rawData0 ~= cast(void[])data;
		offset ~= o;
		iX ~= x;
		iY ~= y;
		bitmapID ~= ID;
		bitdepth ~= bitDepth;
		this.format ~= format;

	}
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
	public ubyte[] get8bitBitmap(string ID){
		int n = searchForID(ID);
		int l = iX[n]*iY[n];
		return cast(ubyte[])rawData0[offset[n]..offset[n]+l];
	}
	public ushort[] get16bitBitmap(string ID){
		int n = searchForID(ID);
		int l = iX[n]*iY[n];
		ushort[] d;
		if(dataReplacer.get(ID,null) is null){
			for(int i = offset[n]; i < offset[n] + l; i+=2){
				d ~= *cast(ushort*)rawData0.ptr;
			}
		}else{
			d = dataReplacer[ID].decodeBitmap(cast(ubyte[])rawData0[offset[n]..offset[n]+l]);
		}
		return d;
	}
	public int getXsize(string ID){
		return iX[searchForID(ID)];
	}
	public int getYsize(string ID){
		return iY[searchForID(ID)];
	}
	public string getBitDepth(string ID){
		return bitdepth[searchForID(ID)];
	}
	public string getFormat(string ID){
		return format[searchForID(ID)];
	}
	public bool isEmpty(){
		return (bitmapID.length == 0);
	}
}

public struct PaletteData{
	ubyte[] data;
	string format;
	int length;

}

public class ReplaceData{
	ubyte[] src;
	ushort[] dest;
	this(){
		
	}
	void addReplaceAttr(ubyte f, ushort t){
		this.src ~= f;
		this.dest ~= t;
	}
	ushort[] decodeBitmap(ubyte[] data){
		ushort[] result;
		result.length = data.length;
		for(int i; i < data.length; i++){
			result[i] = lookupForDecoding(data[i]);
		}
		return result;
	}
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
	CompressionMethodNull = 1,
	CompressionMethodZLIB = 2,
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