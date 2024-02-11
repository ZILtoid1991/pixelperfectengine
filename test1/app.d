module test1.app;

import std.stdio;
import std.string;
import std.conv;
import std.format;
import std.random;
import std.typecons : BitFlags;

import bindbc.sdl;

import midi2.types.structs;
import midi2.types.enums;

import pixelperfectengine.concrete.window;
import pixelperfectengine.concrete.windowhandler;
import pixelperfectengine.concrete.eventchainsystem;

import pixelperfectengine.graphics.outputscreen;
import pixelperfectengine.graphics.raster;
import pixelperfectengine.graphics.layers;

import pixelperfectengine.graphics.bitmap;

import pixelperfectengine.system.input;
import pixelperfectengine.system.file;
import pixelperfectengine.system.etc;
import pixelperfectengine.system.systemutility;
import pixelperfectengine.system.config;
import pixelperfectengine.system.timer;

import pixelperfectengine.system.common;

import pixelperfectengine.audio.base.handler;
import pixelperfectengine.audio.base.modulebase;
import pixelperfectengine.audio.base.config;
import pixelperfectengine.audio.base.midiseq;
import pixelperfectengine.audio.m2.seq;
import pixelperfectengine.audio.m2.rw_text;
//import pixelperfectengine.audio.modules.qm816;
import core.thread;
import iota.audio.midi;
import iota.audio.midiin;

import test1.audioconfig;
import test1.preseteditor;
import test1.modulerouter;
import test1.virtmidikeyb;
import test1.midiseq;

/** 
 * Audio subsystem test.
 */
