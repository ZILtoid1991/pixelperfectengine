module test1.app;

import std.stdio;
import std.string;
import std.conv;
import std.format;
import std.random;

import bindbc.sdl;

import midi2.types.structs;
import midi2.types.enums;

import pixelperfectengine.graphics.outputscreen;
import pixelperfectengine.graphics.raster;
import pixelperfectengine.graphics.layers;

import pixelperfectengine.graphics.bitmap;

import pixelperfectengine.system.input;
import pixelperfectengine.system.file;
import pixelperfectengine.system.etc;
import pixelperfectengine.system.config;

import pixelperfectengine.system.common;

import pixelperfectengine.audio.base.handler;
import pixelperfectengine.audio.base.modulebase;
import pixelperfectengine.audio.modules.qm816;
import core.thread;
import iota.audio.midi;
import iota.audio.midiin;

/** 
 * Audio subsystem test.
 * 
 */
int main(string[] args) {
	initialzeSDL();
	TestAudio app = new TestAudio(args);
	app.whereTheMagicHappens();
	return 0;
}
/** 
 * Testcase for the audio system.
 * Capable of playing back external files.
 */
public class TestAudio : InputListener, SystemEventListener {
	AudioDeviceHandler adh;
	ModuleManager	mm;
	QM816			fmsynth;
	OutputScreen	output;
	InputHandler	ih;
	Raster			r;
	TileLayer		textOut;
	MIDIInput		midiIn;
	int				audioDev;
	int				midiDev = -1;
	uint			state;
	ubyte			noteBase = 60;
	ubyte			bank0;
	ubyte			bank1;
	
	ubyte[32][6][2]	level;
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
		Image fontSource = loadImage(File("../system/cp437_8x16.png"));
		output = new OutputScreen("Audio test", 848 * 2, 480 * 2);
		r = new Raster(848,480,output,0);
		output.setMainRaster(r);
		textOut = new TileLayer(8, 16, RenderingMode.Copy);
		r.addPaletteChunk(loadPaletteFromImage(fontSource));
		r.addLayer(textOut, 0);

		{
			MappingElement[] map;
			map.length = 106 * 30;
			textOut.loadMapping(106,30, map);
			Bitmap8Bit[] tiles = loadBitmapSheetFromImage!Bitmap8Bit(fontSource, 8, 16);
			foreach (i, key; tiles) {
				textOut.addTile(key, to!wchar(i),1);
			}
		}

		ih = new InputHandler();
		ih.systemEventListener = this;
		ih.inputListener = this;
		
