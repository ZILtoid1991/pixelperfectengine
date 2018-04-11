/*
 * Copyright (C) 2016-2017, by Laszlo Szeremi under the Boost license.
 *
 * Pixel Perfect Editor, graphics.outputScreen module
 */

module editor;

import PixelPerfectEngine.graphics.outputScreen;
import PixelPerfectEngine.graphics.raster;
import PixelPerfectEngine.graphics.layers;
import PixelPerfectEngine.extbmp.extbmp;

import PixelPerfectEngine.graphics.bitmap;
import PixelPerfectEngine.graphics.draw;
//import collision;
import PixelPerfectEngine.system.inputHandler;
import PixelPerfectEngine.system.file;
import PixelPerfectEngine.system.etc;
import PixelPerfectEngine.system.config;
import PixelPerfectEngine.system.systemUtility;
import std.stdio;
import std.conv;
import derelict.sdl2.sdl;
import PixelPerfectEngine.concrete.window;
import PixelPerfectEngine.map.mapload;

import converterdialog;
import tileLayer;
import newLayerDialog;
import about;

public interface IEditor{
	public void onExit();
	public void newDocument();
	public void newLayer();
	public void xmpToolkit();
	public void passActionEvent(Event e);
	public void createNewDocument(wstring name, int rX, int rY, int pal);
	//public void createNewLayer(string name, int type, int tX, int tY, int mX, int mY, int priority);
}

public class NewDocumentDialog : Window{
	public IEditor ie;
	private TextBox[] textBoxes;
	public this(Coordinate size, wstring title){
		super(size, title);
	}
	public this(InputHandler inputhandler){
		this(Coordinate(10,10,220,150),"New Document");
		
		Button[] buttons;
		Label[] labels;
		buttons ~= new Button("Ok", "ok", Coordinate(150,110,200,130));

		labels ~= new Label("Name:","",Coordinate(5,20,80,39));
		labels ~= new Label("RasterX:","",Coordinate(5,40,80,59));
		labels ~= new Label("RasterY:","",Coordinate(5,60,80,79));
		labels ~= new Label("N. of colors:","",Coordinate(5,80,120,99));
		textBoxes ~= new TextBox("","name",Coordinate(81,20,200,39));
		textBoxes ~= new TextBox("","rX",Coordinate(121,40,200,59));
		textBoxes ~= new TextBox("","rY",Coordinate(121,60,200,79));
		textBoxes ~= new TextBox("","pal",Coordinate(121,80,200,99));
		addElement(buttons[0], EventProperties.MOUSE);
		foreach(WindowElement we; labels){
			addElement(we, EventProperties.MOUSE);
		}
		foreach(TextBox we; textBoxes){
			//we.addTextInputHandler(inputhandler);
			addElement(we, EventProperties.MOUSE);
		}
		buttons[0].onMouseLClickRel = &buttonOn_onMouseLClickRel;
	}

	public void buttonOn_onMouseLClickRel(Event event){
		ie.createNewDocument(textBoxes[0].getText(), to!int(textBoxes[1].getText()), to!int(textBoxes[2].getText()), to!int(textBoxes[3].getText()));
			
		parent.closeWindow(this);
	}
}

public class EditorWindowHandler : WindowHandler, ElementContainer{
	private WindowElement[] elements, mouseC, keyboardC, scrollC;
	private ListBox layerList, prop;
	//private ListBoxColumn[] propTL, propSL, propSLE;
	//private ListBoxColumn[] layerListE;
	public Label[] labels;
	private int[] propTLW, propSLW, propSLEW;
	public IEditor ie;

	//public InputHandler ih;

	private BitmapDrawer output;
	public this(int sx, int sy, int rx, int ry,ISpriteLayer sl){
		super(sx,sy,rx,ry,sl);
		output = new BitmapDrawer(rx, ry);
		addBackground(output.output);
		propTLW = [40, 320];
		propSLW = [160, 320, 48, 64];
		propSLEW = [160, 320, 40, 56];
		WindowElement.popUpHandler = this;
	}

