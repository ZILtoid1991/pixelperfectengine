module test1.app;

import std.stdio;
import std.string;
import std.conv;
import std.format;
import std.random;

import bindbc.sdl;

import midi2.types.structs;
import midi2.types.enums;

import pixelperfectengine.concrete.window;
import pixelperfectengine.concrete.windowhandler;

import pixelperfectengine.graphics.outputscreen;
import pixelperfectengine.graphics.raster;
import pixelperfectengine.graphics.layers;

import pixelperfectengine.graphics.bitmap;

import pixelperfectengine.system.input;
import pixelperfectengine.system.file;
import pixelperfectengine.system.etc;
import pixelperfectengine.system.systemutility;
import pixelperfectengine.system.config;

import pixelperfectengine.system.common;

import pixelperfectengine.audio.base.handler;
import pixelperfectengine.audio.base.modulebase;
import pixelperfectengine.audio.modules.qm816;
import core.thread;
import iota.audio.midi;
import iota.audio.midiin;

import test1.audioconfig;
import test1.preseteditor;
import test1.modulerouter;

/** 
 * Audio subsystem test.
 */
int main(string[] args) {
	initialzeSDL();
	AudioDevKit app = new AudioDevKit(args);
	app.whereTheMagicHappens();
	return 0;
}
public class TopLevelWindow : Window {
	MenuBar mb;
	AudioDevKit app;
	public this(int width, int height, AudioDevKit app) {
		super(Box(0, 0, width, height), ""d, [], null);
		this.app = app;
		PopUpMenuElement[] menuElements;

		menuElements ~= new PopUpMenuElement("file", "File");

		menuElements[0] ~= new PopUpMenuElement("new", "New project");
		menuElements[0] ~= new PopUpMenuElement("load", "Load project");
		menuElements[0] ~= new PopUpMenuElement("save", "Save project");
		menuElements[0] ~= new PopUpMenuElement("saveAs", "Save project as");
		menuElements[0] ~= new PopUpMenuElement("exit", "Exit application", "Alt + F4");

		menuElements ~= new PopUpMenuElement("edit", "Edit");

		menuElements[1] ~= new PopUpMenuElement("undo", "Undo");
		menuElements[1] ~= new PopUpMenuElement("redo", "Redo");
		menuElements[1] ~= new PopUpMenuElement("copy", "Copy");
		menuElements[1] ~= new PopUpMenuElement("cut", "Cut");
		menuElements[1] ~= new PopUpMenuElement("paste", "Paste");

		menuElements ~= new PopUpMenuElement("view", "View");

		//menuElements[2] ~= new PopUpMenuElement("preEdit", "Module editor");
		menuElements[2] ~= new PopUpMenuElement("router", "Routing layout editor");

		menuElements ~= new PopUpMenuElement("help", "Help");

		menuElements[3] ~= new PopUpMenuElement("helpFile", "Content");
		menuElements[3] ~= new PopUpMenuElement("about", "About");

		mb = new MenuBar("mb", Box(0, 0, width-1, 15), menuElements);
		addElement(mb);
		mb.onMenuEvent = &app.onMenuEvent;
	}
	public override void draw(bool drawHeaderOnly = false) {
		if(output.output.width != position.width || output.output.height != position.height)
			output = new BitmapDrawer(position.width(), position.height());
		
		StyleSheet ss = getStyleSheet();
		const Box bodyarea = Box(0, 0, position.width - 1, position.height - 1);
		drawFilledBox(bodyarea, ss.getColor("window"));

		foreach (WindowElement we; elements) {
			we.draw();
		}
		
	}
}
/** 
 * Testcase for the audio system.
 * Capable of playing back external files.
 */
public class AudioDevKit : InputListener, SystemEventListener {
	AudioDeviceHandler adh;
	ModuleManager	mm;
	AudioModule		selectedModule;
	OutputScreen	output;
	InputHandler	ih;
	Raster			mainRaster;
	AudioSpecs		aS;
	SpriteLayer		windowing;
	MIDIInput		midiIn;
	WindowHandler	wh;
	Window			tlw;
	PresetEditor	preEdit;
	ModuleRouter	router;
	uint			state;
	ubyte			noteBase = 60;
	ubyte			bank0;
	ubyte			bank1;
	
	//ubyte[32][6][2]	level;
	enum StateFlags {
		isRunning		=	1<<0,
		deviceSelected	=	1<<1,
		deviceInitialized=	1<<2,
		midiInitialized	=	1<<3,
		keyPressed		=	1<<8,
		upperHalf		=	1<<9,
	}
	