		{
			import pixelperfectengine.system.input.scancode;
			ih.addBinding(BindingCode(ScanCode.GRAVE, 0, Devicetype.Keyboard, 0, KeyModifier.All), InputBinding("grave"));
			ih.addBinding(BindingCode(ScanCode.n1, 0, Devicetype.Keyboard, 0, KeyModifier.All), InputBinding("num1"));
			ih.addBinding(BindingCode(ScanCode.n2, 0, Devicetype.Keyboard, 0, KeyModifier.All), InputBinding("num2"));
			ih.addBinding(BindingCode(ScanCode.n3, 0, Devicetype.Keyboard, 0, KeyModifier.All), InputBinding("num3"));
			ih.addBinding(BindingCode(ScanCode.n4, 0, Devicetype.Keyboard, 0, KeyModifier.All), InputBinding("num4"));
			ih.addBinding(BindingCode(ScanCode.n5, 0, Devicetype.Keyboard, 0, KeyModifier.All), InputBinding("num5"));
			ih.addBinding(BindingCode(ScanCode.n6, 0, Devicetype.Keyboard, 0, KeyModifier.All), InputBinding("num6"));
			ih.addBinding(BindingCode(ScanCode.n7, 0, Devicetype.Keyboard, 0, KeyModifier.All), InputBinding("num7"));
			ih.addBinding(BindingCode(ScanCode.n8, 0, Devicetype.Keyboard, 0, KeyModifier.All), InputBinding("num8"));
			ih.addBinding(BindingCode(ScanCode.n9, 0, Devicetype.Keyboard, 0, KeyModifier.All), InputBinding("num9"));
			ih.addBinding(BindingCode(ScanCode.n0, 0, Devicetype.Keyboard, 0, KeyModifier.All), InputBinding("num0"));
			ih.addBinding(BindingCode(ScanCode.MINUS, 0, Devicetype.Keyboard, 0, KeyModifier.All), InputBinding("minus"));
			ih.addBinding(BindingCode(ScanCode.EQUALS, 0, Devicetype.Keyboard, 0, KeyModifier.All), InputBinding("equals"));
			ih.addBinding(BindingCode(ScanCode.Q, 0, Devicetype.Keyboard, 0, KeyModifier.All), InputBinding("q"));
			ih.addBinding(BindingCode(ScanCode.W, 0, Devicetype.Keyboard, 0, KeyModifier.All), InputBinding("w"));
			ih.addBinding(BindingCode(ScanCode.E, 0, Devicetype.Keyboard, 0, KeyModifier.All), InputBinding("e"));
			ih.addBinding(BindingCode(ScanCode.R, 0, Devicetype.Keyboard, 0, KeyModifier.All), InputBinding("r"));
			ih.addBinding(BindingCode(ScanCode.T, 0, Devicetype.Keyboard, 0, KeyModifier.All), InputBinding("t"));
			ih.addBinding(BindingCode(ScanCode.Y, 0, Devicetype.Keyboard, 0, KeyModifier.All), InputBinding("y"));
			ih.addBinding(BindingCode(ScanCode.U, 0, Devicetype.Keyboard, 0, KeyModifier.All), InputBinding("u"));
			ih.addBinding(BindingCode(ScanCode.I, 0, Devicetype.Keyboard, 0, KeyModifier.All), InputBinding("i"));
			ih.addBinding(BindingCode(ScanCode.O, 0, Devicetype.Keyboard, 0, KeyModifier.All), InputBinding("o"));
			ih.addBinding(BindingCode(ScanCode.P, 0, Devicetype.Keyboard, 0, KeyModifier.All), InputBinding("p"));
			ih.addBinding(BindingCode(ScanCode.LEFTBRACKET, 0, Devicetype.Keyboard, 0, KeyModifier.All), InputBinding("["));
			ih.addBinding(BindingCode(ScanCode.RIGHTBRACKET, 0, Devicetype.Keyboard, 0, KeyModifier.All), InputBinding("]"));
			ih.addBinding(BindingCode(ScanCode.F1, 0, Devicetype.Keyboard, 0, KeyModifier.All), InputBinding("F1"));
			ih.addBinding(BindingCode(ScanCode.F2, 0, Devicetype.Keyboard, 0, KeyModifier.All), InputBinding("F2"));
			ih.addBinding(BindingCode(ScanCode.F3, 0, Devicetype.Keyboard, 0, KeyModifier.All), InputBinding("F3"));
			ih.addBinding(BindingCode(ScanCode.F4, 0, Devicetype.Keyboard, 0, KeyModifier.All), InputBinding("F4"));
			ih.addBinding(BindingCode(ScanCode.F5, 0, Devicetype.Keyboard, 0, KeyModifier.All), InputBinding("F5"));
			ih.addBinding(BindingCode(ScanCode.F6, 0, Devicetype.Keyboard, 0, KeyModifier.All), InputBinding("F6"));
			ih.addBinding(BindingCode(ScanCode.F7, 0, Devicetype.Keyboard, 0, KeyModifier.All), InputBinding("F7"));
			ih.addBinding(BindingCode(ScanCode.F8, 0, Devicetype.Keyboard, 0, KeyModifier.All), InputBinding("F8"));
			ih.addBinding(BindingCode(ScanCode.F9, 0, Devicetype.Keyboard, 0, KeyModifier.All), InputBinding("F9"));
			ih.addBinding(BindingCode(ScanCode.UP, 0, Devicetype.Keyboard, 0, KeyModifier.All), InputBinding("OctUp"));
			ih.addBinding(BindingCode(ScanCode.DOWN, 0, Devicetype.Keyboard, 0, KeyModifier.All), InputBinding("OctDown"));
			//ih.addBinding(BindingCode(ScanCode.GRAVE, 0, Devicetype.Keyboard, 0, KeyModifier.All), InputBinding("grave"));

		}

