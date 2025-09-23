module test5.app;

import std.stdio;
import std.utf;
import std.path;
import std.conv : to;

import bindbc.opengl;

import pixelperfectengine.system.common;

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
	//initialzeSDL();
	if (args.length == 1) {
		args ~= ["%PATH%/assets/test5.xml", "%PATH%/system/unifont-15.0.01.fnt"];
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
	OSWindow output;
	SpriteLayer s;
	Raster r;
	InputHandler ih;
	BitmapDrawer textOutput;
	string[] availTexts;
	public this(string[] args) {
		//Basic setup
		isRunning = true;
		output = new OSWindow("Text processing and rendering test", "ppe_texttest", -1, -1, 424 * 4, 240 * 4, 
				WindowCfgFlags.IgnoreMenuKey);
		version (Windows) output.getOpenGLHandleAttribsARB([
			OpenGLContextAtrb.MajorVersion, 3,
			OpenGLContextAtrb.MinorVersion, 3,
			OpenGLContextAtrb.ProfileMask, 1,
			OpenGLContextAtrb.Flags, OpenGLContextFlags.Debug,
			0
		]);
		else output.getOpenGLHandle();
		const glStatus = loadOpenGL();
		if (glStatus < GLSupport.gl33) {
			writeln("OpenGL not found!");
		}
		r = new Raster(424,240,output,1);
		r.readjustViewport(424 * 4, 240 * 4, 0, 0);
		s = new SpriteLayer(GLShader(loadShader(`%SHADERS%/base_%SHDRVER%.vert`),
				loadShader(`%SHADERS%/base_%SHDRVER%.frag`)), GLShader(loadShader(`%SHADERS%/base_%SHDRVER%.vert`),
				loadShader(`%SHADERS%/base32bit_%SHDRVER%.frag`)));
		r.addLayer(s, 0);
		r.loadPaletteChunk([Color(0x22,0x22,0x22,0xFF),Color(0xff,0xff,0xff,0xFF),Color(0x80,0x80,0x80,0xFF),
				Color(0xff,0x00,0x00,0xFF),Color(0x00,0xff,0x00,0xFF),Color(0x00,0x00,0xff,0xFF)],0);

		ih = new InputHandler();
		ih.inputListener = this;
		ih.systemEventListener = this;
		{
			import pixelperfectengine.system.input.scancode;
			ih.addBinding(BindingCode(ScanCode.SPACE, 0, Devicetype.Keyboard, 0, IGNORE_ALL), InputBinding("up"));
		}
		//Setup textparsing and parse texts from included ETML file
		Fontset!Bitmap8Bit fnt = new Fontset!Bitmap8Bit(File(resolvePath(args[2])), dirName(resolvePath(args[2])) ~ "/");
		CharacterFormattingInfo!Bitmap8Bit defFrmt = new CharacterFormattingInfo!Bitmap8Bit(fnt, 0x01, 0, 0x01, 
				cast(short)(fnt.size + 1), 0x00);
		dstring input;
		File xml = File(resolvePath(args[1]));
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
		// s.addSprite(textOutput.output, 0, 0, 0);
		
		drawNextText();
	}
	public void whereTheMagicHappens() {
		while (isRunning) {
			r.refresh_GL();
			ih.test();
		}
		destroy(output);
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
			s.addBitmapSource(textOutput.output, 0);
			s.createSpriteMaterial(0, 0);
			s.addSprite(0, 0, Point(0, 0));
			s.updateDisplayList();
		}
	}
	public void onQuit() {
		isRunning = false;
	}
	public void inputDeviceAdded(InputDevice id) {

	}
	public void inputDeviceRemoved(InputDevice id) {

	}
	/** 
	 * Called if a window was resized.
	 * Params:
	 *   window = Handle to the OSWindow class.
	 */
	public void windowResize(OSWindow window, int width, int height) {
		immutable double origAspectRatio = 424.0 / 240.0;//Calculate original aspect ratio
		double newAspectRatio = cast(double)width / cast(double)height;//Calculate new aspect ratio
		if (newAspectRatio > origAspectRatio) {		//Display area is now wider, padding needs to be added on the sides
			const double visibleWidth = height * origAspectRatio;
			const double sideOffset = (width - visibleWidth) / 2.0;
			r.readjustViewport(cast(int)visibleWidth, height, cast(int)sideOffset, 0);
		} else {	//Display area is now taller, padding needs to be added on the top and bottom
			const double visibleHeight = width / origAspectRatio;
			const double topOffset = (height - visibleHeight) / 2.0;
			r.readjustViewport(width, cast(int)visibleHeight, 0, cast(int)topOffset);
		}
	}
	/**
	 * Called when a keybinding event is generated.
	 * The `id` should be generated from a string, usually the name of the binding.
	 * `code` is a duplicate of the code used for fast lookup of the binding, which also contains other info (deviceID, etc).
	 * `timestamp` is the time lapsed since the start of the program, can be used to measure time between keypresses.
	 * NOTE: Hat events on joysticks don't generate keyReleased events, instead they generate keyPressed events on release.
	 */
	public void keyEvent(uint id, BindingCode code, Timestamp timestamp, bool isPressed) {
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
	public void axisEvent(uint id, BindingCode code, Timestamp timestamp, float value) {

	}
}