	public this(string[] args) {
		state |= StateFlags.isRunning;
		//Image fontSource = loadImage(File("../system/cp437_8x16.png"));
		output = new OutputScreen("PixelPerfectEngine Audio Development Kit", 848 * 2, 480 * 2);
		mainRaster = new Raster(848,480,output,0);
		windowing = new SpriteLayer(RenderingMode.Copy);
		//windowing.addSprite(new Bitmap8Bit(848, 480), -65_536, 0, 0);
		wh = new WindowHandler(1696,960,848,480,windowing);
		mainRaster.loadPalette(loadPaletteFromFile("../system/concreteGUIE1.tga"));
		mainRaster.addLayer(windowing, 0);
		INIT_CONCRETE();
		{
			Bitmap8Bit[] customGUIElems = loadBitmapSheetFromFile!Bitmap8Bit("../system/concreteGUI_ADK.tga", 16, 16);
			globalDefaultStyle.setImage(customGUIElems[6], "newA");
			globalDefaultStyle.setImage(customGUIElems[7], "newB");
			globalDefaultStyle.setImage(customGUIElems[8], "saveA");
			globalDefaultStyle.setImage(customGUIElems[9], "saveB");
			globalDefaultStyle.setImage(customGUIElems[10], "loadA");
			globalDefaultStyle.setImage(customGUIElems[11], "loadB");
			globalDefaultStyle.setImage(customGUIElems[12], "settingsA");
			globalDefaultStyle.setImage(customGUIElems[13], "settingsB");
			globalDefaultStyle.setImage(customGUIElems[14], "globalsA");
			globalDefaultStyle.setImage(customGUIElems[15], "globalsB");
			globalDefaultStyle.setImage(customGUIElems[16], "addA");
			globalDefaultStyle.setImage(customGUIElems[17], "addB");
			globalDefaultStyle.setImage(customGUIElems[18], "removeA");
			globalDefaultStyle.setImage(customGUIElems[19], "removeB");
			globalDefaultStyle.setImage(customGUIElems[20], "soloA");
			globalDefaultStyle.setImage(customGUIElems[21], "soloB");
			globalDefaultStyle.setImage(customGUIElems[22], "muteA");
			globalDefaultStyle.setImage(customGUIElems[23], "muteB");
			globalDefaultStyle.setImage(customGUIElems[24], "importA");
			globalDefaultStyle.setImage(customGUIElems[25], "importB");
			globalDefaultStyle.setImage(customGUIElems[26], "exportA");
			globalDefaultStyle.setImage(customGUIElems[27], "exportB");
			globalDefaultStyle.setImage(customGUIElems[28], "macroA");
			globalDefaultStyle.setImage(customGUIElems[29], "macroB");
		}

		ih = new InputHandler();
		ih.systemEventListener = this;
		ih.inputListener = this;
		ih.mouseListener = wh;
		WindowElement.inputHandler = ih;

		AudioDeviceHandler.initAudioDriver(OS_PREFERRED_DRIVER);
	
		initMIDI();
		Bitmap4Bit background = new Bitmap4Bit(848, 480);
		wh.addBackground(background);
		wh.addWindow(new AudioConfig(this));
	}
	void whereTheMagicHappens() {
		while (state & StateFlags.isRunning) {
			mainRaster.refresh();
			ih.test();
			
		}
		if (mm !is null) {
			synchronized
				writeln(mm.suspendAudioThread());
		}
	}
	public void onStart() {
		tlw = new TopLevelWindow(848, 480, this);
		wh.setBaseWindow(tlw);
	}
	public void onMenuEvent(Event ev) {
		MenuEvent me = cast(MenuEvent)ev;
		switch (me.itemSource) {
			case "preEdit":
				openPresetEditor();
				break;
			case "router":
				openRouter();
				break;
			case "exit":
				state &= ~StateFlags.isRunning;
				break;
			default: break;
		}
	}
	public void openRouter() {
		if (router is null)
			router = new ModuleRouter(this);
		if (wh.whichWindow(router) == -1)
			wh.addWindow(router);
		
	}
	public void openPresetEditor() {
		if (preEdit is null && selectedModule !is null)
			preEdit = new PresetEditor("Module editor", selectedModule);
		if (wh.whichWindow(preEdit) == -1)
			wh.addWindow(preEdit);
	}
	public void keyEvent(uint id, BindingCode code, uint timestamp, bool isPressed) {
		
	}
	public void midiInCallback(ubyte[] data, size_t timestamp) @nogc nothrow {
		
	}
	public void axisEvent(uint id, BindingCode code, uint timestamp, float value) {
		
	}
	
	public void onQuit() {
		state &= ~StateFlags.isRunning;
	}
	
	public void controllerAdded(uint id) {
		
	}
	
	public void controllerRemoved(uint id) {
		
	}
	
}
