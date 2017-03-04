/*
 * Copyright (C) 2015-2017, by Laszlo Szeremi under the Boost license.
 *
 * Pixel Perfect Engine, config module
 */

module PixelPerfectEngine.system.config;

import std.xml;
import std.file;
import std.stdio;
import std.string;
import std.conv;
import std.csv;

import PixelPerfectEngine.system.inputHandler;
import PixelPerfectEngine.system.exc;
import PixelPerfectEngine.system.etc;
import PixelPerfectEngine.graphics.outputScreen;

import derelict.sdl2.sdl;

public class ConfigurationProfile{
	public static const ushort[string] keymodifierStrings; 
	
	public static const ushort[string] joymodifierStrings; //["BUTTONS": 0x0000, "DPAD": 0x0004, "AXIS": 0x0008];
	public int sfxVol, musicVol;
	//public string screenMode, resolution, scalingQuality, driver;
	public string[string] videoSettings;
	public KeyBinding[] keyBindingList, inputDevList;
	private string path;
	public AuxillaryElements[] auxillaryParameters;
	private static string vaultPath;
	private SDL_DisplayMode[] videoModes;
	//public AuxillaryElements auxillaryElements[];

	public this(string configFile){
		path = configFile;
		//restore(lastFile);
	}

	public this(){
		path = "config.cfg";
	}

	static this(){
		keymodifierStrings = 
				["NONE"	: 0x0000, "LSHIFT": 0x0001, "RSHIFT": 0x0002, "LCTRL": 0x0040, "RCTRL": 0x0080, "LALT": 0x0100, "RALT": 0x0200, "LGUI": 0x0400,	"RGUI": 0x0800,	"NUM": 0x1000, "CAPS": 0x2000,
				"MODE": 0x4000,	"RESERVED": 0x8000,	"ANY": 0xFFFF];
		joymodifierStrings = ["BUTTONS": 0x0000, "DPAD": 0x0004, "AXIS": 0x0008];
	}

	public void restore(string configFile){
		path = configFile;
		string s = cast(string)std.file.read(configFile);
		
		check(s);
		
		auto doc = new Document(s);

		foreach(Element e1; doc.elements){

			if(e1.tag.name == "Audio"){
				foreach(Element e2; e1.elements){
					if(e2.tag.name == "sfxVol")
						sfxVol = to!int(e2.text());
					else if(e2.tag.name == "musicvol")
						musicVol = to!int(e2.text());
				}
			}
			else if(e1.tag.name == "Video"){
				foreach(Element e2; e1.elements){
					/*if(e2.tag.name == "screenMode")
						screenMode = e2.text();
					else if(e2.tag.name == "resolution")
						resolution = e2.text();
					else if(e2.tag.name == "scalingQuality")
						scalingQuality = e2.text();
					else if(e2.tag.name == "driver")
						driver = e2.text();*/
					videoSettings[e2.tag.name] = e2.text();
				}
			}
			else if(e1.tag.name == "Input"){
				int dn = to!uint(e1.tag.attr["devNum"]);
				int dt;
				switch(e1.tag.attr["devType"]){
					case "Joystick":
						dt = Devicetype.JOYSTICK;
						foreach(Element e2; e1.elements){
							keyBindingList ~= KeyBinding(joymodifierStrings[e2.tag.attr["keyMod"]], to!uint(e2.tag.attr["keyCode"]), dn, e2.tag.attr["ID"], dt);
						}
						break;
					case "Mouse":
						dt = Devicetype.MOUSE;
						foreach(Element e2; e1.elements){
							keyBindingList ~= KeyBinding(0, to!uint(e2.tag.attr["keyCode"]), dn, e2.tag.attr["ID"], dt);
						}
						break;
					case "Touchscreen":
						break;
					default:
						dt = Devicetype.KEYBOARD;
						foreach(Element e2; e1.elements){
							keyBindingList ~= KeyBinding(stringToKeymod(e2.tag.attr["keyMod"]), to!uint(e2.tag.attr["keyCode"]), dn, e2.tag.attr["ID"], dt, stringToKeymod(e2.tag.attr["keyModIgnore"]));
						}
						break;
				}
				
				inputDevList ~= KeyBinding(0, 0, dn, "", dt);
					
						

			}
			else if(e1.tag.name == "Aux"){
				foreach(Element e2; e1.elements){
					auxillaryParameters ~= AuxillaryElements(e2.tag.name, e2.text());
				}
			}
		}
		
	}
	public void store(string configFile){

		auto doc = new Document(new Tag("Configuration"));

		auto e1 = new Element("Audio");
		e1 ~= new Element("sfxVol", to!string(sfxVol));
		e1 ~= new Element("musicVol", to!string(musicVol));
		doc ~= e1;

		auto e2 = new Element("Video");
		/*e2 ~= new Element("screenMode", screenMode);
		e2 ~= new Element("resolution", resolution);
		e2 ~= new Element("scalingQuality", scalingQuality);
		e2 ~= new Element("driver", driver);*/
		foreach(s; videoSettings.byKey()){
			e2 ~= new Element(s, videoSettings[s]);
		}
		doc ~= e2;


		foreach(KeyBinding id; inputDevList){
			auto e3 = new Element("Input");
			e3.tag.attr["devType"] = to!string(id.devicetype);
			e3.tag.attr["devNum"] = to!string(id.devicenumber);
			if(id.devicetype == Devicetype.JOYSTICK){
				for(int k; k < keyBindingList.length; k++){
					if(keyBindingList[k].devicetype == id.devicetype && keyBindingList[k].devicenumber == id.devicenumber){
						auto e4 = new Element("KeyBinding");
						e4.tag.attr["keyMod"] = joymodToString(keyBindingList[k].keymod);
						e4.tag.attr["keyCode"] = to!string(keyBindingList[k].keymod);
						e4.tag.attr["ID"] = keyBindingList[k].ID;
						//e4.tag.attr["keyModIgnore"] = keymodToString(keyBindingList[k].keymodIgnore);
						e3 ~= e4;
					}
				}
			}else{
				for(int k; k < keyBindingList.length; k++){
					if(keyBindingList[k].devicetype == id.devicetype && keyBindingList[k].devicenumber == id.devicenumber){
						auto e4 = new Element("KeyBinding");
						e4.tag.attr["keyMod"] = keymodToString(keyBindingList[k].keymod);
						e4.tag.attr["keyCode"] = to!string(keyBindingList[k].keymod);
						e4.tag.attr["ID"] = keyBindingList[k].ID;
						e4.tag.attr["keyModIgnore"] = keymodToString(keyBindingList[k].keymodIgnore);
						e3 ~= e4;
					}
				}
			}
			doc ~= e3;
		}

		auto e4 = new Element("Aux");
		foreach(AuxillaryElements aux; auxillaryParameters){
			e4 ~= new Element(aux.name, aux.value);
		}
		doc ~= e4;
		
		std.file.write(configFile, doc.toString());
	}

