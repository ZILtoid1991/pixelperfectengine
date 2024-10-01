/*
 * Copyright (C) 2015-2017, by Laszlo Szeremi under the Boost license.
 *
 * Pixel Perfect Engine, config module
 */

module pixelperfectengine.system.config;

//import std.xml;
import std.file;
import std.stdio;
import std.string;
import std.conv;
//import std.csv;

import pixelperfectengine.system.input.handler;
import pixelperfectengine.system.file;
import pixelperfectengine.system.exc;
import pixelperfectengine.system.etc;
import pixelperfectengine.system.dictionary;
import pixelperfectengine.graphics.outputscreen;

//import bindbc.sdl;

import sdlang;
/**
 * Defines a single keybinding.
 */
public struct KeyBinding {
	BindingCode		bc;			///The code that will be used for the keybinding.
	string			name;		///The name of the keybinding.
	float[2]		deadzones;	///Defines a deadzone for the axis.
	bool			axisAsButton;///True if axis is emulating a button outside of deadzone.

	///Converts the struct's other portion into an InputBinding
	public InputBinding toInputBinding() @nogc @safe pure nothrow const {
		import collections.commons : defaultHash;
		return InputBinding(defaultHash(name), axisAsButton ? InputBinding.IS_AXIS_AS_BUTTON : 0, deadzones);
	}
}

/**
 * Stores basic InputDevice info alongside with some additional settings
 */