	public void initGUI(){
		output.drawFilledRectangle(0, rasterX, 0, rasterY, 0x0005);
		
		PopUpMenuElement[] menuElements;
		menuElements ~= new PopUpMenuElement("file", "FILE");

		menuElements[0].setLength(7);
		menuElements[0][0] = new PopUpMenuElement("new", "New PPE map", "Ctrl + N");
		menuElements[0][1] = new PopUpMenuElement("newTemp", "New PPE map from template", "Ctrl + Shift + N");
		menuElements[0][2] = new PopUpMenuElement("load", "Load PPE map", "Ctrl + L");
		menuElements[0][3] = new PopUpMenuElement("save", "Save PPE map", "Ctrl + S");
		menuElements[0][4] = new PopUpMenuElement("saveAs", "Save PPE map as", "Ctrl + Shift + S");
		menuElements[0][5] = new PopUpMenuElement("saveTemp", "Save PPE map as template", "Ctrl + Shift + T");
		menuElements[0][6] = new PopUpMenuElement("exit", "Exit application", "Alt + F4");

		menuElements ~= new PopUpMenuElement("edit", "EDIT");
		
		menuElements[1].setLength(7);
		menuElements[1][0] = new PopUpMenuElement("undo", "Undo", "Ctrl + Z");
		menuElements[1][1] = new PopUpMenuElement("redo", "Redo", "Ctrl + Shift + Z");
		menuElements[1][2] = new PopUpMenuElement("copy", "Copy", "Ctrl + C");
		menuElements[1][3] = new PopUpMenuElement("cut", "Cut", "Ctrl + X");
		menuElements[1][4] = new PopUpMenuElement("paste", "Paste", "Ctrl + V");
		menuElements[1][5] = new PopUpMenuElement("editorSetup", "Editor Settings");
		menuElements[1][6] = new PopUpMenuElement("docSetup", "Document Settings");

		menuElements ~= new PopUpMenuElement("view", "VIEW");

		menuElements[2].setLength(2);
		menuElements[2][0] = new PopUpMenuElement("layerList", "Layer list", "Alt + L");
		menuElements[2][1] = new PopUpMenuElement("layerTools", "Layer tools", "Alt + T");

		menuElements ~= new PopUpMenuElement("layers", "LAYERS");

		menuElements[3].setLength(4);
		menuElements[3][0] = new PopUpMenuElement("newLayer", "New layer", "Alt + N");
		menuElements[3][1] = new PopUpMenuElement("delLayer", "Delete layer", "Alt + Del");
		menuElements[3][2] = new PopUpMenuElement("impLayer", "Import layer", "Alt + Shift + I");
		menuElements[3][3] = new PopUpMenuElement("layerSrc", "Layer resources", "Alt + R");

		menuElements ~= new PopUpMenuElement("tools", "TOOLS");

		menuElements[4].setLength(2);
		menuElements[4][0] = new PopUpMenuElement("xmpTool", "XMP Toolkit", "Alt + X");
		menuElements[4][1] = new PopUpMenuElement("mapXMLEdit", "Edit map as XML", "Ctrl + Alt + X");
		//menuElements[4][0] = new PopUpMenuElement("", "", "");

		menuElements ~= new PopUpMenuElement("help", "HELP");

		menuElements[5].setLength(2);
		menuElements[5][0] = new PopUpMenuElement("helpFile", "Content", "F1");
		menuElements[5][1] = new PopUpMenuElement("about", "About");
		
		//addElement(new Button("Exit","exit",Coordinate(550,80,630,100)), EventProperties.MOUSE);
		/*labels ~= new Label("Layer info:","null",Coordinate(5,395,101,415));
		labels ~= new Label("ScrollX:","null",Coordinate(5,415,70,435));
		labels ~= new Label("0","sx",Coordinate(71,415,140,435));
		labels ~= new Label("ScrollY:","null",Coordinate(145,415,210,435));
		labels ~= new Label("0","sy",Coordinate(211,415,280,435));
		labels ~= new Label("ScrollRateX:","null",Coordinate(281,415,378,435));
		labels ~= new Label("0","srx",Coordinate(379,415,420,435));
		labels ~= new Label("ScrollRateY:","null",Coordinate(421,415,518,435));
		labels ~= new Label("0","sry",Coordinate(519,415,560,435));
		labels ~= new Label("MapX:","null",Coordinate(5,435,45,455));
		labels ~= new Label("0","mx",Coordinate(46,435,100,455));
		labels ~= new Label("MapY:","null",Coordinate(105,435,145,455));
		labels ~= new Label("0","my",Coordinate(146,435,200,455));
		labels ~= new Label("TileX:","null",Coordinate(205,435,255,455));
		labels ~= new Label("0","tx",Coordinate(256,435,310,455));
		labels ~= new Label("TileY:","null",Coordinate(315,435,365,455));
		labels ~= new Label("0","ty",Coordinate(366,435,420,455));*/
		MenuBar mb = new MenuBar("menubar",Coordinate(0,0,640,16),menuElements);
		addElement(mb, EventProperties.MOUSE);
		mb.onMouseLClickPre = &actionEvent;
		foreach(WindowElement we; labels){
			addElement(we, 0);
		}
		foreach(WindowElement we; elements){
			we.draw();
		}
	}