		adh = new AudioDeviceHandler(AudioSpecs(predefinedFormats[PredefinedFormats.FP32], 48_000, 0, 2, 512, Duration.init), 
				64, 8);
		
		initDriver();
		
	}
	void whereTheMagicHappens() {
		ubyte[] midiData;
		while (state & StateFlags.isRunning) {
			r.refresh();
			ih.test();
			
		}
		if (mm !is null) {
			synchronized
				writeln(mm.suspendAudioThread());
		}
	}

	public void clearScreen() {
		for (int y ; y < 30 ; y++)
			for (int x ; x < 106 ; x++)
				textOut.writeMapping(x, y, MappingElement(' '));
	}
	
	public void initDriver() {
		clearScreen();

		adh.initAudioDriver(OS_PREFERRED_DRIVER);

		int line;
		textOut.writeTextToMap(0, line++, 0, "Available devices:");
		textOut.writeTextToMap(0, line, 0, "` ");
		textOut.writeTextToMap(2, line++, 0, "Default");
		foreach (i, key; adh.getDevices) {
			textOut.writeTextToMap(0, line, 0, to!wstring(i + 1));
			textOut.writeTextToMap(2, line++, 0, to!wstring(key));
		}

		//state |= StateFlags.driverInitialized;
	}

	public void initMidiDev() {
		initMIDI();
		string[] inDevs = getMIDIInputDevs();
		if (inDevs.length) {
			clearScreen();

			int line;
			textOut.writeTextToMap(0, line++, 0, "Available MIDI input devices:");
			textOut.writeTextToMap(0, line, 0, "` ");
			textOut.writeTextToMap(2, line++, 0, "None");
			foreach (i, key; inDevs) {
				textOut.writeTextToMap(0, line, 0, to!wstring(i + 1));
				textOut.writeTextToMap(2, line++, 0, to!wstring(key));
			}
		} else {
			state |= StateFlags.midiInitialized;
		}
	}

	public void initDevice(int num) {
		clearScreen();
		try {
			adh.initAudioDevice(num);

			//int line;
			textOut.writeTextToMap(0, 0, 0, "Sample Rate:");
			textOut.writeTextToMap(14, 0, 0, to!wstring(adh.getSamplingFrequency));
			textOut.writeTextToMap(21, 0, 0, "Channels:");
			textOut.writeTextToMap(31, 0, 0, to!wstring(adh.getChannels));
			textOut.writeTextToMap(35, 0, 0, "Bits:");
			//textOut.writeTextToMap(40, 0, 0, to!wstring(adh..bits & 0xFF));
			textOut.writeTextToMap(0, 1, 0, "Synth:");
			textOut.writeTextToMap(7, 1, 0, "QM816");
			
		} catch (AudioInitException e) {
			textOut.writeTextToMap(14, 0, 0, to!wstring(e.msg));
		}
		mm = new ModuleManager(adh);
		fmsynth = new QM816();
		mm.addModule(fmsynth, null, null, [0,1], [0,1]);

		//Initialize audio thread
		int status = mm.runAudioThread();
		if (status)
			throw new Exception("Audio thread error!");

		state |= StateFlags.deviceInitialized;
	}
	public void refreshDisplay() {
		textOut.writeTextToMap(0, 2, 0, "                                                                    ");
		textOut.writeTextToMap(0, 2, 0, "VBank0:");
		textOut.writeTextToMap(8, 2, 0, to!wstring(bank0));
		textOut.writeTextToMap(16, 2, 0, "VBank1:");
		textOut.writeTextToMap(24, 2, 0, to!wstring(bank1));
		textOut.writeTextToMap(32, 2, 0, "Half:");
		textOut.writeTextToMap(38, 2, 0, state & StateFlags.upperHalf ? "Hi" : "Lo");
		textOut.writeTextToMap(42, 2, 0, "Val:");
		textOut.writeTextToMap(48, 2, 0, to!wstring(level[state & StateFlags.upperHalf ? 1 : 0][bank1][bank0]));
	}
	public void keyEvent(uint id, BindingCode code, uint timestamp, bool isPressed) {
		if (isPressed) {
			if ((state & StateFlags.deviceSelected) == 0) {
				switch (id) {
					case hashCalc("num1"):
						audioDev = 0;
						break;
					case hashCalc("num2"):
						audioDev = 1;
						break;
					case hashCalc("num3"):
						audioDev = 2;
						break;
					case hashCalc("num4"):
						audioDev = 3;
						break;
					case hashCalc("num5"):
						audioDev = 4;
						break;
					case hashCalc("num6"):
						audioDev = 5;
						break;
					case hashCalc("num7"):
						audioDev = 6;
						break;
					case hashCalc("num8"):
						audioDev = 7;
						break;
					case hashCalc("num9"):
						audioDev = 8;
						break;
					case hashCalc("num0"):
						audioDev = 9;
						break;
					case hashCalc("grave"):
						audioDev = -1;
						break;
					default:
						break;
				}
				initMidiDev();
				state |= StateFlags.deviceSelected;
				if (state & StateFlags.midiInitialized)
					initDevice(audioDev);
			} else if ((state & StateFlags.midiInitialized) == 0) {
				switch (id) {
					case hashCalc("num1"):
						midiDev = 0;
						break;
					case hashCalc("num2"):
						midiDev = 1;
						break;
					case hashCalc("num3"):
						midiDev = 2;
						break;
					case hashCalc("num4"):
						midiDev = 3;
						break;
					case hashCalc("num5"):
						midiDev = 4;
						break;
					case hashCalc("num6"):
						midiDev = 5;
						break;
					case hashCalc("num7"):
						midiDev = 6;
						break;
					case hashCalc("num8"):
						midiDev = 7;
						break;
					case hashCalc("num9"):
						midiDev = 8;
						break;
					case hashCalc("num0"):
						midiDev = 9;
						break;
					case hashCalc("grave"):
						
						break;
					default:
						break;
				}
				initDevice(audioDev);
				if (midiDev != -1)
					openMIDIInput(midiIn, midiDev);
				if (midiIn)
					midiIn.midiInCallback = &midiInCallback;
				midiIn.start();
				state |= StateFlags.midiInitialized;
			} else if(!(state & StateFlags.keyPressed)) {
				state |= StateFlags.keyPressed;
				UMP midipacket; //UMP(MessageType.MIDI2, 0x0, MIDI2_0Cmd.NoteOn, 0x0, noteBase, MIDI2_0NoteAttrTyp.None);
				switch (id) {
					case hashCalc("q"):		//C
						midipacket = UMP(MessageType.MIDI2, 0x0, MIDI2_0Cmd.NoteOn, 0x0, noteBase, MIDI2_0NoteAttrTyp.None);
						break;
					case hashCalc("num2"):	//C#
						midipacket = UMP(MessageType.MIDI2, 0x0, MIDI2_0Cmd.NoteOn, 0x0, cast(ubyte)(noteBase + 1), MIDI2_0NoteAttrTyp.None);
						break;
					case hashCalc("w"):		//D
						midipacket = UMP(MessageType.MIDI2, 0x0, MIDI2_0Cmd.NoteOn, 0x0, cast(ubyte)(noteBase + 2), MIDI2_0NoteAttrTyp.None);
						break;
					case hashCalc("num3"):	//D#
						midipacket = UMP(MessageType.MIDI2, 0x0, MIDI2_0Cmd.NoteOn, 0x0, cast(ubyte)(noteBase + 3), MIDI2_0NoteAttrTyp.None);
						break;
					case hashCalc("e"):		//E
						midipacket = UMP(MessageType.MIDI2, 0x0, MIDI2_0Cmd.NoteOn, 0x0, cast(ubyte)(noteBase + 4), MIDI2_0NoteAttrTyp.None);
						break;
					case hashCalc("r"):		//F
						midipacket = UMP(MessageType.MIDI2, 0x0, MIDI2_0Cmd.NoteOn, 0x0, cast(ubyte)(noteBase + 5), MIDI2_0NoteAttrTyp.None);
						break;
					case hashCalc("num5"):	//F#
						midipacket = UMP(MessageType.MIDI2, 0x0, MIDI2_0Cmd.NoteOn, 0x0, cast(ubyte)(noteBase + 6), MIDI2_0NoteAttrTyp.None);
						break;
					case hashCalc("t"):		//G
						midipacket = UMP(MessageType.MIDI2, 0x0, MIDI2_0Cmd.NoteOn, 0x0, cast(ubyte)(noteBase + 7), MIDI2_0NoteAttrTyp.None);
						break;
					case hashCalc("num6"):	//G#
						midipacket = UMP(MessageType.MIDI2, 0x0, MIDI2_0Cmd.NoteOn, 0x0, cast(ubyte)(noteBase + 8), MIDI2_0NoteAttrTyp.None);
						break;
					case hashCalc("y"):		//A
						midipacket = UMP(MessageType.MIDI2, 0x0, MIDI2_0Cmd.NoteOn, 0x0, cast(ubyte)(noteBase + 9), MIDI2_0NoteAttrTyp.None);
						break;
					case hashCalc("num7"):	//A#
						midipacket = UMP(MessageType.MIDI2, 0x0, MIDI2_0Cmd.NoteOn, 0x0, cast(ubyte)(noteBase + 10), MIDI2_0NoteAttrTyp.None);
						break;
					case hashCalc("u"):		//B
						midipacket = UMP(MessageType.MIDI2, 0x0, MIDI2_0Cmd.NoteOn, 0x0, cast(ubyte)(noteBase + 11), MIDI2_0NoteAttrTyp.None);
						break;
					case hashCalc("i"):		//C+
						midipacket = UMP(MessageType.MIDI2, 0x0, MIDI2_0Cmd.NoteOn, 0x0, cast(ubyte)(noteBase + 12), MIDI2_0NoteAttrTyp.None);
						break;
					case hashCalc("num9"):	//C#+
						midipacket = UMP(MessageType.MIDI2, 0x0, MIDI2_0Cmd.NoteOn, 0x0, cast(ubyte)(noteBase + 13), MIDI2_0NoteAttrTyp.None);
						break;
					case hashCalc("o"):		//D+
						midipacket = UMP(MessageType.MIDI2, 0x0, MIDI2_0Cmd.NoteOn, 0x0, cast(ubyte)(noteBase + 14), MIDI2_0NoteAttrTyp.None);
						break;
					case hashCalc("num0"):	//D#+
						midipacket = UMP(MessageType.MIDI2, 0x0, MIDI2_0Cmd.NoteOn, 0x0, cast(ubyte)(noteBase + 15), MIDI2_0NoteAttrTyp.None);
						break;
					case hashCalc("p"):		//E+
						midipacket = UMP(MessageType.MIDI2, 0x0, MIDI2_0Cmd.NoteOn, 0x0, cast(ubyte)(noteBase + 16), MIDI2_0NoteAttrTyp.None);
						break;
					case hashCalc("["):		//F+
						midipacket = UMP(MessageType.MIDI2, 0x0, MIDI2_0Cmd.NoteOn, 0x0, cast(ubyte)(noteBase + 17), MIDI2_0NoteAttrTyp.None);
						break;
					case hashCalc("equals")://F#+
						midipacket = UMP(MessageType.MIDI2, 0x0, MIDI2_0Cmd.NoteOn, 0x0, cast(ubyte)(noteBase + 18), MIDI2_0NoteAttrTyp.None);
						break;
					case hashCalc("]"):		//G+
						midipacket = UMP(MessageType.MIDI2, 0x0, MIDI2_0Cmd.NoteOn, 0x0, cast(ubyte)(noteBase + 19), MIDI2_0NoteAttrTyp.None);
						break;
					default:
						break;
				}
				if (midipacket.msgType == MessageType.MIDI2) {
					fmsynth.midiReceive(midipacket, uint.max);
				}
			}
		} else if ((state & StateFlags.deviceInitialized) && (state & StateFlags.keyPressed)) {
			state ^= StateFlags.keyPressed;
			UMP midipacket;// = UMP(MessageType.MIDI2, 0x0, MIDI2_0Cmd.NoteOff, 0x0, noteBase, MIDI2_0NoteAttrTyp.None);
			uint val = uint.max;
			switch (id) {
				case hashCalc("q"):		//C
					midipacket = UMP(MessageType.MIDI2, 0x0, MIDI2_0Cmd.NoteOff, 0x0, noteBase, MIDI2_0NoteAttrTyp.None);
					break;
				case hashCalc("num2"):	//C#
					midipacket = UMP(MessageType.MIDI2, 0x0, MIDI2_0Cmd.NoteOff, 0x0, cast(ubyte)(noteBase + 1), MIDI2_0NoteAttrTyp.None);
					break;
				case hashCalc("w"):		//D
					midipacket = UMP(MessageType.MIDI2, 0x0, MIDI2_0Cmd.NoteOff, 0x0, cast(ubyte)(noteBase + 2), MIDI2_0NoteAttrTyp.None);
					break;
				case hashCalc("num3"):	//D#
					midipacket = UMP(MessageType.MIDI2, 0x0, MIDI2_0Cmd.NoteOff, 0x0, cast(ubyte)(noteBase + 3), MIDI2_0NoteAttrTyp.None);
					break;
				case hashCalc("e"):		//E
					midipacket = UMP(MessageType.MIDI2, 0x0, MIDI2_0Cmd.NoteOff, 0x0, cast(ubyte)(noteBase + 4), MIDI2_0NoteAttrTyp.None);
					break;
				case hashCalc("r"):		//F
					midipacket = UMP(MessageType.MIDI2, 0x0, MIDI2_0Cmd.NoteOff, 0x0, cast(ubyte)(noteBase + 5), MIDI2_0NoteAttrTyp.None);
					break;
				case hashCalc("num5"):	//F#
					midipacket = UMP(MessageType.MIDI2, 0x0, MIDI2_0Cmd.NoteOff, 0x0, cast(ubyte)(noteBase + 6), MIDI2_0NoteAttrTyp.None);
					break;
				case hashCalc("t"):		//G
					midipacket = UMP(MessageType.MIDI2, 0x0, MIDI2_0Cmd.NoteOff, 0x0, cast(ubyte)(noteBase + 7), MIDI2_0NoteAttrTyp.None);
					break;
				case hashCalc("num6"):	//G#
					midipacket = UMP(MessageType.MIDI2, 0x0, MIDI2_0Cmd.NoteOff, 0x0, cast(ubyte)(noteBase + 8), MIDI2_0NoteAttrTyp.None);
					break;
				case hashCalc("y"):		//A
					midipacket = UMP(MessageType.MIDI2, 0x0, MIDI2_0Cmd.NoteOff, 0x0, cast(ubyte)(noteBase + 9), MIDI2_0NoteAttrTyp.None);
					break;
				case hashCalc("num7"):	//A#
					midipacket = UMP(MessageType.MIDI2, 0x0, MIDI2_0Cmd.NoteOff, 0x0, cast(ubyte)(noteBase + 10), MIDI2_0NoteAttrTyp.None);
					break;
				case hashCalc("u"):		//B
					midipacket = UMP(MessageType.MIDI2, 0x0, MIDI2_0Cmd.NoteOff, 0x0, cast(ubyte)(noteBase + 11), MIDI2_0NoteAttrTyp.None);
					break;
				case hashCalc("i"):		//C+
					midipacket = UMP(MessageType.MIDI2, 0x0, MIDI2_0Cmd.NoteOff, 0x0, cast(ubyte)(noteBase + 12), MIDI2_0NoteAttrTyp.None);
					break;
				case hashCalc("num9"):	//C#+
					midipacket = UMP(MessageType.MIDI2, 0x0, MIDI2_0Cmd.NoteOff, 0x0, cast(ubyte)(noteBase + 13), MIDI2_0NoteAttrTyp.None);
					break;
				case hashCalc("o"):		//D+
					midipacket = UMP(MessageType.MIDI2, 0x0, MIDI2_0Cmd.NoteOff, 0x0, cast(ubyte)(noteBase + 14), MIDI2_0NoteAttrTyp.None);
					break;
				case hashCalc("num0"):	//D#+
					midipacket = UMP(MessageType.MIDI2, 0x0, MIDI2_0Cmd.NoteOff, 0x0, cast(ubyte)(noteBase + 15), MIDI2_0NoteAttrTyp.None);
					break;
				case hashCalc("p"):		//E+
					midipacket = UMP(MessageType.MIDI2, 0x0, MIDI2_0Cmd.NoteOff, 0x0, cast(ubyte)(noteBase + 16), MIDI2_0NoteAttrTyp.None);
					break;
				case hashCalc("["):		//F+
					midipacket = UMP(MessageType.MIDI2, 0x0, MIDI2_0Cmd.NoteOff, 0x0, cast(ubyte)(noteBase + 17), MIDI2_0NoteAttrTyp.None);
					break;
				case hashCalc("equals")://F#+
					midipacket = UMP(MessageType.MIDI2, 0x0, MIDI2_0Cmd.NoteOff, 0x0, cast(ubyte)(noteBase + 18), MIDI2_0NoteAttrTyp.None);
					break;
				case hashCalc("]"):		//G+
					midipacket = UMP(MessageType.MIDI2, 0x0, MIDI2_0Cmd.NoteOff, 0x0, cast(ubyte)(noteBase + 19), MIDI2_0NoteAttrTyp.None);
					break;
				case hashCalc("F1"):
					midipacket = UMP(MessageType.MIDI2, 0x0, MIDI2_0Cmd.CtrlCh, state & StateFlags.upperHalf ? 0x8 : 0x0, bank0, bank1);
					level[state & StateFlags.upperHalf ? 1 : 0][bank1][bank0] += 1;
					val = level[state & StateFlags.upperHalf ? 1 : 0][bank1][bank0] * 0x01_01_01_01;
					refreshDisplay();
					break;
				case hashCalc("F2"):
					midipacket = UMP(MessageType.MIDI2, 0x0, MIDI2_0Cmd.CtrlCh, state & StateFlags.upperHalf ? 0x8 : 0x0, bank0, bank1);
					level[state & StateFlags.upperHalf ? 1 : 0][bank1][bank0] -= 1;
					val = level[state & StateFlags.upperHalf ? 1 : 0][bank1][bank0] * 0x01_01_01_01;
					refreshDisplay();
					break;
				case hashCalc("F3"):
					midipacket = UMP(MessageType.MIDI2, 0x0, MIDI2_0Cmd.CtrlCh, state & StateFlags.upperHalf ? 0x8 : 0x0, bank0, bank1);
					level[state & StateFlags.upperHalf ? 1 : 0][bank1][bank0] += 8;
					val = level[state & StateFlags.upperHalf ? 1 : 0][bank1][bank0] * 0x01_01_01_01;
					refreshDisplay();
					break;
				case hashCalc("F4"):
					midipacket = UMP(MessageType.MIDI2, 0x0, MIDI2_0Cmd.CtrlCh, state & StateFlags.upperHalf ? 0x8 : 0x0, bank0, bank1);
					level[state & StateFlags.upperHalf ? 1 : 0][bank1][bank0] -= 8;
					val = level[state & StateFlags.upperHalf ? 1 : 0][bank1][bank0] * 0x01_01_01_01;
					refreshDisplay();
					break;
				case hashCalc("F5"):
					bank0++;
					if (bank0 > 31) bank0 = 0 ;
					refreshDisplay();
					break;
				case hashCalc("F6"):
					bank0--;
					if (bank0 > 31) bank0 = 31 ;
					refreshDisplay();
					break;
				case hashCalc("F7"):
					bank1++;
					if (bank1 > 5) bank1 = 0 ;
					refreshDisplay();
					break;
				case hashCalc("F8"):
					bank1--;
					if (bank1 > 5) bank1 = 5 ;
					refreshDisplay();
					break;
				case hashCalc("F9"):
					state ^= StateFlags.upperHalf;
					refreshDisplay();
					break;
				case hashCalc("OctUp"):
					noteBase += 12;
					break;
				case hashCalc("OctDown"):
					noteBase -= 12;
					break;
				default:
					break;
			}
			if (midipacket.msgType == MessageType.MIDI2) {
				fmsynth.midiReceive(midipacket, val);
			}
		}
	}
	public void midiInCallback(ubyte[] data, size_t timestamp) @nogc nothrow {
		UMP midipkt = UMP(MessageType.MIDI1, 0, data[0]>>4, data[0 & 0xF]);
		if (data.length > 1)
			midipkt.bytes[2] = data[1];
		if (data.length > 2)
			midipkt.bytes[3] = data[2];
		fmsynth.midiReceive(midipkt);
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