public struct InputDeviceData{
	public int deviceNumber;			///Number of the device that is being used
	public Devicetype type;				///Type of the device (keyboard, joystick, etc)
	public bool enableForceFeedback;	///Toggles force feedback if device is capable of it
	public string name;					///Name of the device
	public KeyBinding[] keyBindingList;	///List of the Keybindings associated with this device
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
	public static const ubyte[string] keymodifierStrings;		///Key modifier strings, used for reading config files
	public static const string[ubyte] joymodifierStrings;		///Joy modifier strings, used for reading config files
	public static const string[Devicetype] devicetypeStrings;	///Device type strings
	private static Dictionary keyNameDict, joyButtonNameDict, joyAxisNameDict;	///Two-way dictionaries
	public int		sfxVol;			///Sound effects volume (0-100)
	public int		musicVol;		///Music volume (0-100)
	public string	audioDriver;	///Audio driver, null for auto
	public string	audioDevice;	///Audio device, null for auto
	public int		audioFrequency;	///Audio sampling frequency
	public int		audioBufferLen;	///Audio buffer length
	public int		audioFrameLen;	///Audio frame length
	public int		threads;		///Rendering threads (kinda deprecated)
	public string 	screenMode;		///Graphics screen mode
	public string	resolution;		///Resolution, or window size in windowed mode
	public string	scalingQuality;	///Scaling quality (what scaler it uses)
	public string	gfxdriver;		///Graphics driver
	public string	localCountry;	///Localization configuration (country)
	public string	localLang;		///Localization configuration (language)
	//public string[string] videoSettings;
	//public KeyBinding[] keyBindingList;
	public InputDeviceData[] inputDevices;	///Stores all input devices and keybindings
	private string	path;			///Path where the 
	///Stores ancillary tags to be serialized into the config file
	public Tag[] ancillaryTags;
	private static string vaultPath;
	//private SDL_DisplayMode[] videoModes;
	//public AuxillaryElements auxillaryElements[];
	public string appName;					///Name of the application. Can be used to check e.g. version safety.
	public string appVers;					///Version of the application. Can be used to check e.g. version safety.
	/// Initializes a basic configuration profile. If [vaultPath] doesn't have any configfiles, restores it from defaults.
	public this() {
		path = vaultPath ~ "config.sdl";
		if(!exists(path))
			std.file.copy(getPathToAsset("%PATH%/system/defaultConfig.sdl"),path);			
		restore();
	}
	/// Initializes a basic configuration profile with user supplied values. 
	/// If [vaultPath] doesn't have any configfiles, restores it from defaults.
	public this(string filename, string defaultFile) {
		path = vaultPath ~ filename;
		if(!exists(path))
			std.file.copy(defaultFile, path);			
		restore();
	}
	shared static this() {
		keymodifierStrings =
				["none"	: KeyModifier.None, "Shift": KeyModifier.Shift, "Ctrl": KeyModifier.Ctrl, "Alt": KeyModifier.Alt, 
						"GUI": KeyModifier.GUI, "NumLock": KeyModifier.NumLock, "CapsLock": KeyModifier.CapsLock, "Mode": KeyModifier.Mode,
						"ScrollLock": KeyModifier.ScrollLock, "All": KeyModifier.All];
		joymodifierStrings = [0x00: "button",0x04: "dpad",0x08: "axis"];
		devicetypeStrings = [Devicetype.Joystick: "joystick", Devicetype.Keyboard: "keyboard", Devicetype.Mouse: "mouse",
				Devicetype.Touchscreen: "touchscreen" ];
		//keyNameDict = new Dictionary("../system/keycodeNamings.sdl");
		keyNameDict = new Dictionary(parseFile(getPathToAsset("%PATH%/system/scancodes.sdl")));
		Tag xinput = parseFile(getPathToAsset("%PATH%/system/xinputCodes.sdl"));
		joyButtonNameDict = new Dictionary(xinput.expectTag("button"));
		joyAxisNameDict = new Dictionary(xinput.expectTag("axis"));
	}
	///Restores configuration profile from a file.
	public void restore() {
		Tag root;

		try {
			root = parseFile(path);
			foreach(Tag t0; root.tags) {
				switch (t0.name) {
				case "configurationFile": 	//get configfile metadata
					appName = t0.values[0].get!string();
					appVers = t0.values[1].get!string();
					break;
				case "audio": 		//get values for the audio subsystem
					sfxVol = t0.getTagValue!int("soundVol", 100);
					musicVol = t0.getTagValue!int("musicVol", 100);
					break;
				case "video": 	//get values for the video subsystem
					foreach(Tag t1; t0.tags ){
						switch(t1.name){
							case "driver": gfxdriver = t1.getValue!string("software"); break;
							case "scaling": scalingQuality = t1.getValue!string("nearest"); break;
							case "screenMode": screenMode = t1.getValue!string("windowed"); break;
							case "resolution": resolution = t1.getValue!string("0"); break;
							case "threads": threads = t1.getValue!int(-1); break;
							default: break;
						}
					}
					break;
				case "input":
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
												device.keyBindingList ~= kb;
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
												device.keyBindingList ~= kb;
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
					break;
				case "local":
					localCountry = t0.values[0].get!string();
					localLang = t0.values[1].get!string();
					break;
				default:
					//collect all ancillary tags into an array
					ancillaryTags ~= t0;
					break;
				}
			}
		}
		catch(ParseException e){
			writeln(e.msg);
		}



	}
	/**
	 * Stores configuration profile on disk.
	 */
	public void store(){
		try {
			Tag root = new Tag(null, null);		//, [Value(appName), Value(appVers)]

			new Tag(root, null, "configurationFile", [Value(appName), Value(appVers)]);

			Tag t0 = new Tag(root, null, "audio");
			new Tag(t0, null, "soundVol", [Value(sfxVol)]);
			new Tag(t0, null, "musicVolt", [Value(musicVol)]);

			Tag t1 = new Tag(root, null, "video");
			new Tag(t1, null, "driver", [Value(gfxdriver)]);
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
			if (!localCountry.length) localCountry = "NULL";
			if (!localLang.length) localLang = "NULL";
			new Tag(root, null, "local", [Value(localCountry), Value(localLang)]);
			//Tag t3 = new Tag(root, null, "etc");
			foreach(at; ancillaryTags){
				at.remove();
				root.add(at);
			}
			string data = root.toSDLDocument();
			std.file.write(path, data);
		} catch (Exception e) {
			debug writeln(e);
		}
	}
	/**
	 * Converts a key modifier string to machine-readable value
	 */
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
	/**
	 * Converts a key modifier value to human-readable string.
	 */
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
	/**
	 * Converts JoyModifier to human-readable string.
	 */
	public string joymodToString(const ushort s) @safe pure nothrow const {
		switch(s) {
			case JoyModifier.Axis: return "Axis";
			case JoyModifier.DPad: return "DPad";
			default: return "Buttons";
		}
	}
	/**
	 * Loads inputbindings into a handler.
	 */
	public void loadBindings(InputHandler ih) @safe nothrow {
		foreach (iD; inputDevices) {
			foreach (KeyBinding key; iD.keyBindingList) {
				ih.addBinding(key.bc, key.toInputBinding);
			}
		}
	}
	/* public void useVideoMode(int mode, OutputScreen window){

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
	} */
	public size_t getNumOfVideoModes(){
		return videoModes.length;
	}
	public string videoModeToString(size_t n){
		return to!string(videoModes[n].w) ~ "x" ~ to!string(videoModes[n].h) ~ "@" ~ to!string(videoModes[n].refresh_rate) ~ 
				"Hz";
	}
	/**
	 * Sets the the path where configuration files and etc. will be stored.
	 * If ../_debug/ folder exists, it'll be used instead for emulation purposes.
	 * DEPRECATED, USE PATH SYSTEM INSTEAD!
	 */
	public static void setVaultPath(const char* developer, const char* application){
		if (exists(getPathToAsset("%PATH%/_debug/"))) {
			vaultPath = getPathToAsset("%PATH%/_debug/") ~ "/" ~ fromStringz(developer).idup ~ "_" ~ 
					fromStringz(application).idup ~ "/";
			if (!std.file.exists(vaultPath))
				std.file.mkdir(vaultPath);
		} else {
			vaultPath = to!string(SDL_GetPrefPath(developer, application));
		}
	}
	public static string getVaultPath() {
		return vaultPath;
	}
	/**
	 * Restores the default configuration.
	 * Filename can be set if not the default name was used for the file.
	 */
	public static void restoreDefaults(string filename = "config.sdl") {
		std.file.remove(vaultPath ~ filename);
	}
}
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
