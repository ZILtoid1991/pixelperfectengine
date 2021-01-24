/*
 * Copyright (C) 2015-2017, by Laszlo Szeremi under the Boost license.
 *
 * Pixel Perfect Engine, config module
 */

module PixelPerfectEngine.system.config;

//import std.xml;
import std.file;
import std.stdio;
import std.string;
import std.conv;
//import std.csv;

import PixelPerfectEngine.system.input.handler;
import PixelPerfectEngine.system.exc;
import PixelPerfectEngine.system.etc;
import PixelPerfectEngine.system.dictionary;
import PixelPerfectEngine.graphics.outputScreen;

import bindbc.sdl;

import sdlang;
/**
 * Defines a single keybinding.
 */
public struct KeyBinding {
	BindingCode		bc;			///The code that will be used for the keybinding.
	string			name;		///The name of the keybinding.
	float[2]		deadzones;	///Defines a deadzone for the axis.
	bool			axisAsButton;///True if axis is emulating a button outside of deadzone.
}

/**
 * Stores basic InputDevice info alongside with some additional settings
 */
public struct InputDeviceData{
	public int deviceNumber;
	public Devicetype type;
	public bool enableForceFeedback;
	public string name;
	public KeyBinding[] keyBindingList;
	public this(int deviceNumber, Devicetype type, string name){
		this.deviceNumber = deviceNumber;
		this.type = type;
		this.name = name;
	}
}
/**
 * Handles configuration files, like key configurations, 
 */
public class ConfigurationProfile {
	public static const ubyte[string] keymodifierStrings;
	public static const string[ubyte] joymodifierStrings;
	public static const string[Devicetype] devicetypeStrings;
	private static Dictionary keyNameDict, joyButtonNameDict, joyAxisNameDict;
	public int sfxVol, musicVol;
	public int threads;
	public string screenMode, resolution, scalingQuality, driver;
	//public string[string] videoSettings;
	public KeyBinding[] keyBindingList;
	public InputDeviceData[] inputDevices;	///Stores all input devices and keybindings
	private string path;
	///Stores ancillary tags to be serialized into the config file
	protected Tag[] ancillaryTags;
	private static string vaultPath;
	private SDL_DisplayMode[] videoModes;
	//public AuxillaryElements auxillaryElements[];
	public string appName;
	public string appVers;
	/// Initializes a basic configuration profile. If [vaultPath] doesn't have any configfiles, restores it from defaults.
	public this(){
		path = vaultPath ~ "config.sdl";
		if(exists(path)){
			restore();
		}else{
			std.file.copy("../system/defaultConfig.sdl",path);
			restore();
		}
	}