	public override StyleSheet getStyleSheet(){
		return defaultStyle;
	}

	public void addElement(WindowElement we, int eventProperties){
		elements ~= we;
		we.elementContainer = this;
		//we.al ~= this;
		if((eventProperties & EventProperties.KEYBOARD) == EventProperties.KEYBOARD){
			keyboardC ~= we;
		}
		if((eventProperties & EventProperties.MOUSE) == EventProperties.MOUSE){
			mouseC ~= we;
		}
		if((eventProperties & EventProperties.SCROLL) == EventProperties.SCROLL){
			scrollC ~= we;
		}
	}

	
	public void actionEvent(Event event){
		writeln(event.source);
		switch(event.source){
			case "exit":
				ie.onExit;
				break;
			case "new":
				ie.newDocument;
				break;
			case "newL":
				ie.newLayer;
				break;
			case "xmpTool":
				ie.xmpToolkit();
				break;
			case "about":
				Window w = new AboutWindow();
				addWindow(w);
				w.relMove(30,30);
				break;
			default:
				ie.passActionEvent(event);
				break;
		}
	}
	
	public override void drawUpdate(WindowElement sender){
		output.insertBitmap(sender.getPosition().left,sender.getPosition().top,sender.output.output);
	}
	
	override public void passMouseEvent(int x,int y,int state,ubyte button) {
		foreach(WindowElement e; mouseC){
			if(e.getPosition().left < x && e.getPosition().right > x && e.getPosition().top < y && e.getPosition().bottom > y){
				e.onClick(x - e.getPosition().left, y - e.getPosition().top, state, button);
				return;
			}
		}
	}
	public override void passScrollEvent(int wX, int wY, int x, int y){
		foreach(WindowElement e; scrollC){
			if(e.getPosition().left < wX && e.getPosition().right > wX && e.getPosition().top < wX && e.getPosition().bottom > wY){
				
				e.onScroll(y, x, wX, wY);

				return;
			}
		}
	}
	public Coordinate getAbsolutePosition(WindowElement sender){
		return sender.position;
	}
}

public enum PlacementMode : uint{
	NULL		=	0,
	NORMAL		=	1,
	VOIDFILL	=	2,
	OVERWRITE	=	3,

}

