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

/** 
 * Audio subsystem test.
 * 
 */
int main(string[] args) {
	initialzeSDL();
	TestOneApp app = new TestOneApp(args);
	app.whereTheMagicHappens();
	return 0;
}
/** 
 * Testcase for the audio system.
 * Capable of playing back external files.
 */
public class TestOneApp : InputListener, SystemEventListener {
	AudioDeviceHandler adh;
	ModuleManager	mm;
	QM816			fmsynth;
	OutputScreen	output;
	InputHandler	ih;
	Raster			mainRaster;
	AudioSpecs		aS;
	SpriteLayer		windowing;
	MIDIInput		midiIn;
	WindowHandler	wh;
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

		adh = new AudioDeviceHandler(AudioSpecs(predefinedFormats[PredefinedFormats.FP32], 48_000, 0, 2, 512, Duration.init), 
				64, 8);
		adh.initAudioDriver(OS_PREFERRED_DRIVER);
		initMIDI();

		Bitmap4Bit background = new Bitmap4Bit(848, 480);
		for (int y ; y < background.height() ; y++) {
			for (int x ; x < background.width() ; x++) {
				background.writePixel(x, y, 0x0);
			}
		}
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

	public void initDevice(int num) {
		

		//Initialize audio thread
		int status = mm.runAudioThread();
		if (status)
			throw new Exception("Audio thread error!");

		state |= StateFlags.deviceInitialized;
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
