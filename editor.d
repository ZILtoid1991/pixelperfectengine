/*
 *Copyright (C) 2015, by Laszlo Szeremi under the Boost license.
 *
 *VDP Engine, editor module
 */

module editor;

import std.conv;

import graphics.core;
import graphics.raster;
import graphics.layers;

import graphics.bitmap;
import graphics.draw;
import collision;
import system.inputHandler;
import system.file;
import system.etc;
import std.stdio;
import std.conv;
import derelict.sdl2.sdl;
import windowing.window;
import map.mapload;
import converterdialog;

public interface IEditor{
	public void onExit();
	public void newDocument();
	public void newLayer();
	public void xmpToolkit();
	public void createNewDocument(wstring name, int rX, int rY, int pal);
	public void createNewLayer(string name, int type, int tX, int tY, int mX, int mY);
}

public class NewDocumentDialog : Window, ActionListener{
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
			we.addTextInputHandler(inputhandler);
			addElement(we, EventProperties.MOUSE);
		}
		buttons[0].al ~= this;
	}
	public void actionEvent(string source, int type, int value, wstring message){
		if(source == "ok"){
			ie.createNewDocument(textBoxes[0].getText(), to!int(textBoxes[1].getText()), to!int(textBoxes[2].getText()), to!int(textBoxes[3].getText()));

			parent.closeWindow(this);
		}

	}
	public void actionEvent(string source, string subSource, int type, int value, wstring message){}
	public void actionEvent(Event event){}
}

public class NewLayerDialog : Window, ActionListener{
	public IEditor ie;
	private TextBox[] textBoxes;
	private RadioButtonGroup layerType;
	public this(Coordinate size, wstring title){
		super(size, title);
	}
	public this(InputHandler inputhandler){
		this(Coordinate(10,10,220,250),"New Layer");
		Label[] labels;
		labels ~= new Label("Name:","",Coordinate(5,20,80,39));
		labels ~= new Label("TileX:","",Coordinate(5,40,80,59));
		labels ~= new Label("TileY:","",Coordinate(5,60,80,79));
		textBoxes ~= new TextBox("","name",Coordinate(81,20,200,39));
		textBoxes ~= new TextBox("","rX",Coordinate(81,40,200,59));
		textBoxes ~= new TextBox("","rY",Coordinate(81,60,200,79));
		layerType = new RadioButtonGroup("Layertype:","layertype",Coordinate(5,80,200,200),["Dummy","Tile","Tile(32Bit)","Sprite","Sprite(32Bit)"],16,1);
		Button b = new Button("Ok","ok",Coordinate(150,215,200,235));
		b.al ~= this;
		addElement(b, EventProperties.MOUSE);
		foreach(WindowElement we; labels){
			addElement(we, EventProperties.MOUSE);
		}
		foreach(TextBox we; textBoxes){
			we.addTextInputHandler(inputhandler);
			addElement(we, EventProperties.MOUSE);
		}
		addElement(layerType, EventProperties.MOUSE);
	}
	public void actionEvent(string source, string subSource, int type, int value, wstring message){}
	public void actionEvent(string source, int type, int value, wstring message){}
	public void actionEvent(Event event){}
}

public class EditorWindowHandler : WindowHandler, ElementContainer, ActionListener{
	private WindowElement[] elements, mouseC, keyboardC, scrollC;
	private ListBox layerList, prop;
	private ListBoxColumn[] propTL, propSL, propSLE;
	private ListBoxColumn[] layerListE;
	public Label[] labels;
	private int[] propTLW, propSLW, propSLEW;
	public IEditor ie;

	//public InputHandler ih;

	private BitmapDrawer output;
	public this(int sx, int sy, int rx, int ry,ISpriteLayer16Bit sl){
		super(sx,sy,rx,ry,sl);
		output = new BitmapDrawer(rx, ry);
		addBackground(output.output);
		propTLW = [40, 320];
		propSLW = [160, 320, 48, 64];
		propSLEW = [160, 320, 40, 56];
	}