	public ushort stringToKeymod(string s){
		if(s == "NONE;")	return KeyModifier.NONE;
		if(s == "ANY;")		return KeyModifier.ANY;
		string[] values = csvParser(s, ';');
		ushort result;
		/*foreach(t ; values){
			result += keymodifierStrings[t];
		}*/
		return result;
	}

	public string keymodToString(ushort keymod){
		if(keymod == KeyModifier.NONE)
			return "NONE;";
		if(keymod == KeyModifier.ANY)
			return "ANY;";
		string result;
		if(keymod && KeyModifier.LSHIFT == KeyModifier.LSHIFT){
			result ~= "LSHIFT;";
		}
		if(keymod && KeyModifier.RSHIFT == KeyModifier.RSHIFT){
			result ~= "RSHIFT;";
		}
		if(keymod && KeyModifier.LCTRL == KeyModifier.LCTRL){
			result ~= "LCTRL;";
		}
		if(keymod && KeyModifier.RCTRL == KeyModifier.RCTRL){
			result ~= "RCTRL;";
		}
		if(keymod && KeyModifier.LALT == KeyModifier.LALT){
			result ~= "LALT;";
		}
		if(keymod && KeyModifier.RALT == KeyModifier.RALT){
			result ~= "RALT;";
		}
		if(keymod && KeyModifier.LGUI == KeyModifier.LGUI){
			result ~= "LGUI;";
		}
		if(keymod && KeyModifier.RGUI == KeyModifier.RGUI){
			result ~= "RGUI;";
		}
		if(keymod && KeyModifier.NUM == KeyModifier.NUM){
			result ~= "NUM;";
		}
		if(keymod && KeyModifier.CAPS == KeyModifier.CAPS){
			result ~= "CAPS;";
		}
		if(keymod && KeyModifier.MODE == KeyModifier.MODE){
			result ~= "MODE;";
		}
		if(keymod && KeyModifier.RESERVED == KeyModifier.RESERVED){
			result ~= "RESERVED;";
		}
		return result;
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
	public int getNumOfVideoModes(){
		return videoModes.length;
	}
	public string videoModeToString(size_t n){
		return to!string(videoModes[n].w) ~ "x" ~ to!string(videoModes[n].h) ~ "@" ~ to!string(videoModes[n].refresh_rate) ~ "Hz";
	}
	public static void setVaultPath(const char* developer, const char* application){
		vaultPath = to!string(SDL_GetPrefPath(developer, application));
	}
	public static string getVaultPath(){
		return vaultPath;
	}

}

public struct AuxillaryElements{
	public string value, name;
	public this(string name, string value){
		this.name = name;
		this.value = value;
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
	SCREENMODE		=	"ScreenMode",
	RESOLUTION		=	"Resolution",
	SCALINGQUALITY	=	"ScalingQuality",
	DRIVER			=	"Driver",
	THREADS			=	"Threads",
}