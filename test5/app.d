module test5.app;

import std.stdio;
import std.utf;
import std.path;
import std.conv : to;

import bindbc.sdl;

import pixelperfectengine.system.common;

import pixelperfectengine.graphics.outputscreen;
import pixelperfectengine.graphics.raster;
import pixelperfectengine.graphics.layers;

import pixelperfectengine.graphics.bitmap;
import pixelperfectengine.graphics.text;
import pixelperfectengine.graphics.draw;

import pixelperfectengine.system.lang.textparser;

import pixelperfectengine.system.input;
import pixelperfectengine.system.file;


///Test suite for text parsing and drawing.
int main(string[] args) {
	initialzeSDL();
	if (args.length == 1) {
		args ~= ["../assets/test5.xml", "../system/unifont-15.0.01.fnt"];
	}
	try {
		Test5 app = new Test5(args);
		app.whereTheMagicHappens;
	} catch (Throwable t) {
		writeln(t);
	}
	return 0;
}

public class Test5 : SystemEventListener, InputListener {
	bool isRunning;
	int textPos;
	TextParser txprs;
	OutputScreen output;
	SpriteLayer s;
	Raster r;
	InputHandler ih;
	BitmapDrawer textOutput;
	string[] availTexts;
	public this(string[] args) {
		//Basic setup
		isRunning = true;
		output = new OutputScreen("TileLayer test", 424 * 4, 240 * 4);
		r = new Raster(424,240,output,0);
		output.setMainRaster(r);
		s = new SpriteLayer(RenderingMode.AlphaBlend);
		r.addLayer(s, 0);
		r.addPaletteChunk([Color(0x22,0x22,0x22,0xFF),Color(0xff,0xff,0xff,0xFF),Color(0x80,0x80,0x80,0xFF),
				Color(0xff,0x00,0x00,0xFF),Color(0x00,0xff,0x00,0xFF),Color(0x00,0x00,0xff,0xFF)]);
		r.setupPalette(256);
		ih = new InputHandler();
		ih.inputListener = this;
		ih.systemEventListener = this;
		{
			import pixelperfectengine.system.input.scancode;
			ih.addBinding(BindingCode(ScanCode.SPACE, 0, Devicetype.Keyboard, 0, KeyModifier.All), InputBinding("up"));
		}
		//Setup textparsing and parse texts from included ETML file
		Fontset!Bitmap8Bit fnt = new Fontset!Bitmap8Bit(File(args[2]), dirName(args[2]) ~ "/");
		CharacterFormattingInfo!Bitmap8Bit defFrmt = new CharacterFormattingInfo!Bitmap8Bit(fnt, 0x01, 0, 0x01, 
				cast(short)(fnt.size + 1), 0x00);
		dstring input;
		File xml = File(args[1]);
		char[] buffer;
		/* buffer.length = 4;
		buffer = xml.rawRead(buffer);
		xml.seek(0); */
		/* switch (buffer) {
			case "<?xm": */
		buffer.length = cast(size_t)xml.size;
		buffer = xml.rawRead(buffer);
		input = toUTF32(buffer);
		buffer.length = 0;
		/* 		break;
			//case "\00<\00?":
			default:
				throw new Exception("Character encoding not supported or cannot be detected.");
		} */
		txprs = new TextParser(input, defFrmt);
		txprs.parse();
		foreach (key; txprs.output.byKey) {
			availTexts ~= key;
		}
		writeln(txprs.output);

		textOutput = new BitmapDrawer(424, 240);
		s.addSprite(textOutput.output, 0, 0, 0);
		
		drawNextText();
	}
	public void whereTheMagicHappens() {
		while (isRunning) {
			r.refresh();
			ih.test();
		}
	}
	void drawNextText() {
		if (textPos >= availTexts.length) {
			isRunning = false;
		} else {
			import std.datetime;
			textOutput.drawFilledBox(Box.bySize(0, 0, 424, 240), 0);
			dstring[dstring] symbols;
			symbols["timenow"] = Clock.currTime().toISOString().to!dstring();
			txprs.output[availTexts[textPos]].interpolate(symbols);
			textOutput.drawMultiLineText(Box.bySize(0, 0, 424, 240), txprs.output[availTexts[textPos]]);
			textPos++;
		}
	}
	public void onQuit() {
		isRunning = false;
	}
	public void controllerAdded(uint id) {

	}
	public void controllerRemoved(uint id) {

	}
	/**
	 * Called when a keybinding event is generated.
	 * The `id` should be generated from a string, usually the name of the binding.
	 * `code` is a duplicate of the code used for fast lookup of the binding, which also contains other info (deviceID, etc).
	 * `timestamp` is the time lapsed since the start of the program, can be used to measure time between keypresses.
	 * NOTE: Hat events on joysticks don't generate keyReleased events, instead they generate keyPressed events on release.
	 */
	public void keyEvent(uint id, BindingCode code, uint timestamp, bool isPressed) {
		if (!isPressed)
			drawNextText();
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
}