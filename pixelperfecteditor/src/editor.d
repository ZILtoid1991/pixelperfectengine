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
//import PixelPerfectEngine.extbmp.extbmp;

import PixelPerfectEngine.graphics.bitmap;
import PixelPerfectEngine.graphics.draw;
//import collision;
import PixelPerfectEngine.system.input;
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
import windows.resizemap;
import windows.about;
import editorevents;
public import windows.layerlist;
public import windows.materiallist;
import document;
import windows.rasterwindow;
import windows.newtilelayer;

/+public interface IEditor{
	public void onExit();
	public void newDocument();
	public void passActionEvent(Event e);
	public void createNewDocument(dstring name, int rX, int rY);
}+/

public class NewDocumentDialog : Window{
	public Editor ie;
	private TextBox[] textBoxes;
	public this(Coordinate size, dstring title){
		super(size, title);
	}
	public this(InputHandler inputhandler){
		this(Box(10,10,220,150),"New Document"d);

		Button[] buttons;
		Label[] labels;
		buttons ~= new Button("Ok", "ok", Box(150,110,200,130));

		labels ~= new Label("Name:","",Box(5,20,80,39));
		labels ~= new Label("RasterX:","",Box(5,40,80,59));
		labels ~= new Label("RasterY:","",Box(5,60,80,79));
		//labels ~= new Label("N. of colors:","",Coordinate(5,80,120,99));
		textBoxes ~= new TextBox("","name",Box(81,20,200,39));
		textBoxes ~= new TextBox("","rX",Box(121,40,200,59));
		textBoxes ~= new TextBox("","rY",Box(121,60,200,79));
		//textBoxes ~= new TextBox("","pal",Coordinate(121,80,200,99));
		addElement(buttons[0]);
		foreach(WindowElement we; labels){
			addElement(we);
		}
		foreach(TextBox we; textBoxes){
			//we.addTextInputHandler(inputhandler);
			addElement(we);
		}
		buttons[0].onMouseLClick = &buttonOn_onMouseLClickRel;
	}

	public void buttonOn_onMouseLClickRel(Event event){
		ie.createNewDocument(textBoxes[0].getText().text, to!int(textBoxes[1].getText().text), to!int(textBoxes[2].getText().text));

		close();
	}
}

