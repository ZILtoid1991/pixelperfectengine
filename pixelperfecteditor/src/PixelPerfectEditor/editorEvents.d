module editorEvents;

import document;

public import PixelPerfectEngine.concrete.eventChainSystem;
public import PixelPerfectEngine.graphics.layers;
public import PixelPerfectEngine.map.mapformat;

import PixelPerfectEngine.system.file;

import std.stdio;
import std.conv : to;
import sdlang;

public class WriteToMapVoidFill : UndoableEvent {
	ITileLayer target;
	Coordinate area;
	MappingElement me;
	ubyte[] mask;
	public this(ITileLayer target, Coordinate area, MappingElement me){
		this.target = target;
		this.area = area;
		this.me = me;
	}
	public void redo() {
		for(int y = area.top ; y < area.bottom ; y++){
			for(int x = area.left ; x < area.right ; x++){
				if(target.readMapping(x,y).tileID != 0xFFFF){
					mask[area.width * y + x] = 0xFF;
					target.writeMapping(x,y,me);
				}
			}
		}
	}
	public void undo() {
		for(int y = area.top ; y < area.bottom ; y++){
			for(int x = area.left ; x < area.right ; x++){
				if(mask[area.width * y + x] == 0xFF){
					target.writeMapping(x,y,MappingElement(0xFFFF));
				}
			}
		}
	}
}

public class WriteToMapOverwrite : UndoableEvent {
	ITileLayer target;
	Coordinate area;
	MappingElement me;
	MappingElement[] original;
	public this(ITileLayer target, Coordinate area, MappingElement me){
		this.target = target;
		this.area = area;
		this.me = me;
		original.length = area.area;
	}
	public void redo() {
		size_t pos;
		for(int y = area.top ; y < area.bottom ; y++){
			for(int x = area.left ; x < area.right ; x++){
				original[pos] = target.readMapping(x,y);
				target.writeMapping(x,y,me);
				pos++;
			}
		}
	}
	public void undo() {
		size_t pos;
		for(int y = area.top ; y < area.bottom ; y++){
			for(int x = area.left ; x < area.right ; x++){
				target.writeMapping(x,y,original[pos]);
				pos++;
			}
		}
	}
}

public class WriteToMapSingle : UndoableEvent {
	ITileLayer target;
	int x;
	int y;
	MappingElement me;
	MappingElement original;
	public this(ITileLayer target, int x, int y, MappingElement me) {
		this.target = target;
		this.x = x;
		this.y = y;
		this.me = me;
	}
	public void redo() {
		original = target.readMapping(x,y);
		target.writeMapping(x,y,me);
		debug {
			import std.stdio : writeln;
			writeln("Layer was written at position ", x, ";", y," with values ", me);
		}
	}
	public void undo() {
		target.writeMapping(x,y,original);
	}
}

public class CreateTileLayerEvent : UndoableEvent {
	TileLayer creation;
	MapDocument target;
	int tX;
	int tY;
	int mX;
	int mY;
	int pri;
	string name;
	string file;
	string res;
	bool embed;
	Tag backup;
	Image tileSource;

