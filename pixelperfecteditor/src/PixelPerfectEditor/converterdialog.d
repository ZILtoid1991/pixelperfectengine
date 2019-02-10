/*
 * PixelPerfectEditor, converterdialog module
 *
 * Copyright 2017, under Boost License
 *
 * by Laszlo Szeremi
 */
module converterdialog;

import std.conv;
import std.stdio;

import PixelPerfectEngine.concrete.window;
import PixelPerfectEngine.concrete.elements;

import PixelPerfectEngine.map.mapload;

import PixelPerfectEngine.system.etc;
import PixelPerfectEngine.system.inputHandler;

import PixelPerfectEngine.graphics.bitmap;
import PixelPerfectEngine.graphics.layers;

import PixelPerfectEngine.extbmp.extbmp;

import converter;
import importDialog;
import multiImportDialog;
/**
 *Creates a window for converting external bitmaps for the engine's native format
 */
public class ConverterDialog : Window{
	private ListBox imageList, fileList, animationList, frameList;
	private string[] filenames;
	private string importFileName,animationSelection;
	private Label[string] labels;
	private InputHandler inputHandler;
	public ExtendibleBitmap[] files;
	private ISpriteLayer viewer;
	private Bitmap32Bit preview;
	private PreviewWindow previewWindow;
	private int imageSelection, frameSelection;

	public bool previewModeOn;
	ExtendibleBitmap selection;
	public this(InputHandler inputhandler, ISpriteLayer viewer, ExtendibleMap mh = null, ExtendibleBitmap[] documentFiles = null){
		this(Coordinate(0,16,640,480), "XMP Converter Toolkit");
		this.inputHandler = inputhandler;
		this.viewer = viewer;
		files = documentFiles;
		Button [] buttons;
		if(mh !is null){
			//filenames = mh.getAllFilenames();
			//fileList = new ListBox("fileList",Coordinate(4,20,204,101), [ListBoxColumn("Filename",filenames)], [256], 15);
		}else{
			labels["0x00"] = new Label("Path:", "", Coordinate(4,20,204,40));
			labels["path"] = new Label("n/a", "path", Coordinate(4,40,204,60));
		}
		buttons ~= new Button("New File","newfile", Coordinate(210,20,294,39));
		buttons ~= new Button("Load File","loadfile", Coordinate(210,40,294,59));
		buttons ~= new Button("Save File","savefile", Coordinate(210,60,294,79));
		//buttons ~= new Button("Rem File","removefile", Coordinate(210,60,294,79)); //[ListBoxColumn("BitmapID",[""]),ListBoxColumn("Bitdepth",[""]),ListBoxColumn("Format",[""]),ListBoxColumn("PalMode",[""])] //[128,64,64,80]
		imageList = new ListBox("imageList",Coordinate(4,104,204,304),null,new ListBoxHeader(["BitmapID","Bitdepth","Format","PalMode","sizeX","sizeY"], [128,64,64,80,42,42]), 15);
		buttons ~= new Button("Import New","inportnew", Coordinate(210,110,294,129));
		buttons ~= new Button("Imp Multi","inportmultiple", Coordinate(210,130,294,149));
		buttons ~= new Button("Export As","exportas", Coordinate(210,150,294,169));
		buttons ~= new Button("Remove","remove", Coordinate(210,170,294,189));
		buttons ~= new Button("Preview","preview", Coordinate(210,190,294,209));
		buttons ~= new Button("Imp Pal","paletteImport", Coordinate(210,210,294,229));
		animationList = new ListBox("animationList", Coordinate(300,20,500,120), null, new ListBoxHeader(["AnimID","Frames"], [128,80]), 15);
		buttons ~= new Button("New Anim","newAnim", Coordinate(506,20,590,39));
		buttons ~= new Button("Edit","animProp", Coordinate(506,40,590,59));
		//buttons ~= new Button("Save File","savefile", Coordinate(506,60,590,79));
		buttons ~= new Button("Rem Anim","removeAnim", Coordinate(506,60,590,79));
		frameList = new ListBox("frameList", Coordinate(300,122,500,304), null, new ListBoxHeader(["Num","ImageID","Dur"],[40,128,64]), 15);
		buttons ~= new Button("Add Frame","addFrame", Coordinate(506,130,590,149));
		buttons ~= new Button("Edit","editFr", Coordinate(506,150,590,169));
		buttons ~= new Button("Remove","removeFr", Coordinate(506,170,590,189));

		foreach(Button e; buttons){
			addElement(e, EventProperties.MOUSE);
			e.onMouseLClickRel = &actionEvent;
		}
		foreach(WindowElement e; labels){
			addElement(e, EventProperties.MOUSE);
		}
		addElement(imageList, EventProperties.MOUSE);
		imageList.onItemSelect = &actionEvent;
		addElement(animationList, EventProperties.MOUSE);
		addElement(frameList, EventProperties.MOUSE);
	}

	public this(Coordinate size, dstring title){
		super(size, title);
	}