public class Editor : InputListener, MouseListener, IEditor, SystemEventListener, NewLayerDialogListener{
	public OutputScreen[] ow;
	public Raster[] rasters;
	public InputHandler input;
	public TileLayer[int] backgroundLayers;
	//public TileLayer8Bit[int] backgroundLayers8;
	//public TileLayer32Bit[int] backgroundLayers32;
	public Layer[int] layers;
	public wchar selectedTile;
	public BitmapAttrib selectedTileAttrib;
	public int selectedLayer;
	public SpriteLayer windowing;
	public SpriteLayer bitmapPreview;
	public bool onexit, exitDialog, newLayerDialog, mouseState;
	public WindowElement[] elements;
	public Window test;
	public EditorWindowHandler wh;
	public ExtendibleMap document;
	public EffectLayer selectionLayer;
	//public ForceFeedbackHandler ffb;
	private uint[5] framecounter;
	public char[40] windowTitle;
	public ConfigurationProfile configFile;
	private int mouseX, mouseY;
	private Coordinate selection, selectedTiles;
	public PlacementMode pm;

	public void mouseButtonEvent(Uint32 which, Uint32 timestamp, Uint32 windowID, Uint8 button, Uint8 state, Uint8 clicks, Sint32 x, Sint32 y){
		//writeln(windowID);
		x /= 2;
		y /= 2;
		if(windowID == 2){
			if(button == MouseButton.LEFT){//placement
				if(state == ButtonState.PRESSED && !mouseState){
					mouseX = x;
					mouseY = y;
					mouseState = true;
				}else if(mouseState){
					mouseState = false;
					if(mouseX == x && mouseY == y){//placement
						if(layers[selectedLayer].classinfo == typeid(TileLayer)){
							TileLayer tl = cast(TileLayer)(layers[selectedLayer]);
							int targetX = (x + tl.getSX()) / tl.getTileWidth();
							int targetY = (y + tl.getSY()) / tl.getTileHeight();
							if(targetX >= 0 && targetY >= 0 && targetX < tl.getMX && targetY < tl.getMY){
								if(pm == PlacementMode.NORMAL || (pm == PlacementMode.VOIDFILL && tl.readMapping(targetX,targetY) == 0xFFFF
															|| (pm == PlacementMode.OVERWRITE && tl.readMapping(targetX,targetY) != 0xFFFF))){
									tl.writeMapping(targetX,targetY,selectedTile);
									tl.writeTileAttribute(targetX,targetY,selectedTileAttrib);
									document.tld[selectedLayer].mapping.writeMapping(targetX,targetY,selectedTile,selectedTileAttrib);
								}
							}
						}else{//sprite placement
							
						}
					}else{		//select or region fill
						Coordinate c = Coordinate();
						if(mouseX>x){
							c.left = x;
							c.right = mouseX;
						}else{
							c.left = mouseX;
							c.right = x;
						}
						if(mouseY>y){
							c.top = y;
							c.bottom = mouseY;
						}else{
							c.top = mouseY;
							c.bottom = y;
						}
						if(layers[selectedLayer].classinfo == typeid(TileLayer)){
							TileLayer tl = cast(TileLayer)(layers[selectedLayer]);
							c.left = (c.left + tl.getSX()) / tl.getTileWidth();
							c.right = (c.right + tl.getSX()) / tl.getTileWidth();
							c.top = (c.top + tl.getSY()) / tl.getTileHeight();
							c.bottom = (c.bottom + tl.getSY()) / tl.getTileHeight();
							for(int iY = c.top ; iY < c.bottom ; iY++){
								for(int iX = c.left ; iX < c.right ; iX++){
									if(pm == PlacementMode.NORMAL || (pm == PlacementMode.VOIDFILL && tl.readMapping(iX,iY) == 0xFFFF
																|| (pm == PlacementMode.OVERWRITE && tl.readMapping(iX,iY) != 0xFFFF))){
										tl.writeMapping(iX,iY,selectedTile);
										tl.writeTileAttribute(iX,iY,selectedTileAttrib);
										document.tld[selectedLayer].mapping.writeMapping(iX,iY,selectedTile,selectedTileAttrib);
									}
								}
							}
						}
					}
				}
			}else if(button == MouseButton.MID && pm != PlacementMode.NULL){//deletion
				
			}
		}
	}
	public void mouseWheelEvent(uint type, uint timestamp, uint windowID, uint which, int x, int y, int wX, int wY){}
	public void mouseMotionEvent(uint timestamp, uint windowID, uint which, uint state, int x, int y, int relX, int relY){
	
	}
	public void keyPressed(string ID, Uint32 timestamp, Uint32 devicenumber, Uint32 devicetype){
		switch(ID){
			case "nextLayer":
				break;
			case "prevLayer":
				break;
			case "scrollUp":
				break;
			case "scrollDown":
				break;
			case "scrollLeft":
				break;
			case "scrollRight":
				break;
			case "quit":
				break;
			case "xmpTool":
				break;
			case "load":
				break;
			case "save":
				break;
			case "saveAs":
				break;
			default:
				break;
		}
	}
	public void keyReleased(string ID, Uint32 timestamp, Uint32 devicenumber, Uint32 devicetype){}
	public void passActionEvent(Event e){
		switch(e.source){
			case "saveas": 
				FileDialog fd = new FileDialog("Save document as","docSave",&actionEvent,[FileDialog.FileAssociationDescriptor("PPE map file", ["*.xmf"])],".\\",true);
				wh.addWindow(fd);
				break;
			case "load":
				FileDialog fd = new FileDialog("Load document","docLoad",&actionEvent,[FileDialog.FileAssociationDescriptor("PPE map file", ["*.xmf"])],".\\",false);
				wh.addWindow(fd);
				break;
			default: break;
		}
	}
	/*public void actionEvent(string source, int type, int value, wstring message){
		writeln(source);

		if(source == "file"){
			writeln(message);
		}
	}
	public void actionEvent(string source, string subSource, int type, int value, wstring message){
		switch(subSource){
			case "exitdialog":
				if(source == "Yes"){
					onexit = true;
				}
				break;
			default: break;
		}
	}*/
	public void actionEvent(Event event){
		//writeln(event.subsource);
		switch(event.subsource){
			case "exitdialog":
				if(event.source == "ok"){
					onexit = true;
				}
				break;
			case FileDialog.subsourceID:
				switch(event.source){
					case "docSave":
						break;
					case "docLoad":
						string path = event.path;
						path ~= event.filename;
						document = new ExtendibleMap(path);
						break;
					default: break;
				}
				break;
			default:
				break;
		}
	}
	public void onQuit(){onexit = !onexit;}
	public void controllerRemoved(uint ID){}
	public void controllerAdded(uint ID){}
	public void xmpToolkit(){
		wh.addWindow(new ConverterDialog(input,bitmapPreview));
	}
	public void placeObject(int x, int y){
		if(backgroundLayers.get(selectedLayer, null) !is null){
			int sX = backgroundLayers[selectedLayer].getSX(), sY = backgroundLayers[selectedLayer].getSY();
			sX += x;
			sY += y;
			sX /= backgroundLayers[selectedLayer].getTileWidth();
			sY /= backgroundLayers[selectedLayer].getTileHeight();
			if(sX >= 0 && sY >= 0){
				backgroundLayers[selectedLayer].writeMapping(sX, sY, selectedTile);
			}
		}
	}
	public this(string[] args){
		pm = PlacementMode.OVERWRITE;
		ConfigurationProfile.setVaultPath("ZILtoid1991","PixelPerfectEditor");
		configFile = new ConfigurationProfile();

		windowing = new SpriteLayer(LayerRenderingMode.COPY);
		bitmapPreview = new SpriteLayer();

		wh = new EditorWindowHandler(1280,960,640,480,windowing);
		wh.ie = this;

		//Initialize the Concrete framework
		INIT_CONCRETE(wh);
		

		wh.initGUI();

		input = new InputHandler();
		input.ml ~= this;
		input.ml ~= wh;
		input.il ~= this;
		input.sel ~= this;
		input.kb ~= KeyBinding(0, SDL_SCANCODE_ESCAPE, 0, "sysesc", Devicetype.KEYBOARD);
		WindowElement.inputHandler = input;
		//wh.ih = input;
		//ffb = new ForceFeedbackHandler(input);

		//OutputWindow.setScalingQuality("2");
		//OutputWindow.setDriver("software");
		ow ~= new OutputScreen("Pixel Perfect Editor", 1280, 960);

		rasters ~= new Raster(640, 480, ow[0]);
		ow[0].setMainRaster(rasters[0]);
		rasters[0].addLayer(windowing, 0);
		rasters[0].addLayer(bitmapPreview, 1);
		//rasters[0].setupPalette(512);
		//loadPaletteFromFile("VDPeditUI0.pal", guiR);
		//load24bitPaletteFromFile("VDPeditUI0.pal", rasters[0]);
		//loadPaletteFromXMP(ssOrigin, "default", rasters[0]);
		//foreach(c ; StyleSheet.defaultpaletteforGUI)
		rasters[0].palette ~= [Color(0x00,0x00,0x00,0x00),Color(0xFF,0xFF,0xFF,0xFF),Color(0xFF,0x34,0x9e,0xff),Color(0xff,0xa2,0xd7,0xff),	
		Color(0xff,0x00,0x2c,0x59),Color(0xff,0x00,0x75,0xe7),Color(0xff,0xff,0x00,0x00),Color(0xFF,0x7F,0x00,0x00),
		Color(0xFF,0x00,0xFF,0x00),Color(0xFF,0x00,0x7F,0x00),Color(0xFF,0x00,0x00,0xFF),Color(0xFF,0x00,0x00,0x7F),
		Color(0xFF,0xFF,0xFF,0x00),Color(0xFF,0xFF,0x7F,0x00),Color(0xFF,0x7F,0x7F,0x7F),Color(0xFF,0x00,0x00,0x00)];// StyleSheet.defaultpaletteforGUI;
		//writeln(rasters[0].palette);
		//rasters[0].addRefreshListener(ow[0],0);

	}
	/**
	 * Writes a singe element to a TileLayer
	 */
	public void writeToTileLayer(int x, int y, int num, wchar c, BitmapAttrib b){
		//update the mapfile
		document.tld[num].mapping.writeMapping(x,y,c,b);
		//update the tilelayer
		backgroundLayers[num].writeMapping(x,y,c);
		backgroundLayers[num].writeTileAttribute(x,y,b);
	}
	/**
	 * Writes an area always
	 */
	public void writeAreaWithOverride(int left, int top, int right, int bottom, int num, wchar c, BitmapAttrib b){
		for(int y = top ; y < bottom ; y++){
			for(int x = left ; x < right ; x++){
				writeToTileLayer(x,y,num,c,b);
			}
		}
	}
	/**
	 * Writes an area if c = 0xFFFF
	 */
	public void writeAreaWithoutOverride(int left, int top, int right, int bottom, int num, wchar c, BitmapAttrib b){
		for(int y = top ; y < bottom ; y++){
			for(int x = left ; x < right ; x++){
				if(backgroundLayers[num].readMapping(x,y) == 0xFFFF)
					writeToTileLayer(x,y,num,c,b);
			}
		}
	}
	public void whereTheMagicHappens(){
		while(!onexit){
			input.test();

			rasters[0].refresh();
			if(rasters.length == 2){
				rasters[1].refresh();
			}
			//rudamentaryFrameCounter();
			//onexit = true;
		}
		configFile.store();
	}
	public void onExit(){

		exitDialog=true;
		DefaultDialog dd = new DefaultDialog(Coordinate(10,10,220,75), "exitdialog","Exit application", ["Are you sure?"],["Yes","No","Pls save"],["ok","close","save"]);

		dd.output = &actionEvent;
		wh.addWindow(dd);

	}
	public void newDocument(){
		NewDocumentDialog ndd = new NewDocumentDialog(input);
		ndd.ie = this;
		wh.addWindow(ndd);
	}
	public void createNewDocument(wstring name, int rX, int rY, int pal){
		ow ~= new OutputScreen("Edit window", to!ushort(rX*2),to!ushort(rY*2));
		rasters ~= new Raster(to!ushort(rX), to!ushort(rY), ow[1]);
		rasters[1].setupPalette(pal);
		ow[1].setMainRaster(rasters[1]);
		selectionLayer = new EffectLayer();
		rasters[1].addLayer(selectionLayer, 65536);
		document = new ExtendibleMap();
		document.metaData["name"] = to!string(name);
		document.metaData["rX"] = to!string(rX);
		document.metaData["rY"] = to!string(rY);
		document.metaData["pal"] = to!string(pal);
	}
	