	public this(MapDocument target, int tX, int tY, int mX, int mY, dstring name, string file, string res,
			bool embed) {
		import std.utf : toUTF8;
		creation = new TileLayer(tX, tY);
		this.target = target;
		//this.md = md;
		this.tX = tX;
		this.tY = tY;
		this.mX = mX;
		this.mY = mY;
		this.name = toUTF8(name);
		this.file = file;
		this.res = res;
		this.embed = embed;
		//this.imageReturnFunc = imageReturnFunc;
	}
	public void redo() {
		import std.file : exists, isFile;
		import std.path : baseName;
		import std.utf : toUTF8;
		import PixelPerfectEngine.system.etc : intToHex;
		if (backup) {	//If a backup exists, then re-add that to the document, then return.
			target.mainDoc.addNewLayer(pri, backup, creation);
			target.outputWindow.addLayer(pri);
			return;
		}
		try {
			const int nextLayer = target.nextLayerNumber;

			//handle the following instances for mapping:
			//file == null AND embed
			//file == existing file AND embed
			//file == existing file AND !embed
			//file == nonexisting file
			if ((!exists(file) || !isFile(file)) && embed) {	//create new instance for the map by embedding data into the SDLang file
				//selDoc.mainDoc.tld[nextLayer] = new
				MappingElement[] me;
				me.length = mX * mY;
				creation.loadMapping(mX, mY, me);
				target.mainDoc.addNewTileLayer(nextLayer, tX, tY, mX, mY, name, creation);
				target.mainDoc.addEmbeddedMapData(nextLayer, me);
			} else if (!exists(file)) {	//Create empty file
				File f = File(file, "wb");
				MappingElement[] me;
				me.length = mX * mY;
				creation.loadMapping(mX, mY, me);
				target.mainDoc.addNewTileLayer(nextLayer, tX, tY, mX, mY, name, creation);
				saveMapFile(MapDataHeader(mX, mY), me, f);
				target.mainDoc.addMapDataFile(nextLayer, res);
			} else {	//load mapping, embed data into current file if needed
				MapDataHeader mdh;
				MappingElement[] me = loadMapFile(File(file), mdh);
				creation.loadMapping(mdh.sizeX, mdh.sizeY, me);
				if (embed)
					target.mainDoc.addEmbeddedMapData(nextLayer, me);
				else
					target.mainDoc.addMapDataFile(nextLayer, res);
			}

			//handle the following instances for materials:
			//res == image file
			//TODO: check if material resource file has any embedded resource data
			//TODO: enable importing from SDLang map files (*.ppm)
			//TODO: generate dummy tiles for nonexistent material
			if (exists(res)) {
				//load the resource file and test if it's the correct size (through an exception)
				tileSource = loadImage(File(res));
				ABitmap[] tilesheet;
				switch (tileSource.getBitdepth()) {
					case 4:
						Bitmap4Bit[] output = loadBitmapSheetFromImage!Bitmap4Bit(tileSource, tX, tY);
						foreach(p; output)
							tilesheet ~= p;
						break;
					case 8:
						Bitmap8Bit[] output = loadBitmapSheetFromImage!Bitmap8Bit(tileSource, tX, tY);
						foreach(p; output)
							tilesheet ~= p;
						break;
					case 16:
						Bitmap16Bit[] output = loadBitmapSheetFromImage!Bitmap16Bit(tileSource, tX, tY);
						foreach(p; output)
							tilesheet ~= p;
						break;
					case 32:
						Bitmap32Bit[] output = loadBitmapSheetFromImage!Bitmap32Bit(tileSource, tX, tY);
						foreach(p; output)
							tilesheet ~= p;
						break;
					default:
						throw new Exception("Unsupported bitdepth!");

				}
				if (tilesheet.length == 0) throw new Exception("No tiles were imported!");
				target.addTileSet(nextLayer, tilesheet);
				target.mainDoc.addTileSourceFile(nextLayer, res);
				/+debug {
					TileLayer tl = cast(TileLayer)target;
					writeln(tl.displayList);
				}+/
				//writeln(tilesheet.length);
				//generate default names for the tiles
				{
					TileInfo[] idList;
					string nameBase = baseName(res);
					for (int id ; id < tilesheet.length ; id++) {
						idList ~= TileInfo(cast(wchar)id, id, nameBase ~ "0x" ~ intToHex(id, 4));
						//writeln(idList);
					}
					target.mainDoc.addTileInfo(nextLayer, idList, res);
				}
				if (tileSource.isIndexed) {
					Color[] palette;
					/*foreach (color ; tileSource.palette) {
						palette ~= Color(color.a, color.r, color.g, color.b);
						debug writeln(color);
					}*/
					auto sourcePalette = tileSource.palette;
					palette.reserve(sourcePalette.length);
					for (ushort i ; i < sourcePalette.length ; i++){
						const auto origC = sourcePalette[i];
						const Color c = Color(origC.a, origC.r, origC.g, origC.b);
						palette ~= c;
					}
					debug writeln(palette);
					target.mainDoc.addPaletteFile(file, "", cast(int)target.outputWindow.palette.length);
					target.outputWindow.palette = target.outputWindow.palette ~ palette;
				}

			}
			target.outputWindow.addLayer(nextLayer);
			target.selectedLayer = nextLayer;
			pri = nextLayer;
			target.updateLayerList();
			target.updateMaterialList();
		} catch (Exception e) {
			debug writeln(e);
		}
	}
	public void undo() {
		//Just remove the added layer from the layerlists
		target.outputWindow.removeLayer(pri);
		backup = target.mainDoc.removeLayer(pri);
		target.updateLayerList();
		target.updateMaterialList();
	}
}
