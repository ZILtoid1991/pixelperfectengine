/*
 * Copyright (C) 2016-2017, by Laszlo Szeremi under the Boost license.
 *
 * Pixel Perfect Editor, graphics.outputScreen module
 */

module editor;

import PixelPerfectEngine.graphics.outputScreen;
import PixelPerfectEngine.graphics.raster;
import PixelPerfectEngine.graphics.layers;
import PixelPerfectEngine.graphics.paletteMan;
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
import core.stdc.string : memcpy;
//import derelict.sdl2.sdl;
import bindbc.sdl;
import PixelPerfectEngine.concrete.window;
import PixelPerfectEngine.concrete.eventChainSystem;
import PixelPerfectEngine.map.mapformat;

//import converterdialog;
//import newLayerDialog;
import about;
import editorEvents;
public import layerlist;
public import materialList;
import document;
import rasterWindow;
import newTileLayer;

public interface IEditor{
	public void onExit();
	public void newDocument();
	//public void newLayer();
	public void xmpToolkit();
	public void passActionEvent(Event e);
	public void createNewDocument(dstring name, int rX, int rY);
	//public void createNewLayer(string name, int type, int tX, int tY, int mX, int mY, int priority);
}

public class NewDocumentDialog : Window{
	public IEditor ie;
	private TextBox[] textBoxes;
	public this(Coordinate size, dstring title){
		super(size, title);
	}
	public this(InputHandler inputhandler){
		this(Coordinate(10,10,220,150),"New Document"d);

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
		//textBoxes ~= new TextBox("","pal",Coordinate(121,80,200,99));
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
		ie.createNewDocument(textBoxes[0].getText(), to!int(textBoxes[1].getText()), to!int(textBoxes[2].getText()));

		parent.closeWindow(this);
	}
}