public class TopLevelWindow : Window {
	public this(int width, int height) {
		Text mt(dstring text) @safe nothrow {
			return new Text(text, globalDefaultStyle.getChrFormatting("menuBar"));
		}
		super(Box(0, 0, width, height), ""d, [], null);
		MenuBar mb;
		{
			PopUpMenuElement[] menuElements;
			menuElements ~= new PopUpMenuElement("file", mt("FILE"));

			menuElements[0].setLength(7);
			menuElements[0][0] = new PopUpMenuElement("new", "New PPE map");
			menuElements[0][1] = new PopUpMenuElement("newTemp", "New PPE map from template");
			menuElements[0][2] = new PopUpMenuElement("load", "Load PPE map");
			menuElements[0][3] = new PopUpMenuElement("save", "Save PPE map");
			menuElements[0][4] = new PopUpMenuElement("saveAs", "Save PPE map as");
			menuElements[0][5] = new PopUpMenuElement("saveTemp", "Save PPE map as template");
			menuElements[0][6] = new PopUpMenuElement("exit", "Exit application");

			menuElements ~= new PopUpMenuElement("edit", mt("EDIT"));

			menuElements[1].setLength(7);
			menuElements[1][0] = new PopUpMenuElement("undo", "Undo");
			menuElements[1][1] = new PopUpMenuElement("redo", "Redo");
			menuElements[1][2] = new PopUpMenuElement("copy", "Copy");
			menuElements[1][3] = new PopUpMenuElement("cut", "Cut");
			menuElements[1][4] = new PopUpMenuElement("paste", "Paste");
			menuElements[1][5] = new PopUpMenuElement("editorSetup", "Editor settings");
			menuElements[1][6] = new PopUpMenuElement("docSetup", "Document settings");

			menuElements ~= new PopUpMenuElement("view", mt("VIEW"));

			menuElements[2].setLength(2);
			menuElements[2][0] = new PopUpMenuElement("layerList", "Layers");
			menuElements[2][1] = new PopUpMenuElement("materialList", "Materials");
			//menuElements[2][2] = new PopUpMenuElement("layerTools", "Layer tools", "Alt + T");

			menuElements ~= new PopUpMenuElement("layers", mt("LAYERS"));

			menuElements[3].setLength(5);
			menuElements[3][0] = new PopUpMenuElement("newLayer", "New layer");
			menuElements[3][1] = new PopUpMenuElement("delLayer", "Delete layer");
			menuElements[3][2] = new PopUpMenuElement("impLayer", "Import layer");
			menuElements[3][3] = new PopUpMenuElement("layerSrc", "Layer resources");
			menuElements[3][4] = new PopUpMenuElement("resizeLayer", "Resize layer");

			menuElements ~= new PopUpMenuElement("tools", mt("TOOLS"));

			menuElements[4].setLength(2);
			menuElements[4][0] = new PopUpMenuElement("tgaTool", "TGA Toolkit");
			menuElements[4][1] = new PopUpMenuElement("bmfontTool", "BMFont Toolkit");

			menuElements ~= new PopUpMenuElement("help", mt("HELP"));

			menuElements[5].setLength(2);
			menuElements[5][0] = new PopUpMenuElement("helpFile", "Content");
			menuElements[5][1] = new PopUpMenuElement("about", "About");

			mb = new MenuBar("mb", Box(0,0, width, 16), menuElements);
		}
		addElement(mb);
	}
	public override void draw(bool drawHeaderOnly = false) {
		output.drawFilledBox(position, 0);
		foreach (WindowElement we; elements) {
			we.draw();
		}
	}
	public override void drawHeader() {

	}
	///Passes mouse click event
	public override void passMCE(MouseEventCommons mec, MouseClickEvent mce) {
		lastMousePos = Point(mce.x - position.left, mce.y - position.top);
		foreach (WindowElement we; elements) {
			if (we.getPosition.isBetween(lastMousePos)) {
				lastMouseEventTarget = we;
				mce.x = lastMousePos.x;
				mce.y = lastMousePos.y;
				we.passMCE(mec, mce);
				return;
			}
		}
		foreach (ISmallButton sb; smallButtons) {
			WindowElement we = cast(WindowElement)sb;
			if (we.getPosition.isBetween(lastMousePos)) {
				lastMouseEventTarget = we;
				mce.x = lastMousePos.x;
				mce.y = lastMousePos.y;
				we.passMCE(mec, mce);
				return;
			}
		}
		lastMouseEventTarget = null;
	}
	///Passes mouse move event
	public override void passMME(MouseEventCommons mec, MouseMotionEvent mme) {
		lastMousePos = Point(mme.x - position.left, mme.y - position.top);
		if (lastMouseEventTarget) {
			mme.x = lastMousePos.x;
			mme.y = lastMousePos.y;
			lastMouseEventTarget.passMME(mec, mme);
			if (!lastMouseEventTarget.getPosition.isBetween(mme.x, mme.y)) {
				lastMouseEventTarget = null;
			}
		} else {
			foreach (WindowElement we; elements) {
				if (we.getPosition.isBetween(lastMousePos)) {
					lastMouseEventTarget = we;
					mme.x = lastMousePos.x;
					mme.y = lastMousePos.y;
					we.passMME(mec, mme);
					return;
				}
			}
		}
	}
}
/+public enum PlacementMode : uint{
	NULL		=	0,
	NORMAL		=	1,
	VOIDFILL	=	2,
	OVERWRITE	=	3,

}+/

