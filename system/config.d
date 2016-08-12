/*
Copyright (C) 2015, by Laszlo Szeremi under the Boost license.

VDP Engine, Config module
*/

module system.config;

import std.xml;
import std.file;
import std.stdio;
import std.string;
import std.conv;

import system.inputHandler;
import system.exc;

public class ConfigurationProfile{
	public int sfxVol, musicVol;
	public string screenMode, resolution, scalingQuality, driver;
	public KeyBinding[] keyBindingList, inputDevList;
	private string lastFile;
	public AuxillaryElements[] auxillaryParameters;
	//public AuxillaryElements auxillaryElements[];

	public this(string configFile){
		lastFile = configFile;
		//restore(lastFile);
	}

	public this(){

	}

	public void restore(string configFile){
		lastFile = configFile;
		string s = cast(string)std.file.read(configFile);
		try{
			check(s);
		}
		catch(CheckException e){
			writeln(e.toString);
		}
		finally{
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
						if(e2.tag.name == "screenMode")
							screenMode = e2.text();
						else if(e2.tag.name == "resolution")
							resolution = e2.text();
						else if(e2.tag.name == "scalingQuality")
							scalingQuality = e2.text();
						else if(e2.tag.name == "driver")
							driver = e2.text();
					}
				}
				else if(e1.tag.name == "Input"){
					int dn = to!uint(e1.tag.attr["devNum"]);
					int dt;
					if(e1.tag.attr["devType"] == "Joystick")
						dt = Devicetype.JOYSTICK;
					else if(e1.tag.attr["devType"] == "Mouse")
						dt = Devicetype.MOUSE;
					inputDevList ~= KeyBinding(0, 0, dn, "", dt);
					foreach(Element e2; e1.elements){
						keyBindingList ~= KeyBinding(to!ushort(e2.tag.attr["keyMod"]), to!uint(e2.tag.attr["keyCode"]), dn, e2.tag.attr["ID"], dt);
					}
						


				}
				else if(e1.tag.name == "Aux"){
					foreach(Element e2; e1.elements){
						auxillaryParameters ~= AuxillaryElements(e2.tag.name, e2.text());
					}
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
		e2 ~= new Element("screenMode", screenMode);
		e2 ~= new Element("resolution", resolution);
		e2 ~= new Element("scalingQuality", scalingQuality);
		e2 ~= new Element("driver", driver);
		doc ~= e2;


		foreach(KeyBinding id; inputDevList){
			auto e3 = new Element("Input");
			e3.tag.attr["devType"] = to!string(id.devicetype);
			e3.tag.attr["devNum"] = to!string(id.devicenumber);
			for(int k; k < keyBindingList.length; k++){
				if(keyBindingList[k].devicetype == id.devicetype && keyBindingList[k].devicenumber == id.devicenumber){
					auto e4 = new Element("KeyBinding");
					e4.tag.attr["keyMod"] = to!string(keyBindingList[k].keymod);
					e4.tag.attr["keyCode"] = to!string(keyBindingList[k].keymod);
					e4.tag.attr["ID"] = keyBindingList[k].ID;
					e3 ~= e4;
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
}

public struct AuxillaryElements{
	public string value, name;
	public this(string name, string value){
		this.name = name;
		this.value = value;
	}
}