	static this(){
		keymodifierStrings =
				["none"	: KeyModifier.None, "Shift": KeyModifier.Shift, "Ctrl": KeyModifier.Ctrl, "Alt": KeyModifier.Alt, 
						"GUI": KeyModifier.GUI, "NumLock": KeyModifier.NumLock, "CapsLock": KeyModifier.CapsLock, "Mode": KeyModifier.Mode,
						"ScrollLock": KeyModifier.ScrollLock, "All": KeyModifier.All];
		joymodifierStrings = [0x00: "button",0x04: "dpad",0x08: "axis"];
		devicetypeStrings = [Devicetype.Joystick: "joystick", Devicetype.Keyboard: "keyboard", Devicetype.Mouse: "mouse",
				Devicetype.Touchscreen: "touchscreen" ];
		//keyNameDict = new Dictionary("../system/keycodeNamings.sdl");
		keyNameDict = new Dictionary(parseFile("../system/scancodes.sdl"));
		Tag xinput = parseFile("../system/xinputCodes.sdl");
		joyButtonNameDict = new Dictionary(xinput.expectTag("button"));
		joyAxisNameDict = new Dictionary(xinput.expectTag("axis"));
	}
	///Restores configuration profile
	public void restore() {
		Tag root;

		try {
			root = parseFile(path);
			foreach(Tag t0; root.tags) {
				if(t0.name == "audio") {		//get values for the audio subsystem
					sfxVol = t0.getTagValue!int("soundVol", 100);
					musicVol = t0.getTagValue!int("musicVol", 100);
				} else if(t0.name == "video") {	//get values for the video subsystem
					foreach(Tag t1; t0.tags ){
						switch(t1.name){
							case "driver": driver = t1.getValue!string("software"); break;
							case "scaling": scalingQuality = t1.getValue!string("nearest"); break;
							case "screenMode": driver = t1.getValue!string("windowed"); break;
							case "resolution": driver = t1.getValue!string("0"); break;
							case "threads": threads = t1.getValue!int(-1); break;
							default: break;
						}
					}
				} else if(t0.name == "input") {
					foreach(Tag t1; t0.tags) {
						switch(t1.name) {
							case "device":
								InputDeviceData device;
								device.name = t1.getValue!string("");
								device.deviceNumber = t1.getAttribute!int("devNum");
								switch(t1.expectAttribute!string("type")){
									case "keyboard":
										device.type = Devicetype.Keyboard;
										foreach(Tag t2; t1.tags){
											if(t2.name is null){
												KeyBinding kb;
												kb.name = t2.expectValue!string();
												kb.bc.deviceNum = cast(ubyte)device.deviceNumber;
												kb.bc.deviceTypeID = Devicetype.Keyboard;
												kb.bc.modifierFlags = stringToKeymod(t2.getAttribute!string("keyMod", "None"));
												kb.bc.keymodIgnore = stringToKeymod(t2.getAttribute!string("keyModIgnore", "All"));
												kb.bc.buttonNum = cast(ushort)(t2.getAttribute!int("code", keyNameDict.decode(t2.getAttribute!string("name"))));
												keyBindingList ~= kb;
											}
										}
										break;
									case "joystick":
										device.type = Devicetype.Joystick;
										foreach(Tag t2; t1.tags) {		//parse each individual binding
											if(t2.name is null) {
												KeyBinding kb;
												kb.name = t2.expectValue!string();
												kb.bc.deviceNum = cast(ubyte)device.deviceNumber;
												kb.bc.deviceTypeID = Devicetype.Joystick;
												switch(t2.getAttribute!string("keyMod")){
													case "dpad":
														kb.bc.modifierFlags = JoyModifier.DPad;
														goto default;
													case "axis":
														kb.bc.modifierFlags = JoyModifier.Axis;
														kb.deadzones[0] = t2.getAttribute!float("deadZone0");
														kb.deadzones[1] = t2.getAttribute!float("deadZone1");
														kb.axisAsButton = t2.getAttribute!bool("axisAsButton");
														goto default;
													default:
														kb.bc.buttonNum = cast(ushort)t2.getAttribute!int("code", joyButtonNameDict.decode(t2.getAttribute!string("name")));
														break;
												}
												keyBindingList ~= kb;
											} else if(t2.name == "enableForceFeedback") {
												device.enableForceFeedback = t2.getValue!bool(true);
											}
										}
										break;
									case "mouse":
										device.type = Devicetype.Mouse;
										foreach(Tag t2; t1.tags){
											if(t2.name is null){
												//const ushort scanCode = cast(ushort)t2.getAttribute!int("code");
												KeyBinding kb;
												kb.name = t2.expectValue!string();
												kb.bc.deviceTypeID = Devicetype.Mouse;
												//keyBindingList ~= KeyBinding(0, scanCode, devicenumber, t2.expectValue!string(), Devicetype.MOUSE);
											}
										}
										break;
									default:
										//device = InputDeviceData(devicenumber, Devicetype.KEYBOARD, name);
										break;
								}
								inputDevices ~= device;
								break;
							default: break;
						}
					}
				} else {
					//collect all ancillary tags into an array
					ancillaryTags ~= t0;
				}
			}
		}
		catch(ParseException e){
			writeln(e.msg);
		}



	}
	public void store(){
		Tag root = new Tag(null, null);		//, [Value(appName), Value(appVers)]

		Tag t0 = new Tag(root, null, "audio");
		new Tag(t0, null, "soundVol", [Value(sfxVol)]);
		new Tag(t0, null, "musicVolt", [Value(musicVol)]);

		Tag t1 = new Tag(root, null, "video");
		new Tag(t1, null, "driver", [Value(driver)]);
		new Tag(t1, null, "scaling", [Value(scalingQuality)]);
		new Tag(t1, null, "screenMode", [Value(screenMode)]);
		new Tag(t1, null, "resolution", [Value(resolution)]);
		new Tag(t1, null, "threads", [Value(threads)]);

		Tag t2 = new Tag(root, null, "input");
		foreach (InputDeviceData idd; inputDevices) {
			string devType = devicetypeStrings[idd.type];
			Tag t2_0 = new Tag(t2, null, "device", null, [new Attribute(null, "name",Value(idd.name)), new Attribute(null, 
					"type", Value(devType)), new Attribute(null, "devNum", Value(idd.deviceNumber))]);
			final switch (idd.type) with (Devicetype) {
				case Keyboard:
					foreach (binding ; idd.keyBindingList) {
						Attribute[] attrList = [new Attribute(null, "name", Value(keyNameDict.encode(binding.bc.buttonNum)))];
						if (binding.bc.modifierFlags != KeyModifier.None)
							attrList ~= new Attribute(null, "keyMod", Value(keymodToString(binding.bc.modifierFlags)));
						if (binding.bc.keymodIgnore != KeyModifier.All) 
							attrList ~= new Attribute(null, "keyModIgnore", Value(keymodToString(binding.bc.keymodIgnore)));
						new Tag(t2_0, null, null, [Value(binding.name)], attrList);
					}
					break;
				case Joystick:
					foreach (binding ; idd.keyBindingList) {
						Attribute[] attrList;//= [new Attribute(null, "name", Value(joyButtonNameDict.encode(binding.bc.buttonNum)))];
						switch (binding.bc.modifierFlags) {
							case JoyModifier.Axis:
								attrList = [new Attribute(null, "name", Value(joyAxisNameDict.encode(binding.bc.buttonNum))),
										new Attribute(null, "keyMod", Value(joymodifierStrings[binding.bc.modifierFlags])),
										new Attribute(null, "deadZone0", Value(binding.deadzones[0])),
										new Attribute(null, "deadZone1", Value(binding.deadzones[1]))];
								if (binding.axisAsButton)
									attrList ~= new Attribute(null, "axisAsButton", Value(true));
								break;
							case JoyModifier.DPad:
								attrList = [new Attribute(null, "code", Value(cast(int)(binding.bc.buttonNum))),
										new Attribute(null, "keyMod", Value(joymodifierStrings[binding.bc.modifierFlags]))];
								break;
							default:
								attrList = [new Attribute(null, "name", Value(joyButtonNameDict.encode(binding.bc.buttonNum)))];
								break;
						}
						new Tag(t2_0, null, null, [Value(binding.name)], attrList);
					}
					new Tag(t2_0, null, "enableForceFeedback", [Value(idd.enableForceFeedback)]);
					break;
				case Mouse:
					foreach (binding ; idd.keyBindingList) {
						Attribute[] attrList = [new Attribute(null, "code", Value(cast(int)(binding.bc.buttonNum)))];
						new Tag(t2_0, null, null, [Value(binding.name)], attrList);
					}
					break;
				case Touchscreen:
					break;
			}
		}
		//Tag t3 = new Tag(root, null, "etc");
		foreach(at; ancillaryTags){
			root.add(at);
		}
		string data = root.toSDLDocument();
		std.file.write(path, data);
	}