int main(string[] args) {
	initialzeSDL();
	AudioDevKit app = new AudioDevKit(args);
	app.whereTheMagicHappens();
	return 0;
}
///Top level window, so far only containing the MenuBar.
public class TopLevelWindow : Window {
	MenuBar mb;
	AudioDevKit app;
	public this(int width, int height, AudioDevKit app) {
		super(Box(0, 0, width, height), ""d, [], null);
		this.app = app;
		PopUpMenuElement[] menuElements;

		menuElements ~= new PopUpMenuElement("file", "File", "", [
			new PopUpMenuElement("new", "New project"),
			new PopUpMenuElement("load", "Load project"),
			new PopUpMenuElement("save", "Save project"),
			new PopUpMenuElement("saveAs", "Save project as"),
			new PopUpMenuElement("exit", "Exit application", "Alt + F4")
		]);

		menuElements ~= new PopUpMenuElement("edit", "Edit", "", [
			new PopUpMenuElement("undo", "Undo"),
			new PopUpMenuElement("redo", "Redo"),
			new PopUpMenuElement("copy", "Copy"),
			new PopUpMenuElement("cut", "Cut"),
			new PopUpMenuElement("paste", "Paste")
		]);

		menuElements ~= new PopUpMenuElement("view", "View", "", [
			new PopUpMenuElement("router", "Routing layout editor"),
			new PopUpMenuElement("virtmidikeyb", "Virtual MIDI keyboard"),
			new PopUpMenuElement("sequencer", "Sequencer")
		]);

		menuElements ~= new PopUpMenuElement("audio", "Audio", "", [
			new PopUpMenuElement("stAudio", "Start/Stop Audio thread"),
			new PopUpMenuElement("cfgcompile", "Compile current configuration"),
		]);

		menuElements ~= new PopUpMenuElement("help", "Help", "", [
			new PopUpMenuElement("helpFile", "Content"),
			new PopUpMenuElement("about", "About")
		]);

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
	SequencerM1		midiSeq;
	SequencerM2		m2Seq;
	
	WindowHandler	wh;
	Window			tlw;
	PresetEditor	preEdit;
	VirtualMidiKeyboard virtMIDIkeyb;
	ModuleRouter	router;
	ModuleConfig	mcfg;
	BitFlags!StateFlags	state;
	UndoableStack	eventStack;
	string			selectedModID;
	string			path;
	
	//ubyte[32][6][2]	level;
	enum StateFlags {
		isRunning		=	1<<0,
		audioThreadRunning=	1<<1,
		configurationCompiled=1<<2,
		m2Toggle		=	1<<3,
	}
	
	public this(string[] args) {
		state.isRunning = true;
		//Image fontSource = loadImage(File("../system/cp437_8x16.png"));
		output = new OutputScreen("PixelPerfectEngine Audio Development Kit", 848 * 2, 480 * 2);
		mainRaster = new Raster(848,480,output,0);
		windowing = new SpriteLayer(RenderingMode.Copy);
		//windowing.addSprite(new Bitmap8Bit(848, 480), -65_536, 0, 0);
		wh = new WindowHandler(1696,960,848,480,windowing);
		mainRaster.loadPalette(loadPaletteFromFile(getPathToAsset("/system/concreteGUIE1.tga")));
		mainRaster.addLayer(windowing, 0);
		INIT_CONCRETE();
		{
			Bitmap8Bit[] customGUIElems = loadBitmapSheetFromFile!Bitmap8Bit(
					getPathToAsset("/system/concreteGUI_ADK.tga"), 16, 16);
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
		{
			Bitmap8Bit[] customGUIElems = loadBitmapSheetFromFile!Bitmap8Bit(
					getPathToAsset("/system/concreteGUIE2.tga"), 16, 16);
			globalDefaultStyle.setImage(customGUIElems[0], "playA");
			globalDefaultStyle.setImage(customGUIElems[1], "playB");
			globalDefaultStyle.setImage(customGUIElems[2], "stopA");
			globalDefaultStyle.setImage(customGUIElems[3], "stopB");
		}

		ih = new InputHandler();
		ih.systemEventListener = this;
		ih.inputListener = this;
		ih.mouseListener = wh;
		WindowElement.inputHandler = ih;
		{
			import pixelperfectengine.system.input.scancode;
			ih.addBinding(BindingCode(ScanCode.Q, 0, Devicetype.Keyboard, 0, KeyModifier.LockKeys), 
					InputBinding("VirtMIDIKB-C-0"));
			ih.addBinding(BindingCode(ScanCode.n2, 0, Devicetype.Keyboard, 0, KeyModifier.LockKeys), 
					InputBinding("VirtMIDIKB-C#0"));
			ih.addBinding(BindingCode(ScanCode.W, 0, Devicetype.Keyboard, 0, KeyModifier.LockKeys), 
					InputBinding("VirtMIDIKB-D-0"));
			ih.addBinding(BindingCode(ScanCode.n3, 0, Devicetype.Keyboard, 0, KeyModifier.LockKeys), 
					InputBinding("VirtMIDIKB-D#0"));
			ih.addBinding(BindingCode(ScanCode.E, 0, Devicetype.Keyboard, 0, KeyModifier.LockKeys), 
					InputBinding("VirtMIDIKB-E-0"));
			ih.addBinding(BindingCode(ScanCode.R, 0, Devicetype.Keyboard, 0, KeyModifier.LockKeys), 
					InputBinding("VirtMIDIKB-F-0"));
			ih.addBinding(BindingCode(ScanCode.n5, 0, Devicetype.Keyboard, 0, KeyModifier.LockKeys), 
					InputBinding("VirtMIDIKB-F#0"));
			ih.addBinding(BindingCode(ScanCode.T, 0, Devicetype.Keyboard, 0, KeyModifier.LockKeys), 
					InputBinding("VirtMIDIKB-G-0"));
			ih.addBinding(BindingCode(ScanCode.n6, 0, Devicetype.Keyboard, 0, KeyModifier.LockKeys), 
					InputBinding("VirtMIDIKB-G#0"));
			ih.addBinding(BindingCode(ScanCode.Y, 0, Devicetype.Keyboard, 0, KeyModifier.LockKeys), 
					InputBinding("VirtMIDIKB-A-0"));
			ih.addBinding(BindingCode(ScanCode.n7, 0, Devicetype.Keyboard, 0, KeyModifier.LockKeys), 
					InputBinding("VirtMIDIKB-A#0"));
			ih.addBinding(BindingCode(ScanCode.U, 0, Devicetype.Keyboard, 0, KeyModifier.LockKeys), 
					InputBinding("VirtMIDIKB-B-0"));
			ih.addBinding(BindingCode(ScanCode.I, 0, Devicetype.Keyboard, 0, KeyModifier.LockKeys), 
					InputBinding("VirtMIDIKB-C-1"));
			ih.addBinding(BindingCode(ScanCode.n9, 0, Devicetype.Keyboard, 0, KeyModifier.LockKeys), 
					InputBinding("VirtMIDIKB-C#1"));
			ih.addBinding(BindingCode(ScanCode.O, 0, Devicetype.Keyboard, 0, KeyModifier.LockKeys), 
					InputBinding("VirtMIDIKB-D-1"));
			ih.addBinding(BindingCode(ScanCode.n0, 0, Devicetype.Keyboard, 0, KeyModifier.LockKeys), 
					InputBinding("VirtMIDIKB-D#1"));
			ih.addBinding(BindingCode(ScanCode.P, 0, Devicetype.Keyboard, 0, KeyModifier.LockKeys), 
					InputBinding("VirtMIDIKB-E-1"));
			ih.addBinding(BindingCode(ScanCode.LEFTBRACKET, 0, Devicetype.Keyboard, 0, KeyModifier.LockKeys), 
					InputBinding("VirtMIDIKB-F-1"));
			ih.addBinding(BindingCode(ScanCode.EQUALS, 0, Devicetype.Keyboard, 0, KeyModifier.LockKeys), 
					InputBinding("VirtMIDIKB-F#1"));
			ih.addBinding(BindingCode(ScanCode.RIGHTBRACKET, 0, Devicetype.Keyboard, 0, KeyModifier.LockKeys), 
					InputBinding("VirtMIDIKB-G-1"));
			ih.addBinding(BindingCode(ScanCode.HOME, 0, Devicetype.Keyboard, 0, KeyModifier.LockKeys), 
					InputBinding("VirtMIDIKB-oct+"));
			ih.addBinding(BindingCode(ScanCode.END, 0, Devicetype.Keyboard, 0, KeyModifier.LockKeys), 
					InputBinding("VirtMIDIKB-oct-"));
			ih.addBinding(BindingCode(ScanCode.PAGEUP, 0, Devicetype.Keyboard, 0, KeyModifier.LockKeys), 
					InputBinding("VirtMIDIKB-note+"));
			ih.addBinding(BindingCode(ScanCode.PAGEDOWN, 0, Devicetype.Keyboard, 0, KeyModifier.LockKeys), 
					InputBinding("VirtMIDIKB-note-"));
		}

		AudioDeviceHandler.initAudioDriver(OS_PREFERRED_DRIVER);
	
		initMIDI();
		Bitmap4Bit background = new Bitmap4Bit(848, 480);
		wh.addBackground(background);
		wh.addWindow(new AudioConfig(this));
		eventStack = new UndoableStack(10);
	}
	void whereTheMagicHappens() {
		while (state.isRunning) {
			mainRaster.refresh();
			ih.test();
			timer.test();
		}
		version (linux) midiIn.stop();
		if (mm !is null) {
			synchronized
				writeln(mm.suspendAudioThread());
		}
	}
	public void onStart() {
		tlw = new TopLevelWindow(848, 480, this);
		wh.setBaseWindow(tlw);
		mcfg = new ModuleConfig(mm);
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
			case "stAudio":
				onAudioThreadSwitch();
				break;
			case "cfgcompile":
				onCompileAudioConfig();
				break;
			case "exit":
				state.isRunning = false;
				break;
			case "new":
				onNew();
				break;
			case "load":
				onLoad();
				break;
			case "save":
				onSave();
				break;
			case "saveAs":
				onSaveAs();
				break;
			case "virtmidikeyb":
				onVirtMIDIKeyb();
				break;
			case "sequencer":
				openSequencer();
				break;
			default: break;
		}
	}
	public void onVirtMIDIKeyb() {
		if (virtMIDIkeyb is null) {
			virtMIDIkeyb = new VirtualMidiKeyboard(this);
			wh.addWindow(virtMIDIkeyb);
		}
	}
	public void onVirtMIDIKeybClose() {
		virtMIDIkeyb = null;
	}
	public void onAudioThreadSwitch() {
		if (mcfg is null) {
			wh.message("Error!", "Audio configuration profile has not been initialized!");
		} else {
			if (state.audioThreadRunning) {
				const int errorCode = mm.suspendAudioThread();
				state.audioThreadRunning = false;
				if (errorCode) {
					wh.message("Audio thread error!", "An error occured during audio thread runtime!\nError code:" ~ 
							errorCode.to!dstring);
				}
			} else {
				const int errorCode = mm.runAudioThread();
				if (!errorCode) {
					state.audioThreadRunning = true;
				} else {
					wh.message("Audio thread error!", "Failed to initialize audio thread!\nError code:" ~ errorCode.to!dstring);
				}
			}
		}
	}
	public void onCompileAudioConfig() {
		if (mcfg is null) {
			wh.message("Error!", "Audio configuration profile has not been initialized!");
		} else {
			try {
				mcfg.compile(state.audioThreadRunning);
				if (mcfg.midiRouting.length) {
					midiSeq = new SequencerM1(mcfg.modules, mcfg.midiRouting, mcfg.midiGroups);
					//mm.midiSeq = midiSeq;
				} else {
					midiSeq = null;
				}
				m2Seq = new SequencerM2();
			} catch (Exception e) {
				writeln(e);
			}
		}
	}
	public void onNew() {
		mcfg = new ModuleConfig(mm);
	}
	public void onLoad() {
		import pixelperfectengine.concrete.dialogs.filedialog;
		wh.addWindow(new FileDialog("Load audio configuration file.", "loadConfigDialog", &onLoadConfigurationFile, 
			[FileDialog.FileAssociationDescriptor("SDLang file", ["*.sdl"])], "./"));
	}
	public void onLoadConfigurationFile(Event ev) {
		FileEvent fe = cast(FileEvent)ev;
		path = fe.getFullPath;
		File f = File(path);
		char[] c;
		c.length = cast(size_t)f.size();
		f.rawRead(c);
		mcfg.loadConfig(c.idup);
		if (router !is null) {
			router.refreshRoutingTable();
			router.refreshModuleList();
		}
	}
	public void onSave() {
		if (!path.length) {
			onSaveAs();
		} else {
			try {
				mcfg.save(path);
			} catch(Exception e) {
				debug writeln(e);
			}
		}
	}
	public void onSaveAs() {
		import pixelperfectengine.concrete.dialogs.filedialog;
		wh.addWindow(new FileDialog("Save audio configuration file.", "saveConfigDialog", &onSaveConfigurationFile, 
			[FileDialog.FileAssociationDescriptor("SDLang file", ["*.sdl"])], "./", true));
	}
	public void onSaveConfigurationFile(Event ev) {
		FileEvent fe = cast(FileEvent)ev;
		path = fe.getFullPath;
		try {
			mcfg.save(path);
		} catch(Exception e) {
			debug writeln(e);
		}
	}
	public void openSequencer() {
		if (m2Seq is null && midiSeq is null) wh.message("Error!", "Audio has not been initialized!");
		else wh.addWindow(new SequencerCtrl(this));
	}
	public void onMIDILoad() {
		import pixelperfectengine.concrete.dialogs.filedialog;
		wh.addWindow(new FileDialog("Load MIDI file.", "loadMidiDialog", &onMIDIFileLoad, 
			[FileDialog.FileAssociationDescriptor("MIDI file", ["*.mid"]), 
			FileDialog.FileAssociationDescriptor("M2 file", ["*.m2"])], "./"));
	}
	public void onMIDIFileLoad(Event ev) {
		import mididi;
		import pixelperfectengine.audio.m2.rw;
		FileEvent fe = cast(FileEvent)ev;
		switch (fe.extension) {
			case ".mid":
				if (midiSeq !is null) {
					midiSeq.openMIDI(readMIDIFile(fe.getFullPath));
					state.m2Toggle = false;
					mm.midiSeq = midiSeq;
				} else {
					wh.message("Error!", "No routing table has been initialized in current audio configuration!");
				}
				break;
			case ".m2":
				m2Seq.loadSong(loadM2File(fe.getFullPath), mcfg);
				state.m2Toggle = true;
				mm.midiSeq = m2Seq;
				break;
			default:
				break;
		}
	}
	public void seqStart() {
		if (state.m2Toggle) m2Seq.start();
		else if (midiSeq) midiSeq.start();
	}
	public void seqStop() {
		if (state.m2Toggle) m2Seq.stop();
		else if (midiSeq) midiSeq.stop();
	}
	public void openRouter() {
		if (router is null)
			router = new ModuleRouter(this);
		if (wh.whichWindow(router) == -1)
			wh.addWindow(router);
		
	}
	public void openPresetEditor() {
		if (selectedModule !is null)
			wh.addWindow(new PresetEditor(this));
	}
	public void keyEvent(uint id, BindingCode code, uint timestamp, bool isPressed) {
		if (virtMIDIkeyb !is null) {
			if (virtMIDIkeyb.keyEventReceive(id, code, timestamp, isPressed))
				return;
		}
	}
	public void midiInCallback(ubyte[] data, size_t timestamp) @nogc nothrow {
		if (selectedModule !is null) {
			UMP msb = UMP(MessageType.MIDI1, 0, 0, 0);
			msb.bytes[2] = data.length > 0 ? data[0] : 0;
			msb.bytes[1] = data.length > 1 ? data[1] : 0;
			msb.bytes[0] = data.length > 2 ? data[2] : 0;
			selectedModule.midiReceive(msb);
		}
	}
	public void axisEvent(uint id, BindingCode code, uint timestamp, float value) {
		
	}
	
	public void onQuit() {
		state.isRunning = false;
	}
	
	public void controllerAdded(uint id) {
		
	}
	
	public void controllerRemoved(uint id) {
		
	}
	
}
