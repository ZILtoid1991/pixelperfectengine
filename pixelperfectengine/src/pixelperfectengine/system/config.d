/*
 * Copyright (C) 2015-2017, by Laszlo Szeremi under the Boost license.
 *
 * Pixel Perfect Engine, config module
 */

module pixelperfectengine.system.config;

//import std.xml;
import std.file;
import std.string;
import std.conv;
//import std.csv;

import pixelperfectengine.system.input.handler;
import pixelperfectengine.system.file;
import pixelperfectengine.system.exc;
import pixelperfectengine.system.etc;
import pixelperfectengine.system.dictionary;

import iota.controls.keyboard : KeyboardModifiers;
//import bindbc.sdl;

//import sdlang;
import newsdlang;
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
	public float enableForceFeedback;	///Toggles force feedback if device is capable of it
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
	public string	shaderVers;		///Scaling quality (what scaler it uses)
	public string	gfxdriver;		///Graphics driver
	public string	localCountry;	///Localization configuration (country)
	public string	localLang;		///Localization configuration (language)
	public int		graphicsScaling;///Integer scaling of graphics
	public int[2]	rasterSize;		///Raster size
	//public string[string] videoSettings;
	//public KeyBinding[] keyBindingList;
	public InputDeviceData[] inputDevices;	///Stores all input devices and keybindings
	private string	path;			///Path where the 
	///Stores ancillary tags to be serialized into the config file
	public DLTag[] ancillaryTags;
	private static string vaultPath;
	//private SDL_DisplayMode[] videoModes;
	//public AuxillaryElements auxillaryElements[];
	public string appName;					///Name of the application. Can be used to check e.g. version safety.
	public string appVers;					///Version of the application. Can be used to check e.g. version safety.
	/// Initializes a basic configuration profile. If [vaultPath] doesn't have any configfiles, restores it from defaults.
	public this() {
		path = resolvePath(`%STORE%/config.sdl`);
		if(!exists(path))
			std.file.copy(resolvePath("%PATH%/system/defaultConfig.sdl"),path);
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
				["none"	: 0, "Shift": KeyboardModifiers.Shift, "Ctrl": KeyboardModifiers.Ctrl, "Alt": KeyboardModifiers.Alt, 
						"GUI": KeyboardModifiers.Meta, "NumLock": KeyboardModifiers.NumLock, "CapsLock": KeyboardModifiers.CapsLock, 
						"Aux": KeyboardModifiers.Aux, "ScrollLock": KeyboardModifiers.ScrollLock, "All": ubyte.max];
		joymodifierStrings = [0x00: "button",0x04: "dpad",0x08: "axis"];
		devicetypeStrings = [Devicetype.Joystick: "joystick", Devicetype.Keyboard: "keyboard", Devicetype.Mouse: "mouse",
				Devicetype.Touchscreen: "touchscreen" ];
		//keyNameDict = new Dictionary("../system/keycodeNamings.sdl");
		keyNameDict = new Dictionary(readDOM(getPathToAsset("%PATH%/system/scancodes.sdl")));
		Tag xinput = readDOM(getPathToAsset("%PATH%/system/xinputCodes.sdl"));
		joyButtonNameDict = new Dictionary(xinput.expectTag("button"));
		joyAxisNameDict = new Dictionary(xinput.expectTag("axis"));
	}
	///Restores configuration profile from a file.
	public void restore() {
		DLDocument root;
		try {
			root = readDOM(readText(path));
			foreach(DLTag t0; root.tags) {
				switch (t0.name) {
				case "configurationFile": 	//get configfile metadata
					appName = t0.values[0].get!string();
					appVers = t0.values[1].get!string();
					break;
				case "audio": 		//get values for the audio subsystem
					sfxVol = t0.searchTagX(["soundVol"]).values[0].get!int;
					musicVol = t0.searchTagX(["musicVol"]).values[0].get!int;
					DLValue driver = t0.searchTagX(["driver"]).values[0];
					if (driver.type == DLValueType.String) audioDriver = driver.get!string;
					DLValue device = t0.searchTagX(["device"]).values[0];
					if (device.type == DLValueType.String) audioDevice = driver.get!string;
					audioFrequency = t0.searchTagX(["frequency"]).values[0].get!int;
					audioBufferLen = t0.searchTagX(["bufferLen"]).values[0].get!int;
					audioFrameLen = t0.searchTagX(["frameLen"]).values[0].get!int;
					break;
				case "video": 	//get values for the video subsystem
					foreach(DLTag t1; t0.tags ){
						DLValue val = t1.values[0];
						switch(t1.name){
							case "driver":
								if (val.type == DLValueType.String) gfxdriver = val.get!string;
								else shaderVers = null;
								break;
							case "shaderVers":
								if (val.type == DLValueType.String) shaderVers = val.get!string;
								else shaderVers = null;
								break;
							case "screenMode":
								if (val.type == DLValueType.String) screenMode = val.get!string;
								else screenMode = "windowed";
								break;
							case "resolution":
								if (val.type == DLValueType.String) resolution = val.get!string;
								else resolution = null;
								break;
							case "threads": threads = t1.getValue!int(-1); break;
							default: break;
						}
					}
					break;
				case "input":
					foreach(DLTag t1; t0.tags) {
						switch(t1.name) {
							case "device":
								InputDeviceData device;
								device.name = t1.searchAttribute!string("name");
								device.deviceNumber = t1.searchAttribute!int("devNum", 0);
								switch(t1.searchAttribute!string("type")){
									case "keyboard":
										device.type = Devicetype.Keyboard;
										foreach(DLTag t2; t1.tags){
											if(t2.name is null){
												KeyBinding kb;
												kb.name = t2.value[0].get!string;
												kb.bc.deviceNum = cast(ubyte)device.deviceNumber;
												kb.bc.deviceTypeID = Devicetype.Keyboard;
												kb.bc.modifierFlags = stringToKeymod(t2.searchAttribute!string("keyMod", "None"));
												kb.bc.keymodIgnore = stringToKeymod(t2.searchAttribute!string("keyModIgnore", "All"));
												kb.bc.buttonNum =
														cast(ushort)(t2.searchAttribute!int("code", keyNameDict.decode(t2.searchAttribute!string("name", null))));
												device.keyBindingList ~= kb;
											}
										}
										break;
									case "joystick":
										device.type = Devicetype.Joystick;
										foreach(DLTag t2; t1.tags) {		//parse each individual binding
											if(t2.name is null) {
												KeyBinding kb;
												kb.name = t2.value[0].get!string;
												kb.bc.deviceNum = cast(ubyte)device.deviceNumber;
												kb.bc.deviceTypeID = Devicetype.Joystick;
												switch(t2.searchAttribute!string("keyMod", null)){
													case "dpad":
														kb.bc.modifierFlags = JoyModifier.DPad;
														goto default;
													case "axis":
														kb.bc.modifierFlags = JoyModifier.Axis;
														kb.deadzones[0] = t2.searchAttribute!float("deadZone0", float.nan);
														kb.deadzones[1] = t2.searchAttribute!float("deadZone1", float.nan);
														kb.axisAsButton = t2.searchAttribute!bool("axisAsButton", false);
														goto default;
													default:
														kb.bc.buttonNum =
																cast(ushort)t2.searchAttribute!int("code",
																joyButtonNameDict.decode(t2.searchAttribute!string("name", null)));
														break;
												}
												device.keyBindingList ~= kb;
											} else if(t2.name == "enableForceFeedback") {
												if (t2.values[0].type == DLValueType.Boolean)
													device.enableForceFeedback = t2.values[0].get!bool ? 1.0 : 0.0;
												else device.enableForceFeedback = t2.values[0].get!float;
											}
										}
										break;
									case "mouse":
										device.type = Devicetype.Mouse;
										foreach(Tag t2; t1.tags){
											if(t2.name is null){
												//const ushort scanCode = cast(ushort)t2.getAttribute!int("code");
												KeyBinding kb;
												kb.name = t2.values[0].get!string();
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
			write(path, root.writeDOM());
		} catch(DLException e){
			debug writeln(e.msg);
		}
	}
	/**
	 * Stores configuration profile on disk.
	 */
	public void store(){
		try {
			DLDocument root = new DLDocument([
				new DLComment("Value #0: Application name\nValue #1: Application version"),
				new DLTag("configurationFile", null, [new DLValue(appName), new DLValue(appVers)]),
				new DLComment("Audio settings"),
				new DLTag("audio", null, [
					new DLTag("soundVol", null, [new DLValue(sfxVol),
							new DLComment("Sound volume (0-100)", DLCommentType.Slash, DLCommentStyle.LineEnd)]),
					new DLTag("musicVol", null, [new DLValue(musicVol),
							new DLComment("Music volume (0-100)", DLCommentType.Slash, DLCommentStyle.LineEnd)]),
					new DLTag("driver", null, [new DLValue(audioDriver),
							new DLComment("Name of the audio driver, null for auto", DLCommentType.Slash, DLCommentStyle.LineEnd)]),
					new DLTag("device", null, [new DLValue(audioDevice),
							new DLComment("Name of the audio device, null for auto", DLCommentType.Slash, DLCommentStyle.LineEnd)]),
					new DLTag("frequency", null, [new DLValue(audioDriver), new DLComment(
							"Playback frequency (should be either 44100 or 48000)", DLCommentType.Slash, DLCommentStyle.LineEnd)]),
					new DLTag("bufferLen", null, [new DLValue(audioDriver),
							new DLComment("Length of the buffer (must be power of two)", DLCommentType.Slash, DLCommentStyle.LineEnd)]),
					new DLTag("frameLen", null, [new DLValue(audioDriver), new DLComment("Length of an audio frame (must be less or " ~
							"equal than buffer, and power of two)", DLCommentType.Slash, DLCommentStyle.LineEnd)]),
				]),
				new DLComment("Graphics settings"),
				new DLTag("video", null, [
					new DLTag("driver", null, [new DLValue(gfxdriver), new DLComment("Name of API for rendering, currently ignored, " ~
							"later can specify openGL, vulkan, directX, and metal", DLCommentType.Slash, DLCommentStyle.LineEnd)]),
					new DLTag("shaderVers", null, [new DLValue(shaderVers ?
							DLVar(shaderVers, DLValueType.String, DLStringType.Quote) : DLVar.createNull),
							new DLComment(`Selects shader version, default is "330" or "300es"`, DLCommentType.Slash,
							DLCommentStyle.LineEnd)]),
					new DLTag("screenMode", null, [new DLValue(screenMode),
							new DLComment("Default screen mode", DLCommentType.Slash, DLCommentStyle.LineEnd)]),
					new DLTag("resolution", null, [new DLValue(resolution),
							new DLComment(`Set to "null" if not applicable, otherwise format is "[width]x[height]@[frequency]"`,
							DLCommentType.Slash, DLCommentStyle.LineEnd)]),
					new DLTag("graphicsScaling", null, [new DLValue(graphicsScaling),
							new DLComment("Initial graphics scaling if no override used", DLCommentType.Slash, DLCommentStyle.LineEnd)]),
					new DLTag("rasterSize", null, [new DLValue(rasterSize[0]), new DLValue(rasterSize[1]),
							new DLComment("Initial raster size if no override used", DLCommentType.Slash, DLCommentStyle.LineEnd)]),
				]),
				new DLComment("Input settings")
			]);
			DLTag inputSettings = new DLTag("input", null, [
				new DLComment("device:\n" ~
				"type: Possible values: \"keyboard\", \"joystick\", \"mouse\", \"touchscreen\"(unimplemented)\n"~"
name: Name of the device, might be absent.
devNum: Device ID.")
			]);
			foreach (InputDeviceData idd ; inputDevices) {
				DLElement[] name;
				if (idd.name) name ~= new DLAttribute("name", null, DLVar(idd.name, DLValueType.String, DLStringType.Quote));
				DLTag currInputDevice = new DLTag("device", null, name ~ [
					new DLAttribute("type", null, DLVar(devicetypeStrings[idd.type], DLValueType.String, DLStringType.Quote)),
					new DLAttribute("devnum", null, DLVar(idd.deviceNumber, DLValueType.Integer, DLNumberStyle.Decimal)),
					new DLComment("Anonymous tags here are treated as keybindings.\n" ~
					"Value #0: ID, usually a readable one.\n" ~
					"name: The name of the key from the appropriate naming file.\n" ~
					"code: If namings are unavailable, then this will be used, has a higher\n" ~
					"priority than keyName\n" ~
					"keyMod: In case of keyboards, it's the modifier keys used for various key\n" ~
					"combinations. In case of joysticks, it determines whether it's a button,\n" ~
					"DPad, or an axis.\n" ~
					"keyModIgnore: Determines what modifier keys should it ignore.\n" ~
					"deadZone0: Axis deadzone prelimiter 1.\n" ~
					"deadZone1: Axis deadzone prelimiter 2.\n" ~
					"axisAsButton: Makes the axis to act like a button if within deadzone.")
				]);
				final switch (idd.type) with (Devicetype) {
					case Keyboard:
						foreach (KeyBinding binding ; idd.keyBindingList) {
							DLTag currKeyBind = new DLTag(null, null, [new DLValue(binding.name),
									new DLAttribute("name", null, DLVar(keyNameDict.encode(binding.bc.buttonNum)))]);
							if (binding.bc.modifierFlags != 0) currKeyBind.add(new DLAttribute("keyMod", null, DLVar(
									keymodToString(binding.bc.modifierFlags), DLValueType.String, DLStringType.Quote)));
							if (binding.bc.keymodIgnore != 0) currKeyBind.add(new DLAttribute("keyModIgnore", null, DLVar(
									keymodToString(binding.bc.keymodIgnore), DLValueType.String, DLStringType.Quote)));
							currInputDevice.add(currKeyBind);
						}
						break;
					case Joystick:
						foreach (binding ; idd.keyBindingList) {
							DLTag currKeyBind = new DLTag(null, null, [new DLValue(binding.name)]);
							switch (binding.bc.modifierFlags) {
								case JoyModifier.Axis:
									currKeyBind.add(new DLAttribute("name", null, DLVar(joyAxisNameDict.encode(binding.bc.buttonNum),
											DLValueType.String, DLStringType.Quote)));
									currKeyBind.add(new DLAttribute("keyMod", null, DLVar(joymodifierStrings[binding.bc.modifierFlags],
											DLValueType.String, DLStringType.Quote)));
									currKeyBind.add(new DLAttribute("deadZone0", null, DLVar(binding.deadzones[0],
											DLValueType.Float, DLNumberStyle.Decimal)));
									currKeyBind.add(new DLAttribute("deadZone1", null, DLVar(binding.deadzones[1],
											DLValueType.Float, DLNumberStyle.Decimal)));
									break;
								case JoyModifier.DPad:
									currKeyBind.add(new DLAttribute("code", null, DLVar(binding.bc.buttonNum, DLValueType.Integer,
											DLNumberStyle.Decimal)));
									currKeyBind.add(new DLAttribute("keyMod", null, DLVar(joymodifierStrings[binding.bc.modifierFlags],
											DLValueType.String, DLStringType.Quote)));
									break;
								default:
									currKeyBind.add(new DLAttribute("name", null, DLVar(joyButtonNameDict.encode(binding.bc.buttonNum),
											DLValueType.String, DLStringType.Quote)));
									break;
							}
							currInputDevice.add(currKeyBind);
						}
						currInputDevice.add(new Tag("enableForceFeedback", null, [new DLValue(idd.enableForceFeedback)]));
						break;
					case Mouse:
						foreach (binding ; idd.keyBindingList) {
							currInputDevice.add(new DLTag(null, null, [new DLValue(binding.name), new DLAttribute("code", null,
									DLVar(binding.bc.buttonNum, DLValueType.Integer, DLNumberStyle.Decimal))]));
						}
						break;
					case Touchscreen:
						break;
					case Pen:
						break;
				}
				root.add(currInputDevice);
			}

		} catch (Exception e) {
			debug writeln(e);
		}
	}
	/**
	 * Converts a key modifier string to machine-readable value
	 */
	public ubyte stringToKeymod(string s) @safe const {
		import std.algorithm.iteration : splitter;
		if(s == "None")	return 0x00;
		if(s == "All") return 0xFF;
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
		if(keymod == 0x00) return "None";
		if(keymod == 0xFF) return "All";
		string result;
		if(keymod & KeyboardModifiers.Shift) result ~= "Shift;";
		if(keymod & KeyboardModifiers.Ctrl) result ~= "Ctrl;";
		if(keymod & KeyboardModifiers.Alt) result ~= "Alt;";
		if(keymod & KeyboardModifiers.Meta) result ~= "GUI;";
		if(keymod & KeyboardModifiers.NumLock) result ~= "NumLock";
		if(keymod & KeyboardModifiers.CapsLock) result ~= "CapsLock;";
		if(keymod & KeyboardModifiers.Aux) result ~= "Aux;";
		if(keymod & KeyboardModifiers.ScrollLock) result ~= "ScrollLock;";
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
	/**
	 * Restores the default configuration.
	 * Filename can be set if not the default name was used for the file.
	 */
	public static void restoreDefaults(string filename = "config.sdl") {
		std.file.remove(pathSymbols["STORE"] ~ filename);
	}
}