	public ubyte stringToKeymod(string s) @safe const {
		import std.algorithm.iteration : splitter;
		if(s == "None")	return KeyModifier.None;
		if(s == "All")		return KeyModifier.All;
		auto values = s.splitter(';');
		ubyte result;
		foreach(t ; values){
			result |= keymodifierStrings.get(t,0);
		}
		return result;
	}

	public string keymodToString(const ubyte keymod) @safe pure nothrow const {
		if(keymod == KeyModifier.None)
			return "None";
		if(keymod == KeyModifier.All)
			return "All";
		string result;
		if(keymod & KeyModifier.Shift){
			result ~= "Shift;";
		}
		if(keymod & KeyModifier.Ctrl){
			result ~= "Ctrl;";
		}
		if(keymod & KeyModifier.Alt){
			result ~= "Alt;";
		}
		if(keymod & KeyModifier.GUI){
			result ~= "GUI;";
		}
		if(keymod & KeyModifier.NumLock){
			result ~= "NumLock;";
		}
		if(keymod & KeyModifier.CapsLock){
			result ~= "CapsLock;";
		}
		if(keymod & KeyModifier.Mode){
			result ~= "Mode;";
		}
		if(keymod & KeyModifier.ScrollLock){
			result ~= "ScrollLock;";
		}
		return result[0..$-1];
	}

	public string joymodToString(const ushort s) @safe pure nothrow const {
		switch(s) {
			case JoyModifier.Axis: return "Axis";
			case JoyModifier.DPad: return "DPad";
			default: return "Buttons";
		}
	}
	public void useVideoMode(int mode, OutputScreen window){

	}
	public void autodetectVideoModes(int display = 0){
		int displaymodes = SDL_GetNumDisplayModes(display);
		//writeln(displaymodes);
		//writeln(to!string(SDL_GetError()));
		for(int i ; i <= displaymodes ; i++){
			SDL_DisplayMode d = SDL_DisplayMode();
			if(SDL_GetDisplayMode(display,i,&d) == 0){

				videoModes ~= d;

			}
		}
	}
	public size_t getNumOfVideoModes(){
		return videoModes.length;
	}
	public string videoModeToString(size_t n){
		return to!string(videoModes[n].w) ~ "x" ~ to!string(videoModes[n].h) ~ "@" ~ to!string(videoModes[n].refresh_rate) ~ "Hz";
	}
	public static void setVaultPath(const char* developer, const char* application){
		if (exists("../_debug/")) {
			vaultPath = "../_debug/";
		} else {
			vaultPath = to!string(SDL_GetPrefPath(developer, application));
		}
	}
	public static string getVaultPath(){
		return vaultPath;
	}

}



/*public class VideoMode{
	public int displayIndex, modeIndex;
	public SDL_DisplayMode displaymode;
	public this (){

	}
	public override string toString(){
		return to!string(displaymode.w) ~ "x" ~ to!string(displaymode.h) ~ "@" ~ to!string(displaymode.refresh_rate) ~ "Hz";
	}
}*/
/**
 * Default keywords to look up for common video settings
 */
public enum VideoConfigDefaults : string{
	SCREENMODE		=	"screenMode",
	RESOLUTION		=	"resolution",
	SCALINGQUALITY	=	"scalingQuality",
	DRIVER			=	"driver",
	THREADS			=	"threads",
}
