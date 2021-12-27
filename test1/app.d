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
	uint			state;
	ubyte			noteBase = 60;
	enum StateFlags {
		isRunning		=	1<<0,
		driverInitialized=	1<<1,
		deviceInitialized=	1<<2,
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
			//ih.addBinding(BindingCode(ScanCode.GRAVE, 0, Devicetype.Keyboard, 0, KeyModifier.All), InputBinding("grave"));

		}

		adh = new AudioDeviceHandler(48_000, 2, 1024);
		
		initDriver(OS_PREFERRED_DRIVER);
		
	}
	void whereTheMagicHappens() {
		while (state & StateFlags.isRunning) {
			r.refresh();
			ih.test();
		}
		if (mm !is null) {
			writeln(mm.suspendAudioThread());
		}
	}

	public void clearScreen() {
		for (int y ; y < 30 ; y++)
			for (int x ; x < 106 ; x++)
				textOut.writeMapping(x, y, MappingElement(' '));
	}
	
	public void initDriver(int num) {
		clearScreen();

		adh.initAudioDriver(num);

		int line;
		textOut.writeTextToMap(0, line++, 0, "Available devices:");
		textOut.writeTextToMap(0, line, 0, "` ");
		textOut.writeTextToMap(2, line++, 0, "Default");
		foreach (i, key; adh.getDevices) {
			textOut.writeTextToMap(0, line, 0, to!wstring(i + 1));
			textOut.writeTextToMap(2, line++, 0, to!wstring(key));
		}

		state |= StateFlags.driverInitialized;
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
			textOut.writeTextToMap(40, 0, 0, to!wstring(adh.getFormat & 0xFF));
			textOut.writeTextToMap(0, 1, 0, "Synth:");
			textOut.writeTextToMap(7, 1, 0, "QM816");
		} catch (AudioInitException e) {
			textOut.writeTextToMap(14, 0, 0, to!wstring(e.msg));
		}
		mm = new ModuleManager(adh, 192, 10);
		fmsynth = new QM816();
		mm.addModule(fmsynth, null, null, [0,1], [0,1]);

		//Initialize audio thread
		ThreadID status = mm.runAudioThread();
		if (status == ThreadID.init)
			throw new Exception("Audio thread error!");

		state |= StateFlags.deviceInitialized;
	}

	public void keyEvent(uint id, BindingCode code, uint timestamp, bool isPressed) {
		if (isPressed) {
			if (!(state & StateFlags.driverInitialized)) {
				switch (id) {
					case hashCalc("num1"):
						initDriver(0);
						break;
					case hashCalc("num2"):
						initDriver(1);
						break;
					case hashCalc("num3"):
						initDriver(2);
						break;
					case hashCalc("num4"):
						initDriver(3);
						break;
					case hashCalc("num5"):
						initDriver(4);
						break;
					case hashCalc("num6"):
						initDriver(5);
						break;
					case hashCalc("num7"):
						initDriver(6);
						break;
					case hashCalc("num8"):
						initDriver(7);
						break;
					case hashCalc("num9"):
						initDriver(8);
						break;
					case hashCalc("num0"):
						initDriver(9);
						break;
					case hashCalc("grave"):
						initDriver(-1);
						break;
					default:
						break;
				}
			} else if (!(state & StateFlags.deviceInitialized)) {
				switch (id) {
					case hashCalc("num1"):
						initDevice(0);
						break;
					case hashCalc("num2"):
						initDevice(1);
						break;
					case hashCalc("num3"):
						initDevice(2);
						break;
					case hashCalc("num4"):
						initDevice(3);
						break;
					case hashCalc("num5"):
						initDevice(4);
						break;
					case hashCalc("num6"):
						initDevice(5);
						break;
					case hashCalc("num7"):
						initDevice(6);
						break;
					case hashCalc("num8"):
						initDevice(7);
						break;
					case hashCalc("num9"):
						initDevice(8);
						break;
					case hashCalc("num0"):
						initDevice(9);
						break;
					case hashCalc("grave"):
						initDevice(-1);
						break;
					default:
						break;
				}
			} else {
				UMP midipacket;
				switch (id) {
					case hashCalc("q"):		//C
						midipacket = UMP(MessageType.MIDI2, 0x0, MIDI2_0Cmd.NoteOn, 0x0, noteBase, MIDI2_0NoteAttrTyp.None);
						break;
					case hashCalc("num2"):	//C#
						midipacket = UMP(MessageType.MIDI2, 0x0, MIDI2_0Cmd.NoteOn, 0x0, cast(ubyte)(noteBase + 1), 
								MIDI2_0NoteAttrTyp.None);
						break;
					case hashCalc("w"):		//D
						midipacket = UMP(MessageType.MIDI2, 0x0, MIDI2_0Cmd.NoteOn, 0x0, cast(ubyte)(noteBase + 2), 
								MIDI2_0NoteAttrTyp.None);
						break;
					case hashCalc("num3"):	//D#
						midipacket = UMP(MessageType.MIDI2, 0x0, MIDI2_0Cmd.NoteOn, 0x0, cast(ubyte)(noteBase + 3), 
								MIDI2_0NoteAttrTyp.None);
						break;
					case hashCalc("e"):		//E
						midipacket = UMP(MessageType.MIDI2, 0x0, MIDI2_0Cmd.NoteOn, 0x0, cast(ubyte)(noteBase + 4), 
								MIDI2_0NoteAttrTyp.None);
						break;
					case hashCalc("r"):		//F
						midipacket = UMP(MessageType.MIDI2, 0x0, MIDI2_0Cmd.NoteOn, 0x0, cast(ubyte)(noteBase + 5), 
								MIDI2_0NoteAttrTyp.None);
						break;
					case hashCalc("num5"):	//F#
						midipacket = UMP(MessageType.MIDI2, 0x0, MIDI2_0Cmd.NoteOn, 0x0, cast(ubyte)(noteBase + 6), 
								MIDI2_0NoteAttrTyp.None);
						break;
					case hashCalc("t"):		//G
						midipacket = UMP(MessageType.MIDI2, 0x0, MIDI2_0Cmd.NoteOn, 0x0, cast(ubyte)(noteBase + 7), 
								MIDI2_0NoteAttrTyp.None);
						break;
					case hashCalc("num6"):	//G#
						midipacket = UMP(MessageType.MIDI2, 0x0, MIDI2_0Cmd.NoteOn, 0x0, cast(ubyte)(noteBase + 8), 
								MIDI2_0NoteAttrTyp.None);
						break;
					case hashCalc("y"):		//A
						midipacket = UMP(MessageType.MIDI2, 0x0, MIDI2_0Cmd.NoteOn, 0x0, cast(ubyte)(noteBase + 9), 
								MIDI2_0NoteAttrTyp.None);
						break;
					case hashCalc("num7"):	//A#
						midipacket = UMP(MessageType.MIDI2, 0x0, MIDI2_0Cmd.NoteOn, 0x0, cast(ubyte)(noteBase + 10), 
								MIDI2_0NoteAttrTyp.None);
						break;
					case hashCalc("u"):		//B
						midipacket = UMP(MessageType.MIDI2, 0x0, MIDI2_0Cmd.NoteOn, 0x0, cast(ubyte)(noteBase + 11), 
								MIDI2_0NoteAttrTyp.None);
						break;
					case hashCalc("i"):		//C+
						midipacket = UMP(MessageType.MIDI2, 0x0, MIDI2_0Cmd.NoteOn, 0x0, cast(ubyte)(noteBase + 12), 
								MIDI2_0NoteAttrTyp.None);
						break;
					case hashCalc("num9"):	//C#+
						midipacket = UMP(MessageType.MIDI2, 0x0, MIDI2_0Cmd.NoteOn, 0x0, cast(ubyte)(noteBase + 13), 
								MIDI2_0NoteAttrTyp.None);
						break;
					case hashCalc("o"):		//D+
						midipacket = UMP(MessageType.MIDI2, 0x0, MIDI2_0Cmd.NoteOn, 0x0, cast(ubyte)(noteBase + 14), 
								MIDI2_0NoteAttrTyp.None);
						break;
					case hashCalc("num0"):	//D#+
						midipacket = UMP(MessageType.MIDI2, 0x0, MIDI2_0Cmd.NoteOn, 0x0, cast(ubyte)(noteBase + 15), 
								MIDI2_0NoteAttrTyp.None);
						break;
					case hashCalc("p"):		//E+
						midipacket = UMP(MessageType.MIDI2, 0x0, MIDI2_0Cmd.NoteOn, 0x0, cast(ubyte)(noteBase + 16), 
								MIDI2_0NoteAttrTyp.None);
						break;
					case hashCalc("["):		//F+
						midipacket = UMP(MessageType.MIDI2, 0x0, MIDI2_0Cmd.NoteOn, 0x0, cast(ubyte)(noteBase + 17), 
								MIDI2_0NoteAttrTyp.None);
						break;
					case hashCalc("equals")://F#+
						midipacket = UMP(MessageType.MIDI2, 0x0, MIDI2_0Cmd.NoteOn, 0x0, cast(ubyte)(noteBase + 18), 
								MIDI2_0NoteAttrTyp.None);
						break;
					case hashCalc("]"):		//G+
						midipacket = UMP(MessageType.MIDI2, 0x0, MIDI2_0Cmd.NoteOn, 0x0, cast(ubyte)(noteBase + 19), 
								MIDI2_0NoteAttrTyp.None);
						break;
					default:
						break;
				}
				if (midipacket.msgType == MessageType.MIDI2) {
					fmsynth.midiReceive([midipacket.base, uint.max, 0, 0],0);
				}
			}
		} else if (state & StateFlags.deviceInitialized) {
			UMP midipacket;
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
				default:
					break;
			}
			if (midipacket.msgType == MessageType.MIDI2) {
				fmsynth.midiReceive([midipacket.base, uint.max, 0, 0],0);
			}
		}
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