public class Editor : InputListener, SystemEventListener {
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
	public WindowHandler wh;
	//public EffectLayer selectionLayer;
	//public ForceFeedbackHandler ffb;
	//private uint[5] framecounter;
	public char[40] windowTitle;
	public ConfigurationProfile configFile;
	private int mouseX, mouseY;
	private Coordinate selection, selectedTiles;
	//public PlacementMode pm;
	//public UndoableStack undoStack;
	public PaletteManager palman;
	public MapDocument[dstring] documents;
	public MapDocument selDoc;
	public LayerList layerList;
	public MaterialList materialList;
	
public this(string[] args){
		ConfigurationProfile.setVaultPath("ZILtoid1991","PixelPerfectEditor");
		//configFile = new ConfigurationProfile();

		windowing = new SpriteLayer(RenderingMode.Copy);
		bitmapPreview = new SpriteLayer();

		wh = new WindowHandler(1696,960,848,480,windowing);
		//wh.ie = this;

		//Initialize the Concrete framework
		INIT_CONCRETE(wh);
		writeln(globalDefaultStyle.drawParameters);
		//Initialize custom GUI elements
		{
			Bitmap8Bit[] customGUIElems = loadBitmapSheetFromFile!Bitmap8Bit("../system/concreteGUIE1.tga", 16, 16);
			globalDefaultStyle.setImage(customGUIElems[0], "menuButtonA");
			globalDefaultStyle.setImage(customGUIElems[1], "menuButtonB");
			globalDefaultStyle.setImage(customGUIElems[2], "fullSizeButtonA");
			globalDefaultStyle.setImage(customGUIElems[3], "fullSizeButtonB");
			globalDefaultStyle.setImage(customGUIElems[4], "smallSizeButtonA");
			globalDefaultStyle.setImage(customGUIElems[5], "smallSizeButtonB");
			globalDefaultStyle.setImage(customGUIElems[6], "newDocumentButtonA");
			globalDefaultStyle.setImage(customGUIElems[7], "newDocumentButtonB");
			globalDefaultStyle.setImage(customGUIElems[8], "saveDocumentButtonA");
			globalDefaultStyle.setImage(customGUIElems[9], "saveDocumentButtonB");
			globalDefaultStyle.setImage(customGUIElems[10], "loadDocumentButtonA");
			globalDefaultStyle.setImage(customGUIElems[11], "loadDocumentButtonB");
			globalDefaultStyle.setImage(customGUIElems[12], "settingsButtonA");
			globalDefaultStyle.setImage(customGUIElems[13], "settingsButtonB");
			globalDefaultStyle.setImage(customGUIElems[14], "blankButtonA");
			globalDefaultStyle.setImage(customGUIElems[15], "blankButtonB");
		}
		{
			Bitmap8Bit[] customGUIElems = loadBitmapSheetFromFile!Bitmap8Bit("../system/concreteGUIE4.tga", 16, 16);
			globalDefaultStyle.setImage(customGUIElems[0], "addMaterialA");
			globalDefaultStyle.setImage(customGUIElems[1], "addMaterialB");
			globalDefaultStyle.setImage(customGUIElems[2], "removeMaterialA");
			globalDefaultStyle.setImage(customGUIElems[3], "removeMaterialB");
			globalDefaultStyle.setImage(customGUIElems[4], "horizMirrorA");
			globalDefaultStyle.setImage(customGUIElems[5], "horizMirrorB");
			globalDefaultStyle.setImage(customGUIElems[6], "vertMirrorA");
			globalDefaultStyle.setImage(customGUIElems[7], "vertMirrorB");
			globalDefaultStyle.setImage(customGUIElems[8], "ovrwrtInsA");
			globalDefaultStyle.setImage(customGUIElems[9], "ovrwrtInsB");
			//globalDefaultStyle.setImage(customGUIElems[10], "");
			//globalDefaultStyle.setImage(customGUIElems[11], "");
			globalDefaultStyle.setImage(customGUIElems[12], "paletteDownA");
			globalDefaultStyle.setImage(customGUIElems[13], "paletteDownB");
			globalDefaultStyle.setImage(customGUIElems[14], "paletteUpA");
			globalDefaultStyle.setImage(customGUIElems[15], "paletteUpB");
		}
		{
			Bitmap8Bit[] customGUIElems = loadBitmapSheetFromFile!Bitmap8Bit("../system/concreteGUIE3.tga", 16, 16);
			globalDefaultStyle.setImage(customGUIElems[0], "trashButtonA");
			globalDefaultStyle.setImage(customGUIElems[1], "trashButtonB");
			globalDefaultStyle.setImage(customGUIElems[2], "visibilityButtonA");
			globalDefaultStyle.setImage(customGUIElems[3], "visibilityButtonB");
			globalDefaultStyle.setImage(customGUIElems[4], "newTileLayerButtonA");
			globalDefaultStyle.setImage(customGUIElems[5], "newTileLayerButtonB");
			globalDefaultStyle.setImage(customGUIElems[6], "newSpriteLayerButtonA");
			globalDefaultStyle.setImage(customGUIElems[7], "newSpriteLayerButtonB");
			globalDefaultStyle.setImage(customGUIElems[8], "newTransformableTileLayerButtonA");
			globalDefaultStyle.setImage(customGUIElems[9], "newTransformableTileLayerButtonB");
			globalDefaultStyle.setImage(customGUIElems[10], "importLayerDataButtonA");
			globalDefaultStyle.setImage(customGUIElems[11], "importLayerDataButtonB");
			globalDefaultStyle.setImage(customGUIElems[12], "importMaterialDataButtonA");
			globalDefaultStyle.setImage(customGUIElems[13], "importMaterialDataButtonB");
			globalDefaultStyle.setImage(customGUIElems[14], "paletteButtonA");
			globalDefaultStyle.setImage(customGUIElems[15], "paletteButtonB");
		}

		//wh.initGUI();

		input = new InputHandler();
		//input.ml ~= this;
		input.mouseListener = wh;
		input.inputListener = this;
		input.systemEventListener = this;
		//input.kb ~= KeyBinding(0, SDL_SCANCODE_ESCAPE, 0, "sysesc", Devicetype.KEYBOARD);
		//input.kb ~= configFile.keyBindingList;
		input.addBinding(InputHandler.getSysEscKey, InputBinding(InputHandler.sysescCode));
		//configFile.loadBindings(input);
		
		WindowElement.inputHandler = input;
		
		ow ~= new OutputScreen("Pixel Perfect Editor", 1696, 960);

		rasters = new Raster(848, 480, ow[0], 0, 2);
		ow[0].setMainRaster(rasters);
		rasters.addLayer(windowing, 0);
		rasters.addLayer(bitmapPreview, 1);
		//ISSUE: Copying the palette from StyleSheet.defaultPaletteForGUI doesn't work
		//SOLUTION: Load the palette from a file
		rasters.loadPalette(loadPaletteFromFile("../system/concreteGUIE1.tga"));
		wh.setBaseWindow(new TopLevelWindow(848, 480));
		wh.addBackground(loadBitmapFromFile!Bitmap32Bit("../system/background.png"));
		openMaterialList();
		openLayerList();
	}
	public void menuEvent(Event ev) {
		MenuEvent mev = cast(MenuEvent)ev;
		switch (mev.itemSource) {
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
				initNewTileLayer();
				break;
			case "layerTools":
				//TileLayerEditor tle = new TileLayerEditor(this);
				//wh.addWindow(tle);
				break;
			case "resizeLayer":
				initResizeLayer();
				break;
			case "undo":
				onUndo();
				break;
			case "redo":
				onRedo();
				break;
			case "exit":
				onQuit();
				break;
			default:
				break;
		}
	}
	/+public void passActionEvent(Event e){
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
				initNewTileLayer();
				break;
			case "layerTools":
				//TileLayerEditor tle = new TileLayerEditor(this);
				//wh.addWindow(tle);
				break;
			case "resizeLayer":
				initResizeLayer();
				break;
			case "undo":
				onUndo();
				break;
			case "redo":
				onRedo();
				break;
			default: break;
		}
	}+/
	/**
	 * Called when a keybinding event is generated.
	 * The `id` should be generated from a string, usually the name of the binding.
	 * `code` is a duplicate of the code used for fast lookup of the binding, which also contains other info (deviceID, etc).
	 * `timestamp` is the time lapsed since the start of the program, can be used to measure time between keypresses.
	 * NOTE: Hat events on joysticks don't generate keyReleased events, instead they generate keyPressed events on release.
	 */
	public void keyEvent(uint id, BindingCode code, uint timestamp, bool isPressed) {

	}
	/**
	 * Called when an axis is being operated.
	 * The `id` should be generated from a string, usually the name of the binding.
	 * `code` is a duplicate of the code used for fast lookup of the binding, which also contains other info (deviceID, etc).
	 * `timestamp` is the time lapsed since the start of the program, can be used to measure time between keypresses.
	 * `value` is the current position of the axis normalized between -1.0 and +1.0 for joysticks, and 0.0 and +1.0 for analog
	 * triggers.
	 */
	public void axisEvent(uint id, BindingCode code, uint timestamp, float value) {

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
		import PixelPerfectEngine.concrete.dialogs.filedialog;
		FileDialog fd = new FileDialog("Load document","docLoad",&onLoadDialog,[FileDialog.FileAssociationDescriptor(
			"PPE map file", ["*.xmf"])],".\\",false);
		wh.addWindow(fd);
	}
	public void onLoadDialog (Event ev) {
		import std.utf : toUTF32;
		try {
			FileEvent event = cast(FileEvent)ev;
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
		import PixelPerfectEngine.concrete.dialogs.filedialog;
		FileDialog fd = new FileDialog("Save document as","docSave",&onSaveDialog,[FileDialog.FileAssociationDescriptor(
			"PPE map file", ["*.xmf"])],".\\",true);
		wh.addWindow(fd);
	}
	public void onSaveDialog(Event ev) {
		import std.path : extension;
		import std.ascii : toLower;
		FileEvent event = cast(FileEvent)ev;
		selDoc.filename = event.getFullPath();
		if(extension(selDoc.filename) != ".xmf"){
			selDoc.filename ~= ".xmf";
		}
		selDoc.mainDoc.save(selDoc.filename);
	}
	/+public void actionEvent(Event ev) {
		
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
	}+/
	public void onQuit(){onExit();}
	public void controllerRemoved(uint ID){}
	public void controllerAdded(uint ID){}
	public void initResizeLayer() {
		//import resizeMap;
		if (selDoc !is null) {
			wh.addWindow(new ResizeMap(selDoc));
		}
	}
	
	
	/**
	 * Opens a window to ask the user for the data on the new tile layer
	 */
	public void initNewTileLayer(){
		wh.addWindow(new NewTileLayerDialog(this));
	}
	/**
	 * Opens a window to ask the user for input on materials to be added
	 */
	public void initAddMaterials() {
		import windows.addtiles;
		if(selDoc){
			ITileLayer itl = cast(ITileLayer)selDoc.mainDoc.layeroutput[selDoc.selectedLayer];
			const int tileX = itl.getTileWidth, tileY = itl.getTileHeight;
			wh.addWindow(new AddTiles(this, tileX, tileY));
		}
	}
	/**
	 * Creates a new tile layer with the given data.
	 *
	 * file: Optional field. If given, it specifies the external file for binary map data. If it specifies an already
	 * existing file, then that file will be loaded. If null, then the map data will be embedded as a BASE64 chunk.
	 * tmplt: Optional field. Specifies the initial tile source data from a map file alongside with the name of the layer
	 */
	public void newTileLayer(int tX, int tY, int mX, int mY, dstring name, string file, bool embed) {
		selDoc.events.addToTop(new CreateTileLayerEvent(selDoc, tX, tY, mX, mY, name, file, embed));
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
		import PixelPerfectEngine.concrete.dialogs.defaultdialog;
		exitDialog=true;
		DefaultDialog dd = new DefaultDialog(Coordinate(10,10,220,75), "exitdialog","Exit application", ["Are you sure?"],
				["Yes","No","Pls save"],["ok","close","save"]);

		dd.output = &confirmExit;
		wh.addWindow(dd);

	}
	private void confirmExit(Event ev) {
		WindowElement we = cast(WindowElement)ev.sender;
		if (we.getSource == "ok") {
			onexit = true;
		}
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
	public void openLayerList() {
		if (!layerList) {
			layerList = new LayerList(0, 16, &onLayerListClosed);
			wh.addWindow(layerList);
		}
	}
	private void onLayerListClosed() {
		layerList = null;
	}
	public void openMaterialList() {
		if (!materialList) {
			materialList = new MaterialList(0, 230, &onMaterialListClosed);
			wh.addWindow(materialList);
		}
	}
	private void onMaterialListClosed() {
		materialList = null;
	}
}