	public void initGUI(){
		output.drawFilledRectangle(0, rasterX, 0, rasterY, 154);
		layerListE ~= ListBoxColumn("Num", [""]);
		layerListE ~= ListBoxColumn("Name", [""]);
		layerListE ~= ListBoxColumn("Type", [""]);
		layerList = new ListBox("layerList", Coordinate(5,7,205,98), layerListE, [30,160,64],15);
		propTL ~= ListBoxColumn("ID", [""]);
		propTL ~= ListBoxColumn("Name", [""]);
		propSL ~= ListBoxColumn("Type", [""]);
		propSL ~= ListBoxColumn("Name", [""]);
		propSL ~= ListBoxColumn("SizeX", [""]);
		propSL ~= ListBoxColumn("SizeY", [""]);
		propSLE ~= ListBoxColumn("Type", [""]);
		propSLE ~= ListBoxColumn("Name", [""]);
		propSLE ~= ListBoxColumn("PosX", [""]);
		propSLE ~= ListBoxColumn("PosY", [""]);
		prop = new ListBox("prop", Coordinate(5,105,460,391), propSL, propSLW,15);
		addElement(layerList, EventProperties.MOUSE | EventProperties.SCROLL);
		addElement(prop, EventProperties.MOUSE | EventProperties.SCROLL);
		addElement(new Button("New","new",Coordinate(210,5,290,25)), EventProperties.MOUSE);
		addElement(new Button("Load","load",Coordinate(295,5,375,25)), EventProperties.MOUSE);
		addElement(new Button("Save","save",Coordinate(380,5,460,25)), EventProperties.MOUSE);
		addElement(new Button("Save As","saveas",Coordinate(465,5,545,25)), EventProperties.MOUSE);
		addElement(new Button("Help","help",Coordinate(550,5,630,25)), EventProperties.MOUSE);
		addElement(new Button("New Layer","newL",Coordinate(210,30,290,50)), EventProperties.MOUSE);
		addElement(new Button("Del Layer","delL",Coordinate(295,30,375,50)), EventProperties.MOUSE);
		addElement(new Button("Imp Layer","impL",Coordinate(380,30,460,50)), EventProperties.MOUSE);
		addElement(new Button("Imp TileD","impTD",Coordinate(465,30,545,50)), EventProperties.MOUSE);
		addElement(new Button("Imp ObjD","impOD",Coordinate(550,30,630,50)), EventProperties.MOUSE);
		addElement(new Button("Imp Map","impM",Coordinate(210,55,290,75)), EventProperties.MOUSE);
		addElement(new Button("Imp Img","impI",Coordinate(295,55,375,75)), EventProperties.MOUSE);
		addElement(new Button("XMP Edit","xmp",Coordinate(380,55,460,75)), EventProperties.MOUSE);
		addElement(new Button("Palette","pal",Coordinate(465,55,545,75)), EventProperties.MOUSE);
		addElement(new Button("Settings","setup",Coordinate(550,55,630,75)), EventProperties.MOUSE);
		addElement(new Button("Doc Prop","docP",Coordinate(210,80,290,100)), EventProperties.MOUSE);
		addElement(new Button("Export","exp",Coordinate(295,80,375,100)), EventProperties.MOUSE);
		//addElement(new Button("Save","save",Coordinate(380,80,460,100)), EventProperties.MOUSE);
		//addElement(new Button("Save As","saveas",Coordinate(465,80,545,100)), EventProperties.MOUSE);
		addElement(new Button("Exit","exit",Coordinate(550,80,630,100)), EventProperties.MOUSE);
		labels ~= new Label("Layer info:","null",Coordinate(5,395,101,415));
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
		labels ~= new Label("0","ty",Coordinate(366,435,420,455));
		foreach(WindowElement we; labels){
			addElement(we, 0);
		}
		foreach(WindowElement we; elements){
			we.draw();
		}
	}

