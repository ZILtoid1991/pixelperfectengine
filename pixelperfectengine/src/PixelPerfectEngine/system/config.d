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

import PixelPerfectEngine.system.inputHandler;
import PixelPerfectEngine.system.exc;
import PixelPerfectEngine.system.etc;
import PixelPerfectEngine.system.dictionary;
import PixelPerfectEngine.graphics.outputScreen;

import bindbc.sdl;

import sdlang;

public class ConfigurationProfile{
	public static const ushort[string] keymodifierStrings;
	public static const string[ushort] joymodifierStrings;
	public static const string[Devicetype] devicetypeStrings;
	private static Dictionary keyNameDict, joyButtonNameDict, joyAxisNameDict;
	public int sfxVol, musicVol;
	public int threads;
	public string screenMode, resolution, scalingQuality, driver;
	//public string[string] videoSettings;
	public KeyBinding[] keyBindingList;
	public InputDeviceData[] inputDevices;
	private string path;
	public AuxillaryElements[] auxillaryParameters;
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
		joymodifierStrings = [0x0000: "buttons",0x0004: "dpad",0x0008: "axis"];
		devicetypeStrings = [Devicetype.JOYSTICK: "joystick", Devicetype.KEYBOARD: "keyboard", Devicetype.MOUSE: "mouse",
				Devicetype.TOUCHSCREEN: "touchscreen" ];
		keyNameDict = new Dictionary("../system/keycodeNamings.sdl");
		joyButtonNameDict = new Dictionary("../system/joyButtonNamings.sdl");
		joyAxisNameDict = new Dictionary("../system/joyAxisNamings.sdl");
	}
	///Restores configuration profile
	public void restore(){

		//string s = cast(string)std.file.read(configFile);

		Tag root;

		try{
			root = parseFile(path);
			foreach(Tag t0; root.tags){
				if(t0.name == "audio"){		//get values for the audio subsystem
					sfxVol = t0.getTagValue!int("soundVol", 100);
					musicVol = t0.getTagValue!int("musicVol", 100);
				}else if(t0.name == "video"){	//get values for the video subsystem
					foreach(Tag t1; t0.tags){
						switch(t1.name){
							case "driver": driver = t1.getValue!string("software"); break;
							case "scaling": scalingQuality = t1.getValue!string("nearest"); break;
							case "screenMode": driver = t1.getValue!string("windowed"); break;
							case "resolution": driver = t1.getValue!string("0"); break;
							case "threads": threads = t1.getValue!int(-1); break;
							default: break;
						}
					}
				}else if(t0.name == "input"){
					foreach(Tag t1; t0.tags){
						switch(t1.name){
							case "device":
								InputDeviceData device;
								string name = t1.getValue!string("");
								int devicenumber = t1.getAttribute!int("devNum");
								switch(t1.expectAttribute!string("type")){
									case "keyboard":
										device = InputDeviceData(devicenumber, Devicetype.KEYBOARD, name);
										foreach(Tag t2; t1.tags){
											if(t2.name is null){
												uint scanCode = t2.getAttribute!int("keyCode", keyNameDict.decode(t2.getAttribute!string("keyName")));
												KeyBinding keyBinding = KeyBinding(stringToKeymod(t2.getAttribute!string("keyMod","NONE")), scanCode, 
														devicenumber, t2.expectValue!string(), Devicetype.KEYBOARD, stringToKeymod(t2.getAttribute!string
														("keyModIgnore","ALL")));
												keyBindingList ~= keyBinding;
											}
										}
										break;
									case "joystick":
										device = InputDeviceData(devicenumber, Devicetype.JOYSTICK, name);
										foreach(Tag t2; t1.tags){
											if(t2.name is null){
												switch(t2.getAttribute!string("keymodifier")){
													case "buttons":
														uint scanCode = t2.getAttribute!int("keyCode", joyButtonNameDict.decode(t2.getAttribute!string("keyName")));
														keyBindingList ~= KeyBinding(0, scanCode, devicenumber, t2.expectValue!string(), Devicetype.JOYSTICK);
														break;
													case "dpad":
														uint scanCode = t2.getAttribute!int("keyCode");
														keyBindingList ~= KeyBinding(4, scanCode, devicenumber, t2.expectValue!string(), Devicetype.JOYSTICK);
														break;
													case "axis":
														uint scanCode = t2.getAttribute!int("keyCode", joyAxisNameDict.decode(t2.getAttribute!string("keyName")));
														keyBindingList ~= KeyBinding(8, scanCode, devicenumber, t2.expectValue!string(), Devicetype.JOYSTICK);
														break;
													default:
														uint scanCode = t2.getAttribute!int("keyCode");
														keyBindingList ~= KeyBinding(0, scanCode, devicenumber, t2.expectValue!string(), Devicetype.JOYSTICK);
														break;
												}
											}else if(t2.name == "enableForceFeedback"){
												device.enableForceFeedback = t2.getValue!bool(true);
											}else if(t2.name == "axisDeadzone"){
												device.axisDeadZonePlus[t2.getAttribute!int("axisNumber", joyAxisNameDict.decode
														(t2.getAttribute!string("axisName")))] = t2.expectAttribute!int("plus");
												device.axisDeadZoneMinus[t2.getAttribute!int("axisNumber", joyAxisNameDict.decode
														(t2.getAttribute!string("axisName")))] = t2.expectAttribute!int("minus");
											}
										}
										break;
									case "mouse":
										device = InputDeviceData(devicenumber, Devicetype.MOUSE, name);
										foreach(Tag t2; t1.tags){
											if(t2.name is null){
												const uint scanCode = t2.getAttribute!int("keyCode");
												keyBindingList ~= KeyBinding(0, scanCode, devicenumber, t2.expectValue!string(), Devicetype.MOUSE);
											}
										}
										break;
									default:
										device = InputDeviceData(devicenumber, Devicetype.KEYBOARD, name);
										break;
								}
								inputDevices ~= device;
								break;
							default: break;
						}
					}
				}else if(t0.name == "etc"){
					foreach(Tag t1; t0.tags){
						auxillaryParameters ~= AuxillaryElements(t1.name(), t1.getValue!string());
					}
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
		Tag t0_0 = new Tag(t0, null, "soundVol", [Value(sfxVol)]);
		Tag t0_1 = new Tag(t0, null, "musicVolt", [Value(musicVol)]);

		Tag t1 = new Tag(root, null, "video");
		Tag t1_0 = new Tag(t1, null, "driver", [Value(driver)]);
		Tag t1_1 = new Tag(t1, null, "scaling", [Value(scalingQuality)]);
		Tag t1_2 = new Tag(t1, null, "screenMode", [Value(screenMode)]);
		Tag t1_3 = new Tag(t1, null, "resolution", [Value(resolution)]);
		Tag t1_4 = new Tag(t1, null, "threads", [Value(threads)]);

		Tag t2 = new Tag(root, null, "input");
		foreach(InputDeviceData idd; inputDevices){
			string devType = devicetypeStrings[idd.type];
			Tag t2_0 = new Tag(t2, null, "device", null, [new Attribute(null, "name",Value(idd.name)), new Attribute(null, 
					"type", Value(devType)), new Attribute(null, "devNum", Value(idd.deviceNumber))]);
			if(idd.type == Devicetype.KEYBOARD){
				foreach(KeyBinding k; keyBindingList){
					if(k.devicetype == idd.type && k.devicenumber == idd.deviceNumber){
						Attribute key;
						string s = keyNameDict.encode(k.scancode);
						if(s is null){
							key = new Attribute(null, "keyCode", Value(to!int(k.scancode)));
						}else{
							key = new Attribute(null, "keyName", Value(s));
						}
						new Tag(t2_0, null, null, [Value(k.ID)], [key, new Attribute(null, "keyMod", Value(keymodToString(k.keymod))), 
								new Attribute(null, "keyModIgnore", Value(keymodToString(k.keymodIgnore)))]);
					}
				}
			}else if(idd.type == Devicetype.JOYSTICK){
				foreach(KeyBinding k; keyBindingList){
					if(k.devicetype == idd.type && k.devicenumber == idd.deviceNumber){
						new Tag(t2_0, null, null, [Value(k.ID)], [new Attribute(null, "keyCode", Value(to!int(k.scancode))), new 
								Attribute(null, "keyMod", Value(joymodifierStrings[k.keymod]))]);

					}
				}
				new Tag(t2_0, null, "enableForceFeedback", [Value(idd.enableForceFeedback)]);
				foreach(int i; idd.axisDeadZonePlus.byKey){
					new Tag(t2_0, null, "axisDeadzone", null, [new Attribute(null, "axisNumber", Value(i) ), new Attribute(null, 
							"plus", Value(idd.axisDeadZonePlus[i]) ), new Attribute(null, "minus", Value(idd.axisDeadZoneMinus[i]) )]);
				}
			}else if(idd.type == Devicetype.MOUSE){
				foreach(KeyBinding k; keyBindingList){
					if(k.devicetype == idd.type && k.devicenumber == idd.deviceNumber){
						new Tag(t2_0, null, null, [Value(k.ID)], [new Attribute(null, "keyCode", Value(to!int(k.scancode)))]);
					}
				}
			}
		}
		Tag t3 = new Tag(root, null, "etc");
		foreach(AuxillaryElements ae; auxillaryParameters){
			new Tag(t3, null, ae.name, [Value(ae.value)]);
		}
		string data = root.toSDLDocument();
		std.file.write(path, data);
	}

	public ushort stringToKeymod(string s){
		import std.algorithm.iteration : splitter;
		if(s == "None")	return KeyModifier.None;
		if(s == "All")		return KeyModifier.All;
		auto values = s.splitter(';');
		ushort result;
		foreach(t ; values){
			result |= keymodifierStrings.get(t,0);
		}
		return result;
	}

	public string keymodToString(ushort keymod){
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

	public string joymodToString(ushort s){
		switch(s){
			case JoyModifier.AXIS: return "AXIS";
			case JoyModifier.DPAD: return "DPAD";
			default: return "BUTTONS";
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
		debug {
			vaultPath = "../_debug/";
		} else {

			vaultPath = to!string(SDL_GetPrefPath(developer, application));
		}
	}
	public static string getVaultPath(){
		return vaultPath;
	}

}
/**
 * Deprecated, not up to current standards, will be upgraded to take advantage of the SDLang format.
 */
public struct AuxillaryElements{
	public string value, name;
	public this(string name, string value){
		this.name = name;
		this.value = value;
	}
}

/**
 * Stores basic InputDevice info alongside with some additional settings
 */
public struct InputDeviceData{
	public int deviceNumber;
	public Devicetype type;
	public string name;
	public bool enableForceFeedback;
	public int[int] axisDeadZonePlus, axisDeadZoneMinus;
	public this(int deviceNumber, Devicetype type, string name){
		this.deviceNumber = deviceNumber;
		this.type = type;
		this.name = name;
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