	public void singleImport(string bitmapID, string paletteID, bool importPal, string bitDepth){
		try{
			importDirectlyToXMP(importFileName,paletteID,selection,new ImportData([bitmapID],bitDepth,0,0,0));
			if(importPal){//
				importPaletteDirectlyToXMP(importFileName,selection,paletteID);
			}
		}catch(Exception e){
			writeln(e);
		}
	}

	public void multiImport(string foretag, string aftertag, int digits, string paletteID, bool importPal, string bitDepth, int numFrom, int sX, int sY, bool useHex){
		try{
			NamingConvention nc = new NamingConvention(foretag, aftertag, useHex ? NumberingStyle.HEXADECIMAL : NumberingStyle.DECIMAL, numFrom, digits);
			importDirectlyToXMP(importFileName, paletteID, selection, new ImportData(nc, bitDepth, sX, sY, 0));
			if(importPal){//
				importPaletteDirectlyToXMP(importFileName,selection,paletteID);
			}
		}catch(Exception e){
			parent.messageWindow(to!dstring(e.classinfo.toString()), to!dstring(e.msg));
		}
	}

	public void actionEvent(Event event){
		//writeln(event.subsource);
		//writeln(event.source);
		switch(event.subsource){
			case "filedialog":
				switch(event.source){
					case "xmpfiledialog":
						ExtendibleBitmap newFile = new ExtendibleBitmap();
						string fileName = event.path ;
						fileName ~= '\\';
						fileName ~= event.filename;
						newFile.saveFile(fileName);
						if(files is null){
							selection = newFile;
							labels["path"].setText(to!dstring(fileName));
						}else{
							files ~= newFile;
							filenames ~= fileName;
							selection = newFile;
						}

						break;
					case "xmpload":
						string fileName = event.path ;
						//writeln(fileName);
						fileName ~= '\\';
						//writeln(fileName);
						fileName ~= event.filename;
						//writeln(fileName);
						ExtendibleBitmap newFile = new ExtendibleBitmap(fileName);
						if(files is null){
							selection = newFile;
							labels["path"].setText(to!dstring(fileName));
						}else{
							files ~= newFile;
							filenames ~= fileName;
							selection = newFile;
						}
						updateImageList();
						updateAnimationList();
						break;
					case "importfile":
						string fileName = event.path ;
						fileName ~= '\\';
						fileName ~= event.filename;
						importFileName = fileName;
						//Bitmap32Bit bmp = importBitmapFromFile(fileName);
						//ImportDialog id = new ImportDialog(this);
						//id.al ~= this;
						parent.addWindow(new ImportDialog(this));
						break;
					case "importmulti":
						string fileName = event.path;
						fileName ~= '\\';
						fileName ~= event.filename;
						importFileName = fileName;
						BitmapInfo bi = getBitmapInfo(importFileName);

						parent.addWindow(new MultiImportDialog(bi.width, bi.height, this));
						break;
					case "palettefile":
						string fileName = event.path;
						fileName ~= '\\';
						fileName ~= event.filename;
						importFileName = fileName;
						TextInputDialog tid = new TextInputDialog(Coordinate(0,0,200,90),"palName","Import Palette","Palette ID:");

						parent.addWindow(tid);
						break;
					default: break;
				}
				break;
			/+case "impDial":

				try{
					/*Bitmap32Bit bmp = import32BitBitmapFromFile(importFileName);
					 selection.addBitmap(cast(void[])bmp.getRawdata(),bmp.getX,bmp.getY,"32bit",to!string(event.text),"ARGB");
					 updateImageList();
					 previewModeOn = true;
					 //set sprite for preview mode
					 //writeln(preview);
					 viewer.addSprite(bmp, 0, 0, 0);*/
					string bitdepth;
					switch(event.value){
						case 0: bitdepth = "8bit"; break;
						case 1: bitdepth = "16bit"; break;
						case 2: bitdepth = "32bit"; break;
						default: bitdepth = "1bit"; break;
					}
					importDirectlyToXMP(importFileName,selection,new ImportData([to!string(event.text)],bitdepth,0,0,0));

					}catch(Exception e){
						writeln(e);
					}
				break;+/
			case "TextInputDialog":
				switch(event.source){
					case "palName":
						importPaletteDirectlyToXMP(importFileName,selection,to!string(event.text));
						break;
					default: break;
				}
				break;
			default:
				switch(event.source){
					case "newfile":
						// create new filedialog to save the new file to the given location
						FileDialog fileDialog = new FileDialog("Create new XMP file", "xmpfiledialog", &actionEvent, [FileDialog.FileAssociationDescriptor("Extendible bitmap file", ["*.xmp"])], ".\\", true);
						parent.addWindow(fileDialog);
						break;
					case "loadfile":
						FileDialog fileDialog = new FileDialog("Load XMP file", "xmpload", &actionEvent, [FileDialog.FileAssociationDescriptor("Extendible bitmap file", ["*.xmp"])], ".\\", false);
						parent.addWindow(fileDialog);
						break;
					case "savefile":
						selection.saveFile();
						break;
					case "preview":
						if(preview !is null){
							if(previewModeOn){
								previewModeOn = false;
								previewWindow.close();
							}else{
								previewModeOn = true;

								previewWindow = new PreviewWindow(preview, viewer, this);
								parent.addWindow(previewWindow);
							}
						}
						break;
					case "inportnew":
						FileDialog fileDialog = new FileDialog("Import PNG/TGA/BMP", "importfile", &actionEvent, [FileDialog.FileAssociationDescriptor("All supported files", ["*.png","*.tga","*.bmp"]),
								FileDialog.FileAssociationDescriptor("Portable network graphics", ["*.png"]), FileDialog.FileAssociationDescriptor("Targa graphics file", ["*.tga"]),
								FileDialog.FileAssociationDescriptor("Windows bitmap", ["*.bmp"])], ".\\");
						parent.addWindow(fileDialog);
						break;
					case "inportmultiple":
						//parent.addWindow(new SpriteSheetDialog());
						FileDialog fileDialog = new FileDialog("Import PNG/TGA/BMP", "importmulti", &actionEvent, [FileDialog.FileAssociationDescriptor("All supported files", ["*.png","*.tga","*.bmp"]),
								FileDialog.FileAssociationDescriptor("Portable network graphics", ["*.png"]), FileDialog.FileAssociationDescriptor("Targa graphics file", ["*.tga"]),
								FileDialog.FileAssociationDescriptor("Windows bitmap", ["*.bmp"])], ".\\");
						parent.addWindow(fileDialog);
						break;
					case "imageList":
						//if(!selection.isEmpty){
						imageSelection = event.value;
							//update image information
							//preview = new Bitmap32Bit(selection.getBitmap(imageSelection),selection.getXsize(imageSelection),selection.getYsize(imageSelection));
							//writeln(preview);
						preview = getBitmapPreview(selection,selection.bitmapID[imageSelection]);
						//writeln(preview);
						//}
						break;
					case "paletteImport":
						FileDialog fileDialog = new FileDialog("Import Palette", "palettefile", &actionEvent, [FileDialog.FileAssociationDescriptor("All supported files", ["*.png","*.tga","*.bmp"]),
							FileDialog.FileAssociationDescriptor("Portable network graphics", ["*.png"]), FileDialog.FileAssociationDescriptor("Targa graphics file", ["*.tga"]),
							FileDialog.FileAssociationDescriptor("Windows bitmap", ["*.bmp"])], ".\\");
						parent.addWindow(fileDialog);
						break;
					case "remove":
						selection.removeBitmap(imageList.selection);
						updateImageList();
						break;
					default: break;
				}
				break;
		}
	}
	private void updateFileList(){

	}
	private void updateImageList(){

		ListBoxItem[] items;
		for(int i; i < selection.bitmapID.length; i++){
			items ~= new ListBoxItem([to!dstring(selection.bitmapID[i]),to!dstring(selection.bitdepth[i]),to!dstring(selection.format[i])
					,to!dstring(selection.paletteMode[i]), to!dstring(selection.getXsize(i)),to!dstring(selection.getYsize(i))]);
		}
		//imageList.updateColumns([ListBoxColumn("BitmapID",IDs),ListBoxColumn("Bitdepth",bt),ListBoxColumn("Format",form),ListBoxColumn("PalMode",pm)]);
		imageList.updateColumns(items);
		imageList.draw();
	}
	private void updateAnimationList(){
		//wstring[] IDs, frames;
		ListBoxItem[] items;
		foreach(s; selection.animData.byKey){
			items ~=  new ListBoxItem([to!dstring(s), to!dstring(selection.animData[s].ID.length)]);
		}
		animationList.updateColumns(items);
		animationList.draw();
	}
	private void updateFrameList(){
		//wstring[] num, IDs, dur;
		ListBoxItem[] items;
		for(int i ; i < selection.animData[animationSelection].ID.length ; i++){
			items ~=  new ListBoxItem([to!dstring(i), to!dstring(selection.animData[animationSelection].ID[i]), to!dstring(
					selection.animData[animationSelection].duration[i])]);
		}
		frameList.updateColumns(items);
		frameList.draw();
	}

}

interface SheetDialogListener{
	public void SheetDialogEvent(string a, string b, int numFrom, int numOfDigits, int x, int y, int bitdepth, NumberingStyle ns);
}

public class PreviewWindow : Window{
	Bitmap32Bit previewImage;
	ISpriteLayer spriteLayer;
	ConverterDialog cd;
	public this(Bitmap32Bit previewImage, ISpriteLayer spriteLayer, ConverterDialog cd){
		Coordinate size = Coordinate(0,0,previewImage.width > 78 ? previewImage.width + 2 : 80, previewImage.height + 18);
		super(size, "Preview");
		spriteLayer.addSprite(previewImage, -1, 2, 18);
		this.spriteLayer = spriteLayer;
		this.cd = cd;
	}

	public deprecated void actionEvent(Event event) {

	}

	override public void move(int x,int y) {
		spriteLayer.moveSprite(-1,x+2,y+18);
		super.move(x,y);
	}
	override public void relMove(int x,int y) {
		spriteLayer.relMoveSprite(-1,x,y);
		super.relMove(x,y);
	}
	override public void close() {
		spriteLayer.removeSprite(-1);
		cd.previewModeOn = false;
		super.close;
	}

}