	public void addElement(WindowElement we, int eventProperties){
		elements ~= we;
		we.elementContainer = this;
		we.al ~= this;
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

	public void actionEvent(string source, int type, int value, wstring message){
		writeln(source);
		switch(source){
			case "exit":
				ie.onExit;
				break;
			case "new":
				ie.newDocument;
				break;
			case "newL":
				ie.newLayer;
				break;
			case "xmp":
				ie.xmpToolkit();
				break;
			default:
				break;
		}
	}
	public void actionEvent(Event event){}
	public void actionEvent(string source, string subSource, int type, int value, wstring message){}
	public Bitmap16Bit[wchar] getFontSet(int style){
		switch(style){
			case 0: return basicFont;
			case 1: return altFont;
			case 3: return alarmFont;
			default: break;
		}
		return basicFont;
		
	}
	public Bitmap16Bit getStyleBrush(int style){
		return styleBrush[style];
	}
	public void drawUpdate(WindowElement sender){
		output.insertBitmap(sender.getPosition().xa,sender.getPosition().ya,sender.output.output);
	}
	public void getFocus(WindowElement sender){}
	public void dropFocus(WindowElement sender){}
	public override void passMouseEvent(int x, int y, int state = 0){
		foreach(WindowElement e; mouseC){
			if(e.getPosition().xa < x && e.getPosition().xb > x && e.getPosition().ya < y && e.getPosition().yb > y){
				e.onClick(x - e.getPosition().xa, y - e.getPosition().ya, state);
				return;
			}
		}
	}
	public override void passScrollEvent(int wX, int wY, int x, int y){
		foreach(WindowElement e; scrollC){
			if(e.getPosition().xa < wX && e.getPosition().xb > wX && e.getPosition().ya < wX && e.getPosition().yb > wY){
				
				e.onScroll(y, x, wX, wY);

				return;
			}
		}
	}
}

public class Editor : InputListener, MouseListener, ActionListener, IEditor, SystemEventListener{
	public OutputWindow[] ow;
	public Raster[] rasters;
	public InputHandler input;
	public BackgroundLayer[] backgroundLayers;
	public SpriteLayer windowing;
	public SpriteLayer32Bit bitmapPreview;
	public bool onexit, exitDialog, newLayerDialog;
	public WindowElement[] elements;
	public Window test;
	public EditorWindowHandler wh;
	public MapHandler document;
	//public ForceFeedbackHandler ffb;
	private uint[5] framecounter;
	public char[40] windowTitle;