	public void newLayer(){
		if(document !is null){
			NewLayerDialog ndd = new NewLayerDialog(this);
			wh.addWindow(ndd);
		}
	}
	private void updateLayerList(){

	}
	public void newTileLayerEvent(string name, string file, bool embed, bool preexisting, int tX, int tY, int mX, int mY){
		import std.path;
		TileLayer tl = new TileLayer(tX, tY, LayerRenderingMode.ALPHA_BLENDING);
		
		while(layers.get(selectedLayer, null)){
			selectedLayer++;
		}
		TileLayerData tld;
		if(preexisting && !embed){
			tld = new TileLayerData(tX, tY, mX, mY, 1.0, 1.0, selectedLayer, MapData.load(file), name);
		}else if(!preexisting && embed){
			tld = new TileLayerData(tX, tY, mX, mY, 1.0, 1.0, selectedLayer, name);
		}else if(!preexisting && !embed){
			tld = new TileLayerData(tX, tY, mX, mY, 1.0, 1.0, selectedLayer, name);
			tld.mapping.save(file);
		}else if(extension(file) == ".xmf"){
			wh.messageWindow("Error"w, "Function of importing embedded mapping from *.xmf files not yet implemented"w, 320);
			return;
		}
		tld.isEmbedded = embed;
		tl.loadMapping(mX,mY,tld.mapping.getCharMapping(),tld.mapping.getAttribMapping());
		layers[selectedLayer] = tl;
		if(rasters.length > 1){
			rasters[1].addLayer(tl,selectedLayer);
		}
	}
	public void newSpriteLayerEvent(string name){
		SpriteLayer sl = new SpriteLayer();
		
		while(layers.get(selectedLayer, null)){
			selectedLayer++;
		}
		SpriteLayerData sld = new SpriteLayerData(name, 1.0, 1.0, selectedLayer);
		layers[selectedLayer] = sl;
		if(rasters.length > 1){
			rasters[1].addLayer(sl,selectedLayer);
		}
	}
	public void importTileLayerSymbolData(string file){
	
	}
	public int getPreviousTileLayer(int pri){
		import std.algorithm.sorting;
		int[] list = document.tld.keys;
		list.sort();
		int n, i;
		for( ; i < list.length ; i++){
			if(pri == list[i]){
				n = list[i];
				break;
			}
		}
		selectedLayer--;
		if(i == 0){
			return n;
		}else{
			return list[i - 1];
		}
	}
	public int getNextTileLayer(int pri){
		import std.algorithm.sorting;
		int[] list = document.tld.keys;
		list.sort();
		int n, i;
		for( ; i < list.length ; i++){
			if(pri == list[i]){
				n = list[i];
				break;
			}
		}
		selectedLayer++;
		if(i == list.length - 1){
			return n;
		}else{
			return list[i + 1];
		}
	}
	public int moveLayerDown(int pri){
		selectedLayer--;
		import std.algorithm.sorting;
		int[] list = layers.keys;
		list.sort();
		int n, i;
		for( ; i < list.length ; i++){
			if(pri == list[i]){
				n = list[i];
				break;
			}
		}
		if(i == 0){
			Layer l = layers[n];
			layers[n] = layers[n - 1];
			if(document.tld.get(n, null)){
				document.tld[n - 1] = document.tld[n];
				document.tld.remove(n);
				document.tld[n - 1].priority -= 1;
			}else{
				document.sld[n - 1] = document.sld[n];
				document.sld.remove(n);
				document.sld[n - 1].priority -= 1;
			}
			n--;
			return n;
		}
		if(list[i - 1] == n - 1){	//swap two layers
			Layer l = layers[n];
			layers[n] = layers[n - 1];
			if(document.tld.get(n, null)){
				document.tld[n - 1] = document.tld[n];
				document.tld.remove(n);
				document.tld[n - 1].priority -= 1;
			}else{
				document.sld[n - 1] = document.sld[n];
				document.sld.remove(n);
				document.sld[n - 1].priority -= 1;
			}
			n--;
			layers[n] = l;
			if(document.tld.get(n, null)){
				document.tld[n + 1] = document.tld[n];
				document.tld.remove(n);
				document.tld[n + 1].priority += 1;
			}else{
				document.sld[n + 1] = document.sld[n];
				document.sld.remove(n);
				document.sld[n + 1].priority += 1;
			}
		}else{						//lower the priority of the current layer
			Layer l = layers[n];
			layers.remove(n);
			if(document.tld.get(n, null)){
				document.tld[n - 1] = document.tld[n];
				document.tld.remove(n);
				document.tld[n - 1].priority -= 1;
			}else{
				document.sld[n - 1] = document.sld[n];
				document.sld.remove(n);
				document.sld[n - 1].priority -= 1;
			}
			n--;
			layers[n] = l;
			
		}
		return n;
	}
	public int moveLayerUp(int pri){
		selectedLayer++;
		import std.algorithm.sorting;
		int[] list = layers.keys;
		list.sort();
		int n, i;
		for( ; i < list.length ; i++){
			if(pri == list[i]){
				n = list[i];
				break;
			}
		}
		if(i == list.length - 1){
			Layer l = layers[n];
			layers[n] = layers[n - 1];
			if(document.tld.get(n, null)){
				document.tld[n - 1] = document.tld[n];
				document.tld.remove(n);
				document.tld[n - 1].priority -= 1;
			}else{
				document.sld[n - 1] = document.sld[n];
				document.sld.remove(n);
				document.sld[n - 1].priority -= 1;
			}
			n--;
			return n;
		}
		if(list[i + 1] == n + 1){	//swap two layers
			Layer l = layers[n];
			layers[n] = layers[n + 1];
			if(document.tld.get(n, null)){
				document.tld[n + 1] = document.tld[n];
				document.tld.remove(n);
				document.tld[n + 1].priority += 1;
			}else{
				document.sld[n + 1] = document.sld[n];
				document.sld.remove(n);
				document.sld[n + 1].priority += 1;
			}
			n++;
			layers[n] = l;
			if(document.tld.get(n, null)){
				document.tld[n - 1] = document.tld[n];
				document.tld.remove(n);
				document.tld[n - 1].priority -= 1;
			}else{
				document.sld[n - 1] = document.sld[n];
				document.sld.remove(n);
				document.sld[n - 1].priority -= 1;
			}
		}else{						//higher the priority of the current layer
			Layer l = layers[n];
			layers.remove(n);
			if(document.tld.get(n, null)){
				document.tld[n + 1] = document.tld[n];
				document.tld.remove(n);
				document.tld[n + 1].priority += 1;
			}else{
				document.sld[n + 1] = document.sld[n];
				document.sld.remove(n);
				document.sld[n + 1].priority += 1;
			}
			n++;
			layers[n] = l;
			
		}
		return n;
	}
}