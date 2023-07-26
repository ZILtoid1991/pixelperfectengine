module pixelperfectengine.audio.base.config;

import sdlang;

import pixelperfectengine.audio.base.handler;
import pixelperfectengine.audio.base.modulebase;

import collections.commons : defaultHash;

import std.algorithm.searching : countUntil;
import std.array : split;
import std.conv : to;

/** 
 * Module and audio routin configurator.
 * Loads an SDL file, then configures the modules and sets up their routing, presets, etc.
 * See `modulesetup.md` on documentation about how the format works internally.
 */
public class ModuleConfig {
	/**
	 * Defines a routing node.
	 * Can contain multiple inputs and outputs.
	 */
	protected static struct RoutingNode {
		string name;
		string[] inputs;
		string[] outputs;
		bool opEquals(const RoutingNode other) const @nogc @safe pure nothrow {
			return this.name == other.name;
		}
		///Returns true if input is found in the routing node.
		bool hasInput(string s) {
			return countUntil(inputs, s) != -1;
		}
		///Returns true if output is found in the routing node.
		bool hasOutput(string s) {
			return countUntil(outputs, s) != -1;
		}
	}
	///Registered output channel names.
	protected static immutable string[] outChannelNames = 
			["outputL", "outputR", "surroundL", "surroundR", "center", "lowfreq"];
	///Stores most of the document data here when uncompiled.
	protected Tag					root;
	///The target for audio handling.
	protected ModuleManager			manager;
	///Routing nodes that have been parsed so far.
	protected RoutingNode[]			rns;
	///The audio modules stored by this configuration.
	public AudioModule[]			modules;
	///Track routing for MIDI devices.
	public uint[]					midiRouting;
	///Group identifiers for tracks.
	public ubyte[]					midiGroups;
	///The names of the modules.
	public string[]					modNames;
	/**
	 * Loads an audio configuration, and parses it. Does not automatically compile it.
	 * Params:
	 *   src: the text of the cconfig file.
	 *   manager: the ModuleManager, that will handle audio capabilities.
	 */
	public this(string src, ModuleManager manager) {
		root = parseSource(src);
		this.manager = manager;
	}
	/**
	 * Creates an empty audio configuration, e.g. for editors.
	 * Params:
	 *   manager: the ModuleManager, that will handle audio capabilities.
	 */
	public this(ModuleManager manager) {
		this.manager = manager;
		root = new Tag(null);
	}
	/** 
	 * Loads a configuration file from text.
	 * Params:
	 *   src = the text of the configuration file.
	 */
	public void loadConfig(string src) @trusted {
		root = parseSource(src);
	}
	/** 
	 * Loads a configuration file from file
	 * Params:
	 *   path = Path to the file.
	 */
	public void loadConfigFromFile(string path) {
		import std.stdio : File;
		File f = File(path);
		char[] c;
		c.length = cast(size_t)f.size();
		f.rawRead(c);
		loadConfig(c.idup);
	}
	/** 
	 * Saves the configuration into a file.
	 * Params:
	 *   path = the path of the file.
	 */
	public void save(string path) {
		import std.file : write;
		write(path, root.toSDLDocument());
	}
	/**
	 * Compiles the current configuration, then configures the modules accordingly.
	 * Params:
	 *  isRunning = If true, then the audio thread will be suspended on the duration of the configuration.
	 */
	public void compile(bool isRunning) {
		rns.length = 0;
		modules.length = 0;
		modNames.length = 0;
		midiRouting.length = 0;
		midiGroups.length = 0;
		if (isRunning)
			manager.suspendAudioThread();
		foreach (Tag t0; root.tags) {
			switch (t0.name) {
				case "module":
					string modName = t0.values[1].get!string;
					AudioModule currMod;
					switch (t0.values[0].get!string) {
						case "qm816":
							import pixelperfectengine.audio.modules.qm816;
							currMod = new QM816();
							break;
						case "pcm8":
							import pixelperfectengine.audio.modules.pcm8;
							currMod = new PCM8();
							break;
						case "delaylines":
							import pixelperfectengine.audio.modules.delaylines;
							currMod = new DelayLines(t0.values[2].get!int(), t0.values[3].get!int());
							break;
						default:
							break;
					}
					modules ~= currMod;
					modNames ~= modName;
					foreach (Tag t1; t0.tags) {
						switch (t1.name) {
							case "loadSample":
								const string dpkSource = t1.getAttribute!string("dpk", null);
								loadAudioFile(currMod, t1.values[1].get!int(), t1.values[0].get!string(), dpkSource);
								break;
							case "waveformSlice":
								currMod.waveformSlice(t1.values[0].get!int, t1.values[1].get!int, t1.values[2].get!int, t1.values[3].get!int);
								break;
							case "presetRecall":
								const int presetID = t1.values[0].get!int();
								//const string presetName = t1.getAttribute("name", string.init);
								foreach (Tag t2; t1.tags) {
									uint paramID;
									if (t2.values[0].peek!string) {
										paramID = defaultHash(t2.values[0].get!string);
									} else {
										paramID = cast(uint)(t2.values[0].get!long);
									}
									if (t2.values[1].peek!string) {
										currMod.writeParam_string(presetID, paramID, t2.values[1].get!string);
									} else if (t2.values[1].peek!long) {
										currMod.writeParam_long(presetID, paramID, t2.values[1].get!long);
									} else if (t2.values[1].peek!int) {
										currMod.writeParam_int(presetID, paramID, t2.values[1].get!int);
									} else if (t2.values[1].peek!double) {
										currMod.writeParam_double(presetID, paramID, t2.values[1].get!double);
									} else if (t2.values[1].peek!bool) {
										currMod.writeParam_int(presetID, paramID, t2.values[1].get!bool ? 1 : 0);
									}
								}
								break;
							default:
								break;
						}
					}
					break;
				case "route":
					ptrdiff_t nRoutNode = countUntil!("a.name == b")(rns, t0.values[1].get!string());
					if (nRoutNode == -1) {	//If routing node doesn't exist yet, create it!
						rns ~= RoutingNode(t0.values[1].get!string(), [t0.values[0].get!string()], [t0.values[1].get!string()]);
					} else {				//If does, then just add a new input.
						rns[nRoutNode].inputs ~= t0.values[0].get!string();
					}
					break;
				case "node":
					RoutingNode node = RoutingNode(t0.values[0].get!string(), [], []);
					foreach (Tag t1; t0.expectTag("input").tags) {
						node.inputs ~= t1.getValue!string();
					}
					foreach (Tag t1; t0.expectTag("output").tags) {
						node.outputs ~= t1.getValue!string();
					}
					if (node.inputs.length == 0 && node.outputs.length == 0)	//Node is invalidated, remove it
						t0.remove();
					else if (node.inputs.length && node.outputs.length)			//Only use nodes that have valid inputs and outputs
						rns ~= node;
					break;
				case "midiRouting":
					foreach (Tag t1 ; t0.tags) {
						midiRouting ~= t1.values[0].get!int;
						midiGroups ~= cast(ubyte)(t1.getAttribute!int("group", 0));
					}
					/* midiRouting ~= t0.values[0].get!int;
					midiGroups ~= cast(ubyte)(t0.getAttribute!int("group", 0)); */
					break;
				default:
					break;
			}
		}
		manager.setBuffers(rns.length);
		foreach (size_t i, AudioModule am; modules) {
			string[] modIns = am.getInfo.inputChNames;
			string[] modOuts = am.getInfo.outputChNames;
			size_t[] inBufs, outBufs;
			ubyte[] inChs, outChs;
			foreach (size_t k, string key; modIns) {
				for (size_t j ; j < rns.length ; j++) {
					if (rns[j].hasOutput(modNames[i] ~ ":" ~ key)) {
						inBufs ~= j;
						inChs ~= cast(ubyte)k;
						break;
					}
				}
			}
			foreach (size_t k, string key; modOuts) {
				for (size_t j ; j < rns.length ; j++) {
					if (rns[j].hasInput(modNames[i] ~ ":" ~ key)) {
						outBufs ~= j;
						outChs ~= cast(ubyte)k;
						break;
					}
				}
			}
			manager.addModule(am, inBufs, inChs, outBufs, outChs);
		}
		if (isRunning)
			manager.runAudioThread();
	}
	/**
	 * Loads an audio file into the given audio module.
	 * This function is external, with the intent of being able to alter default voicebanks for e.g. mods, 
	 * localizations, etc.
	 * Params:
	 *  modID = The module identifier string, usually its name within the configuration.
	 *  waveID = The waveform ID. Conflicting waveforms will be automatically overwitten.
	 *  path = Path of the file to be loaded.
	 *  dataPak = If a DataPak is used, then the path to it must be specified there, otherwise it's null.
	 */
	public void loadAudioFile(string modID, int waveID, string path, string dataPak = null) {
		import std.path : extension;
		loadAudioFile(modules[countUntil(modNames, modID)], waveID, path, dataPak);
	}
	/**
	 * Loads an audio file into the given audio module.
	 * Params:
	 *  mod = The module, that needs the waveform data.
	 *  waveID = The waveform ID. Conflicting waveforms will be automatically overwitten.
	 *  path = Path of the file to be loaded.
	 *  dataPak = If a DataPak is used, then the path to it must be specified there, otherwise it's null.
	 */
	protected void loadAudioFile(AudioModule mod, int waveID, string path, string dataPak = null) {
		import std.path : extension;
		switch (extension(path)) {
			case ".wav":
				loadWaveFile(mod, waveID, path, dataPak);
				break;
			case ".voc", ".adp", ".ad4":
				loadVocFile(mod, waveID, path, dataPak);
				break;
			default:
				break;
		}
	}
	/**
	 * Loads a Microsoft Wave (wav) file into a module.
	 * Params:
	 *  mod = The module, that needs the waveform data.
	 *  waveID = The waveform ID. Conflicting waveforms will be automatically overwitten.
	 *  path = Path of the file to be loaded.
	 *  dataPak = If a DataPak is used, then the path to it must be specified there, otherwise it's null.
	 */
	protected void loadWaveFile(AudioModule mod, int waveID, string path, string dataPak = null) {
		import pixelperfectengine.system.wavfile;
		WavFile f = new WavFile(path);
		mod.waveformDataReceive(waveID, f.rawData[52..$].dup, 
				WaveFormat(f.header.samplerate, f.header.bytesPerSecond, f.header.format, f.header.channels, 
				f.header.bytesPerSample, f.header.bitsPerSample));
	}
	/**
	 * Loads a Dialogic ADPCM (voc/af4) file into a module.
	 * Params:
	 *  mod = The module, that needs the waveform data.
	 *  waveID = The waveform ID. Conflicting waveforms will be automatically overwitten.
	 *  path = Path of the file to be loaded.
	 *  dataPak = If a DataPak is used, then the path to it must be specified there, otherwise it's null.
	 */
	protected void loadVocFile(AudioModule mod, int waveID, string path, string dataPak = null) {
		import std.stdio : File;
		import std.path : extension;
		File f = File(path);
		ubyte[] buf;
		buf.length = cast(size_t)f.size();
		f.rawRead(buf);
		const int samplerate = extension(path) == ".voc" || extension(path) == ".adp" ? 8000 : 36_000;
		mod.waveformDataReceive(waveID, buf, WaveFormat(samplerate, samplerate / 2, AudioFormat.DIALOGIC_OKI_ADPCM, 1, 1, 4));
	}
	/**
	 * Edits a preset parameter.
	 * Params:
	 *   modID = The module identifier string, usually its name within the configuration.
	 *   presetID = The preset identifier number.
	 *   paramID = The ID of the parameter, either the type of a string, or a long.
	 *   value = The value to be written into the preset.
	 *   backup = Previous value of the parameter, otherwise left unaltered.
	 *   name = Optional name of the preset.
	 */
	public void editPresetParameter(string modID, int presetID, Value paramID, Value value, ref Value backup, 
			string name = null) {
		foreach (Tag t0 ; root.tags) {
			if (t0.name == "module") {
				if (t0.values[1].get!string == modID) {
					foreach (Tag t1 ; t0.tags) {
						if (t1.name == "presetRecall" && t1.values[0].peek!int && t1.values[0].get!int() == presetID) {
							foreach (Tag t2 ; t1.tags) {
								
								if (t2.values[0] == paramID) {
									backup = t2.values[1];
									t2.values[1] = value;
									return;
								}
								
							}
							new Tag(t1, null, null, [Value(paramID), Value(value)]);
							return;
						}
					}
					Attribute[] attr;
					if (name.length)
						attr ~= new Attribute("name", Value(name));
					Tag t_1 = new Tag(t0, null, "presetRecall", [Value(presetID)], attr);
					new Tag(t_1, null, null, [paramID, value]);
					return;
				}
			}
		}

	}
	/** 
	 * Adds a routing to the audio configuration. Automatically creates nodes if names are not recognized either as
	 * module ports or audio outputs.
	 * Params:
	 *   from = Source of the routing. Can be either a module output or a node.
	 *   to = Destination of the routing. Can be either a module input, a node, or an audio output.
	 */
	public void addRouting(string from, string to) {
		const bool fromModule = from.split(":").length == 2;
		const bool toModule = to.split(":").length == 2 || countUntil(outChannelNames, to) != -1;
		if (fromModule && toModule) {
			new Tag(root, null, "route", [Value(from), Value(to)]);
		} else if (fromModule) {
			foreach (Tag t0; root.tags) {
				if (t0.name == "node" && t0.getValue!string == to) {
					new Tag(t0.expectTag("input"), null, null, [Value(from)]);
					return;
				}
			}
			new Tag(root, null, "node", [Value(to)], null, 
				[
					new Tag(null, "input", null, null, [
						new Tag(null, null, from)
					]), 
					new Tag(null, "output")
				]);
		} else {	//(toModule)
			foreach (Tag t0; root.tags) {
				if (t0.name == "node" && t0.getValue!string == from) {
					new Tag(t0.expectTag("output"), null, null, [Value(to)]);
					return;
				}
			}
			new Tag(root, null, "node", [Value(from)], null, 
				[
					new Tag(null, "input"), 
					new Tag(null, "output", null, null, [
						new Tag(null, null, to)
					])
				]);
		}
	}
	/** 
	 * Removes a routing from the audio configuration.
	 * Params:
	 *   from = Source of the routing. Can be either a module output or a node.
	 *   to = Destination of the routing. Can be either a module input, a node, or an audio output.
	 * Returns: True if routing is found and then removed, false otherwise.
	 */
	public bool removeRouting(string from, string to) {
		const bool fromModule = from.split(":").length == 2;
		const bool toModule = to.split(":").length == 2 || countUntil(outChannelNames, to) != -1;
		if (fromModule && toModule) {
			foreach (Tag t0; root.tags) {
				if (t0.name == "route") {
					if (t0.values[0] == from && t0.values[1] == to) {
						t0.remove();
						return true;
					}
				}
			}
		} else if (fromModule) {
			foreach (Tag t0; root.tags) {
				if (t0.name == "node" && t0.getValue!string == to) {
					Tag t1 = t0.expectTag("input");
					foreach (Tag t2 ; t1.tags())
					if (t2.getValue!string == from) {
						t2.remove();
						return true;
					}
				}
			}
		} else {	//(toModule)
			foreach (Tag t0; root.tags) {
				if (t0.name == "node" && t0.getValue!string == from) {
					Tag t1 = t0.expectTag("output");
					foreach (Tag t2 ; t1.tags())
					if (t2.getValue!string == to) {
						t2.remove();
						return true;
					}
				}
			}
		}
		return false;
	}
	/** 
	 * Returns the routing table of this audio configuration as an array of pairs of strings. 
	 */
	public string[2][] getRoutingTable() {
		string[2][] result;
		foreach (Tag t0 ; root.tags()) {
			switch (t0.name) {
				case "route":
					result ~= [t0.values[0].get!string, t0.values[1].get!string];
					break;
				case "node":
					const string nodeName = t0.values[0].get!string;
					foreach (Tag t1; t0.expectTag("input").tags) {
						result ~= [t1.values[0].get!string, nodeName];
					}
					foreach (Tag t1; t0.expectTag("output").tags) {
						result ~= [nodeName, t1.values[0].get!string];
					}
					break;
				default:
					break;
			}
		}
		return result;
	}
	/** 
	 * Adds a new module to the configuration.
	 * Params:
	 *   type = Type of the module.
	 *   name = Name and ID of the module.
	 */
	public void addModule(string type, string name) {
		switch (type) {
			case "delaylines1010":
				new Tag(root, null, "module", [Value("delaylines"), Value(name), Value(1024), Value(1024)]);
				break;
			case "delaylines1012":
				new Tag(root, null, "module", [Value("delaylines"), Value(name), Value(1024), Value(4096)]);
				break;
			case "delaylines1212":
				new Tag(root, null, "module", [Value("delaylines"), Value(name), Value(4096), Value(4096)]);
				break;
			default:
				new Tag(root, null, "module", [Value(type), Value(name)]);
				break;
		}
	}
	/** 
	 * Adds a module from backup.
	 * Params:
	 *   backup = The module tag containing all the info associated with the module.
	 */
	public void addModule(Tag backup) {
		root.add(backup);
	}
	/**
	 * Renames a module.
	 * Params:
	 *   oldName = The current name of the module.
	 *   newName = the desired name of the module.
	 */
	public void renameModule(string oldName, string newName) {
		foreach (Tag t0 ; root.tags) {
			if (t0.name == "module") {
				if (t0.values[1] == oldName) {
					t0.values[1] = Value(newName);
					return;
				}
			}
		}
	}
	/** 
	 * Removes a module from the configuration.
	 * Params:
	 *   name = Name/ID of the module.
	 * Returns: An SDL tag containing all the information related to the module, or null if ID is invalid.
	 */
	public Tag removeModule(string name) {
		foreach (Tag t0 ; root.tags) {
			if (t0.name == "module") {
				if (t0.values[1] == name) {
					t0.remove();
					return t0;
				}
			}
		}
		return null;
	}
	/**
	 * Returns the module with the given `name`, or null if not found.
	 */
	public AudioModule getModule(string name) @safe {
		foreach (size_t i, string n; modNames) {
			if (n == name)
				return modules[i];
		}
		return null;
	}
	///Returns the number of the module, or -1 if the module name does not exist.
	sizediff_t getModuleNum(string name) @safe const {
		foreach (size_t i, string n; modNames) {
			if (n == name)
				return i;
		}
		return -1;
	}
	/**
	 * Returns a list of modules.
	 */
	public string[2][] getModuleList() {
		string[2][] result;
		foreach (Tag t0 ; root.tags) {
			if (t0.name == "module") {
				result ~= [t0.values[0].get!string, t0.values[1].get!string];
			}
		}
		return result;
	}
	/** 
	 * Removes a preset from the configuration.
	 * Params:
	 *   modID = Module name/ID.
	 *   presetID = Preset ID.
	 * Returns: The tag containing all the info related to the preset for backup, or null if module and/or 
	 * preset ID is invalid.
	 */
	public Tag removePreset(string modID, int presetID) {
		foreach (Tag t0 ; root.tags) {
			if (t0.name == "module") {
				if (t0.values[1] == modID) {
					foreach (Tag t1; t0.tags) {
						if (t1.name == "presetRecall" && t1.getValue!int == presetID) {
							return t1.remove;
						}
					}
				}
			}
		}
		return null;
	}
	/** 
	 * Adds a preset to the configuration either from a backup or an import.
	 * Params:
	 *   modID = Module name/ID.
	 *   backup = The preset to be (re)added.
	 */
	public void addPreset(string modID, Tag backup) {
		foreach (Tag t0 ; root.tags) {
			if (t0.name == "module") {
				if (t0.values[1] == modID) {
					t0.add(backup);
					return;
				}
			}
		}
	}
	/**
	 * Returns the list of presets associated with the module identified by `modID`.
	 */
	public auto getPresetList(string modID) {
		struct PresetData {
			string name;
			int id;
		}
		PresetData[] result;
		foreach (Tag t0 ; root.tags) {
			if (t0.name == "module") {
				if (t0.values[1] == modID) {
					foreach (Tag t1; t0.tags) {
						if (t1.name == "presetRecall") {
							result ~= PresetData(t1.getAttribute!string("name"), t1.expectValue!int);
						}
					}
					return result;
				}
			}
		}
		return result;
	}
	/**
	 * Adds a wave file to the given module.
	 * Params:
	 *   path = the path of the wave file.
	 *   modID = the ID of the module, that will use the wave file.
	 *   waveID = the ID of the waveform to be loaded.
	 *   dpkPath = path to the DataPak file if there's one.
	 *   name = name of the waveform if there's one specified.
	 * Returns: The tag that was added to the configuration file, or null on error.
	 */
	public Tag addWaveFile(string path, string modID, int waveID, string dpkPath, string name) {
		foreach (Tag t0 ; root.tags) {
			if (t0.name == "module") {
				if (t0.values[1] == modID) {
					Attribute[] attr;
					if (name.length) {
						attr ~= new Attribute("name", Value(name));
					}
					if (dpkPath.length) {
						attr ~= new Attribute("dpkPath", Value(dpkPath));
					}
					Tag t1 = new Tag(t0, null, "loadSample", [Value(path), Value(waveID)], attr);
					return t1;
				}
			}
		}
		return null;
	}
	/**
	 * Creates a waveform from another by slicing.
	 * Params:
	 *   modID = ID of the target module.
	 *   waveID = ID of the new waveform.
	 *   src = ID of the source waveform.
	 *   pos = Position of the beginning of the slice.
	 *   len = Length of the slice.
	 * Returns: The tag that was added to the configuration file, or null on error.
	 */
	public Tag addWaveSlice(string modID, int waveID, int src, int pos, int len, string name) {
		foreach (Tag t0 ; root.tags) {
			if (t0.name == "module") {
				if (t0.values[1] == modID) {
					Attribute[] attr;
					if (name.length) {
						attr ~= new Attribute("name", Value(name));
					}
					Tag t1 = new Tag(t0, null, "waveformSlice", [Value(waveID), Value(src), Value(pos), Value(len)], attr);
					return t1;
				}
			}
		}
		return null;
	}
	/**
	 * Adds a waveform data tag from `backup` to the module described by `modID`.
	 */
	public void addWaveFromBackup(string modID, Tag backup) {
		foreach (Tag t0 ; root.tags) {
			if (t0.name == "module") {
				if (t0.values[1] == modID) {
					t0.add(backup);
					return;
				}
			}
		}
	}
	/**
	 * Removes a waveform identified by `waveID` from the module described by `modID`,
	 * then returns the configuration tag as backup. Returns null if module and/or waveform not found.
	 */
	public Tag removeWave(string modID, int waveID) {
		foreach (Tag t0 ; root.tags) {
			if (t0.name == "module") {
				if (t0.values[1] == modID) {
					foreach (Tag t1 ; t0.tags) {
						switch (t1.name) {
							case "loadSample":
								if (t1.values[1].get!int == waveID)
									return t1.remove();
								break;
							case "waveformSlice":
								if (t1.values[0].get!int == waveID)
									return t1.remove();
								break;
							default: break;
						}
					}
				}
			}
		}
		return null;
	}
	/**
	 * Renames a wave file definition.
	 * Does not affect internal waves if they're overridden.
	 * Params:
	 *   modID = module ID.
	 *   waveID = Waveform ID.
	 *   newName = The new name for the waveform.
	 * Returns: The old name if there's any.
	 */
	public string renameWave(string modID, int waveID, string newName) {
		string oldName;
		foreach (Tag t0 ; root.tags) {
			if (t0.name == "module") {
				if (t0.values[1] == modID) {
					foreach (Tag t1 ; t0.tags) {
						void doThing() {
							if (t1.getAttribute!string("name")) {
								oldName = t1.getAttribute!string("name");
								t1.attributes["name"][0].remove;
							}
							if (newName.length) {
								t1.add(new Attribute("name", Value(newName)));
							}
						}
						switch (t1.name) {
							case "loadSample":
								if (t1.values[1].get!int == waveID) {
									doThing();
									return oldName;
								}
								break;
							case "waveformSlice":
								if (t1.values[0].get!int == waveID) {
									doThing();
									return oldName;
								}
								break;
							default: break;
						}
					}
				}
			}
		}
		return oldName;
	}
	/**
	 * Returns the waveform list belonging to the audio module identified by `modID`.
	 */
	public WaveFileData[] getWaveFileList(string modID) {
		WaveFileData[] result;
		foreach (Tag t0 ; root.tags) {
			if (t0.name == "module") {
				if (t0.values[1] == modID) {
					foreach (Tag t1 ; t0.tags) {
						switch (t1.name) {
							case "loadSample":
								result ~= WaveFileData(t1.values[1].get!int, t1.getAttribute!string("dpkPath"), t1.values[0].get!string, 
										t1.getAttribute!string("name"), false, false);
								break;
							case "waveformSlice":
								result ~= WaveFileData(t1.values[0].get!int, null, "SLICE FROM:" ~ to!string(t1.values[1].get!int), 
										t1.getAttribute!string("name"), true, false);
								break;
							default: break;
						}
					}
					AudioModule m = getModule(modID);
					if (m !is null) {
						uint[] internalIDList = m.getInternalWaveformIDList();
						string[] internalNameList = m.getInternalWaveformNames();
						assert (internalIDList.length == internalNameList.length);
						for (int i ; i < internalIDList.length ; i++) {
							result ~= WaveFileData(internalIDList[i], null, "INTERNAL", internalNameList[i], false, true);
						}
					}
					return result;
				}
			}
		}
		return result;
	}
	///Creates a MIDI routing table from the supplied values.
	public void setMIDIrouting(uint[] table) {
		Tag t0 = root.getTag("midiRouting");
		if (t0 is null) {
			t0 = new Tag(root, null, "midiRouting");
		}
		if (t0.tags.length) {
			foreach (Tag t1 ; t0.tags) {
				t1.remove();
			}
		}
		foreach (uint i ; table) {
			new Tag(t0, null, null, [Value(cast(int)i)]);
		}
	}
}
/**
 * Implements a structure for wave file data storage.
 */
struct WaveFileData {
	int id;				//Waveform ID.
	string dpkPath;		//DataPak file path if exists, null otherwise.
	string path;		//Path to the source file, null if slice of internal.
	string name;		//Name of the waveform.
	bool isSlice;		//True if waveform is a slice of another one.
	bool isInternal;	//True if waveform is internal to the module.
}