	public void mouseButtonEvent(Uint32 which, Uint32 timestamp, Uint32 windowID, Uint8 button, Uint8 state, Uint8 clicks, Sint32 x, Sint32 y){
		//writeln(windowID);
	}
	public void mouseWheelEvent(uint type, uint timestamp, uint windowID, uint which, int x, int y, int wX, int wY){}
	public void mouseMotionEvent(uint timestamp, uint windowID, uint which, uint state, int x, int y, int relX, int relY){}
	public void keyPressed(string ID, Uint32 timestamp, Uint32 devicenumber, Uint32 devicetype){
		if(ID == "sysesc"){
			onexit = !onexit;
		}else if(ID == "AAAAA"){
			//ffb.runRumbleEffect(0, 1, 100);
		}
	}
	public void keyReleased(string ID, Uint32 timestamp, Uint32 devicenumber, Uint32 devicetype){}
	public void actionEvent(string source, int type, int value, wstring message){
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
	}
	public void actionEvent(Event event){}
	public void onQuit(){onexit = !onexit;}
	public void controllerRemoved(uint ID){}
	public void controllerAdded(uint ID){}
	public void xmpToolkit(){
		wh.addWindow(new ConverterDialog(input));
	}
	public this(string[] args){

		windowing = new SpriteLayer();
		bitmapPreview = new SpriteLayer32Bit();

		wh = new EditorWindowHandler(1280,960,640,480,windowing);
		wh.ie = this;

		//load the fonts
		Bitmap16Bit[] fontset = loadBitmapFromFile("UIfont.vmp");
		for(int i; i < fontset.length; i++){
			wh.basicFont[to!wchar(32+i)] = fontset[i];
			//write(32+i, " ");
		}

		//load the stylesheets
		Bitmap16Bit[] styleSheet = loadBitmapFromFile("UIstyle.vmp");
		styleSheet ~= loadBitmapFromFile("UIbuttons0.vmp");
		wh.styleBrush[0] = styleSheet[0];
		wh.styleBrush[1] = styleSheet[1];
		wh.styleBrush[2] = styleSheet[2];
		wh.styleBrush[3] = styleSheet[3];
		wh.styleBrush[4] = styleSheet[4];
		wh.styleBrush[5] = styleSheet[5];
		wh.styleBrush[6] = styleSheet[6];
		wh.styleBrush[7] = styleSheet[7];
		wh.styleBrush[8] = styleSheet[8];
		wh.styleBrush[9] = styleSheet[9];
		wh.styleBrush[10] = styleSheet[10];
		wh.styleBrush[11] = styleSheet[11];
		wh.styleBrush[12] = styleSheet[12];
		wh.styleBrush[13] = styleSheet[13];
		wh.styleBrush[14] = styleSheet[14];
		wh.styleBrush[15] = styleSheet[15];
		wh.styleBrush[16] = styleSheet[16];
		wh.styleBrush[17] = styleSheet[17];

		wh.initGUI();

		input = new InputHandler();
		input.ml ~= this;
		input.ml ~= wh;
		input.il ~= this;
		input.sel ~= this;
		input.kb ~= KeyBinding(0, SDL_SCANCODE_ESCAPE, 0, "sysesc", Devicetype.KEYBOARD);
		//wh.ih = input;
		//ffb = new ForceFeedbackHandler(input);

		//OutputWindow.setScalingQuality("2");
		//OutputWindow.setDriver("software");
		ow ~= new OutputWindow("Pixel Perfect Editor", 1280, 960);

		rasters ~= new Raster(640, 480, ow[0].renderer);
		ow[0].setMainRaster(rasters[0]);
		rasters[0].addLayer(windowing);
		rasters[0].addLayer(bitmapPreview);
		rasters[0].setupPalette(512);
		//loadPaletteFromFile("VDPeditUI0.pal", guiR);
		load24bitPaletteFromFile("VDPeditUI0.pal", rasters[0]);

		rasters[0].addRefreshListener(ow[0],0);

	}

	public void rudamentaryFrameCounter(){
		framecounter[0] = framecounter[1];
		framecounter[1] = SDL_GetTicks();
		framecounter[2]++;
		framecounter[3] += framecounter[1] - framecounter[0];
		if(framecounter[3] >= 1000){
			//writeln(framecounter[2]);
			framecounter[4] = framecounter[2];
			framecounter[2] = 0;
			framecounter[3] = 0;
		}

	}

	public void whereTheMagicHappens(){
		while(!onexit){
			input.test();

			rasters[0].refresh();
			if(rasters.length == 2){
				rasters[1].refresh();
			}
			rudamentaryFrameCounter();
			//onexit = true;
		}
	}
	public void onExit(){

			exitDialog=true;
			DefaultDialog dd = new DefaultDialog(Coordinate(10,10,220,75), "exitdialog","U WOT M8?", "Are you fucking serious?",["Yes","No","Pls save"]);
			dd.al ~= this;
			wh.addWindow(dd);

	}
	public void newDocument(){
		NewDocumentDialog ndd = new NewDocumentDialog(input);
		ndd.ie = this;
		wh.addWindow(ndd);
	}
	public void createNewDocument(wstring name, int rX, int rY, int pal){
		ow ~= new OutputWindow("Edit window", to!ushort(rX*2),to!ushort(rY*2));
		rasters ~= new Raster(to!ushort(rX), to!ushort(rY), ow[1].renderer);
		rasters[1].setupPalette(pal);
		ow[1].setMainRaster(rasters[1]);
		document = new MapHandler();

	}
	public void createNewLayer(string name, int type, int tX, int tY, int mX, int mY){

	}
	public void newLayer(){
		if(document !is null){
			NewLayerDialog ndd = new NewLayerDialog(input);
			wh.addWindow(ndd);
		}
	}
}