public class EditorWindowHandler : WindowHandler, ElementContainer{
	private WindowElement[] elements, mouseC, keyboardC, scrollC;
	//private ListBox layerList, prop;
	//private ListBoxColumn[] propTL, propSL, propSLE;
	//private ListBoxColumn[] layerListE;
	public Label[] labels;
	private int[] propTLW, propSLW, propSLEW;
	public Editor ie;
	//public bool layerList, materialList;
	public LayerList layerList;
	public MaterialList materialList;

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
		//openLayerList;
	}
	private void onLayerListClose(){
		layerList = null;
	}
	private void onMaterialListClose(){
		materialList = null;
	}
	public void clearArea(WindowElement sender){

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
		menuElements[2][0] = new PopUpMenuElement("layerList", "Layers", "Alt + L");
		menuElements[2][1] = new PopUpMenuElement("materialList", "Materials", "Alt + M");
		//menuElements[2][2] = new PopUpMenuElement("layerTools", "Layer tools", "Alt + T");

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
		//menuElements[4][2] = new PopUpMenuElement("bmfontimport", "Import BMFont File");

		menuElements ~= new PopUpMenuElement("help", "HELP");

		menuElements[5].setLength(2);
		menuElements[5][0] = new PopUpMenuElement("helpFile", "Content", "F1");
		menuElements[5][1] = new PopUpMenuElement("about", "About");


		MenuBar mb = new MenuBar("menubar",Coordinate(0,0,848,16),menuElements);
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
	public void openLayerList() {
		if(!layerList){
			layerList = new LayerList(0, 16, &onLayerListClose);
			addWindow(layerList);
		}
	}
	public void openMaterialList() {

		if(!materialList){
			materialList = new MaterialList(0, 16 + 213, &onMaterialListClose);
			//addWindow(new MaterialList(848 - 98, 16 + 213, &onMaterialListClose));
			addWindow(materialList);
		}
	}
	public void actionEvent(Event event){
		switch(event.source){
			case "exit":
				ie.onExit;
				break;
			case "new":
				ie.newDocument;
				break;
			case "xmpTool":
				break;
			case "about":
				Window w = new AboutWindow();
				addWindow(w);
				w.relMove(30,30);
				break;
			case "layerList":
				openLayerList;
					//addWindow(new LayerList(848 - 98, 16, &onLayerListClose));
				//layerList = true;
				break;
			case "materialList":
				openMaterialList;
				//materialList = true;
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

public class Editor : InputListener, MouseListener, IEditor, SystemEventListener {
	public OutputScreen[] ow;
	public Raster rasters;
	public InputHandler input;
	public wchar selectedTile;
	public BitmapAttrib selectedTileAttrib;
	public int selectedLayer;
	public SpriteLayer windowing;
	public SpriteLayer bitmapPreview;
	public bool onexit, exitDialog, newLayerDialog, mouseState, rasterRefresh;
	public Window test;
	public EditorWindowHandler wh;
	public EffectLayer selectionLayer;
	//public ForceFeedbackHandler ffb;
	//private uint[5] framecounter;
	public char[40] windowTitle;
	public ConfigurationProfile configFile;
	private int mouseX, mouseY;
	private Coordinate selection, selectedTiles;
	public PlacementMode pm;
	//public UndoableStack undoStack;
	public PaletteManager palman;
	public MapDocument[dstring] documents;
	public MapDocument selDoc;

	public void mouseButtonEvent(Uint32 which, Uint32 timestamp, Uint32 windowID, Uint8 button, Uint8 state, Uint8 clicks, Sint32 x, Sint32 y){

		setRasterRefresh;
	}
	public void mouseWheelEvent(uint type, uint timestamp, uint windowID, uint which, int x, int y, int wX, int wY){
		setRasterRefresh;
	}
	public void mouseMotionEvent(uint timestamp, uint windowID, uint which, uint state, int x, int y, int relX, int relY){
		setRasterRefresh;
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
				onLoad;
				break;
			case "save":
				onSave;
				break;
			case "saveAs":
				onSaveAs;
				break;
			case "undo":
				onUndo;
				break;
			case "redo":
				onRedo;
				break;
			default:
				break;
		}
	}
	public void keyReleased(string ID, Uint32 timestamp, Uint32 devicenumber, Uint32 devicetype){}
	public void passActionEvent(Event e){
		switch(e.source){
			case "save":
				onSave();
				break;
			case "saveAs":
				onSaveAs();
				break;
			case "load":
				onLoad();
				break;
			case "newLayer":
				//NewLayerDialog nld = new NewLayerDialog(this);
				//wh.addWindow(nld);
				break;
			case "layerTools":
				//TileLayerEditor tle = new TileLayerEditor(this);
				//wh.addWindow(tle);
				break;
			case "undo":
				onUndo();
				break;
			case "redo":
				onRedo();
				break;
			default: break;
		}
	}
	public void onUndo () {
		if(selDoc !is null){
			selDoc.events.undo;
			selDoc.outputWindow.updateRaster;
		}
	}
	public void onRedo () {
		if(selDoc !is null){
			selDoc.events.redo;
			selDoc.outputWindow.updateRaster;
		}
	}
	public void onLoad () {
		FileDialog fd = new FileDialog("Load document","docLoad",&onLoadDialog,[FileDialog.FileAssociationDescriptor(
			"PPE map file", ["*.xmf"])],".\\",false);
		wh.addWindow(fd);
	}
	public void onLoadDialog (Event event) {
		import std.utf : toUTF32;
		try {
			selDoc = new MapDocument(event.getFullPath);
			dstring name = toUTF32(selDoc.mainDoc.getName);
			RasterWindow w = new RasterWindow(selDoc.mainDoc.getHorizontalResolution, selDoc.mainDoc.getVerticalResolution, 
					rasters.palette.ptr, name, selDoc);
			selDoc.outputWindow = w;
			wh.addWindow(w);
			documents[name] = selDoc;
			selDoc.updateLayerList();
			selDoc.updateMaterialList();
			selDoc.mainDoc.loadTiles(w);
			selDoc.mainDoc.loadMappingData();
			w.loadLayers();
			w.updateRaster();
		} catch (Exception e) {
			debug writeln(e);
		}
		
	}
	public void onSave () {
		if (selDoc.filename) {
			selDoc.mainDoc.save(selDoc.filename);
		} else {
			onSaveAs();
		}
	}
	public void onSaveAs () {
		FileDialog fd = new FileDialog("Save document as","docSave",&onSaveDialog,[FileDialog.FileAssociationDescriptor(
			"PPE map file", ["*.xmf"])],".\\",true);
		wh.addWindow(fd);
	}
	public void onSaveDialog (Event event) {
		import std.path : extension;
		import std.ascii : toLower;
		selDoc.filename = event.getFullPath();
		if(extension(selDoc.filename) != ".xmf"){
			selDoc.filename ~= ".xmf";
		}
		selDoc.mainDoc.save(selDoc.filename);
	}
	public void actionEvent(Event event) {

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
						//document = new ExtendibleMap(path);
						break;
					default: break;
				}
				break;
			default:
				break;
		}
	}
	public void onQuit(){onExit();}
	public void controllerRemoved(uint ID){}
	public void controllerAdded(uint ID){}
	public void xmpToolkit(){
		//wh.addWindow(new ConverterDialog(input,bitmapPreview));
	}
	
	public this(string[] args){
		pm = PlacementMode.OVERWRITE;
		ConfigurationProfile.setVaultPath("ZILtoid1991","PixelPerfectEditor");
		configFile = new ConfigurationProfile();

		windowing = new SpriteLayer(LayerRenderingMode.ALPHA_BLENDING);
		bitmapPreview = new SpriteLayer();

		wh = new EditorWindowHandler(1696,960,848,480,windowing);
		wh.ie = this;

		//Initialize the Concrete framework
		INIT_CONCRETE(wh);
		//Initialize custom GUI elements
		{
			Bitmap8Bit[] customGUIElems = loadBitmapSheetFromFile!Bitmap8Bit("../system/concreteGUIE1.tga", 16, 16);
			WindowElement.styleSheet.setImage(customGUIElems[0], "menuButtonA");
			WindowElement.styleSheet.setImage(customGUIElems[1], "menuButtonB");
			WindowElement.styleSheet.setImage(customGUIElems[2], "fullSizeButtonA");
			WindowElement.styleSheet.setImage(customGUIElems[3], "fullSizeButtonB");
			WindowElement.styleSheet.setImage(customGUIElems[4], "smallSizeButtonA");
			WindowElement.styleSheet.setImage(customGUIElems[5], "smallSizeButtonB");
			WindowElement.styleSheet.setImage(customGUIElems[6], "newDocumentButtonA");
			WindowElement.styleSheet.setImage(customGUIElems[7], "newDocumentButtonB");
			WindowElement.styleSheet.setImage(customGUIElems[8], "saveDocumentButtonA");
			WindowElement.styleSheet.setImage(customGUIElems[9], "saveDocumentButtonB");
			WindowElement.styleSheet.setImage(customGUIElems[10], "loadDocumentButtonA");
			WindowElement.styleSheet.setImage(customGUIElems[11], "loadDocumentButtonB");
			WindowElement.styleSheet.setImage(customGUIElems[12], "settingsButtonA");
			WindowElement.styleSheet.setImage(customGUIElems[13], "settingsButtonB");
			WindowElement.styleSheet.setImage(customGUIElems[14], "blankButtonA");
			WindowElement.styleSheet.setImage(customGUIElems[15], "blankButtonB");
		}
		{
			Bitmap8Bit[] customGUIElems = loadBitmapSheetFromFile!Bitmap8Bit("../system/concreteGUIE4.tga", 16, 16);
			WindowElement.styleSheet.setImage(customGUIElems[0], "addMaterialA");
			WindowElement.styleSheet.setImage(customGUIElems[1], "addMaterialB");
			WindowElement.styleSheet.setImage(customGUIElems[2], "removeMaterialA");
			WindowElement.styleSheet.setImage(customGUIElems[3], "removeMaterialB");
			WindowElement.styleSheet.setImage(customGUIElems[4], "horizMirrorA");
			WindowElement.styleSheet.setImage(customGUIElems[5], "horizMirrorB");
			WindowElement.styleSheet.setImage(customGUIElems[6], "vertMirrorA");
			WindowElement.styleSheet.setImage(customGUIElems[7], "vertMirrorB");
			//WindowElement.styleSheet.setImage(customGUIElems[8], "");
			//WindowElement.styleSheet.setImage(customGUIElems[9], "");
			//WindowElement.styleSheet.setImage(customGUIElems[10], "");
			//WindowElement.styleSheet.setImage(customGUIElems[11], "");
			WindowElement.styleSheet.setImage(customGUIElems[12], "paletteDownA");
			WindowElement.styleSheet.setImage(customGUIElems[13], "paletteDownB");
			WindowElement.styleSheet.setImage(customGUIElems[14], "paletteUpA");
			WindowElement.styleSheet.setImage(customGUIElems[15], "paletteUpB");
		}
		{
			Bitmap8Bit[] customGUIElems = loadBitmapSheetFromFile!Bitmap8Bit("../system/concreteGUIE3.tga", 16, 16);
			WindowElement.styleSheet.setImage(customGUIElems[0], "trashButtonA");
			WindowElement.styleSheet.setImage(customGUIElems[1], "trashButtonB");
			WindowElement.styleSheet.setImage(customGUIElems[2], "visibilityButtonA");
			WindowElement.styleSheet.setImage(customGUIElems[3], "visibilityButtonB");
			WindowElement.styleSheet.setImage(customGUIElems[4], "newTileLayerButtonA");
			WindowElement.styleSheet.setImage(customGUIElems[5], "newTileLayerButtonB");
			WindowElement.styleSheet.setImage(customGUIElems[6], "newSpriteLayerButtonA");
			WindowElement.styleSheet.setImage(customGUIElems[7], "newSpriteLayerButtonB");
			WindowElement.styleSheet.setImage(customGUIElems[8], "newTransformableTileLayerButtonA");
			WindowElement.styleSheet.setImage(customGUIElems[9], "newTransformableTileLayerButtonB");
			WindowElement.styleSheet.setImage(customGUIElems[10], "importLayerDataButtonA");
			WindowElement.styleSheet.setImage(customGUIElems[11], "importLayerDataButtonB");
			WindowElement.styleSheet.setImage(customGUIElems[12], "importMaterialDataButtonA");
			WindowElement.styleSheet.setImage(customGUIElems[13], "importMaterialDataButtonB");
			WindowElement.styleSheet.setImage(customGUIElems[14], "paletteButtonA");
			WindowElement.styleSheet.setImage(customGUIElems[15], "paletteButtonB");
		}

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
		ow ~= new OutputScreen("Pixel Perfect Editor", 1696, 960);

		rasters = new Raster(848, 480, ow[0], 0);
		ow[0].setMainRaster(rasters);
		rasters.addLayer(windowing, 0);
		rasters.addLayer(bitmapPreview, 1);
		//ISSUE: Copying the palette from StyleSheet.defaultPaletteForGUI doesn't work
		//SOLUTION: Load the palette from a file
		rasters.palette = loadPaletteFromFile("../system/concreteGUIE1.tga");
		//rasters[0].addRefreshListener(ow[0],0);
		WindowElement.onDraw = &setRasterRefresh;
		PopUpElement.onDraw = &setRasterRefresh;
		Window.onDrawUpdate = &setRasterRefresh;
		wh.openLayerList;
		wh.openMaterialList;
	}
	/**
	 * Opens a window to aks the user for the data on the new tile layer
	 */
	public void initNewTileLayer(){
		wh.addWindow(new NewTileLayerDialog(this));
	}
	/**
	 * Creates a new tile layer with the given data.
	 *
	 * file: Optional field. If given, it specifies the external file for binary map data. If it specifies an already
	 * existing file, then that file will be loaded. If null, then the map data will be embedded as a BASE64 chunk.
	 * tmplt: Optional field. Specifies the initial tile source data from a map file alongside with the name of the layer
	 */
	public void newTileLayer(int tX, int tY, int mX, int mY, dstring name, string file, string tmplt, bool embed) {
		selDoc.events.addToTop(new CreateTileLayerEvent(selDoc, tX, tY, mX, mY, name, file, tmplt, embed));
	}
	public void setRasterRefresh(){
		rasterRefresh = true;
	}
	public void whereTheMagicHappens(){
		//rasters.refresh();
		while(!onexit){
			input.test();

			rasters.refresh();
			if (selDoc) {
				selDoc.contScrollLayer();
			}
		}
		//configFile.store();
	}
	public void onExit(){

		exitDialog=true;
		DefaultDialog dd = new DefaultDialog(Coordinate(10,10,220,75), "exitdialog","Exit application", ["Are you sure?"],
				["Yes","No","Pls save"],["ok","close","save"]);

		dd.output = &actionEvent;
		wh.addWindow(dd);

	}
	public void newDocument(){
		NewDocumentDialog ndd = new NewDocumentDialog(input);
		ndd.ie = this;
		wh.addWindow(ndd);
	}
	public void createNewDocument(dstring name, int rX, int rY){
		import std.utf : toUTF8;
		MapDocument md = new MapDocument(toUTF8(name), rX, rY);
		RasterWindow w = new RasterWindow(rX, rY, rasters.palette.ptr, name, md);
		md.outputWindow = w;
		wh.addWindow(w);
		documents[name] = md;
		selDoc = md;
	}
}
