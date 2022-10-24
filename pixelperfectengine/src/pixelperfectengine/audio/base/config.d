module pixelperfectengine.audio.base.config;

import sdlang;

import pixelperfectengine.audio.base.handler;
import pixelperfectengine.audio.base.modulebase;

import collections.commons : defaultHash;

import std.algorithm.searching : countUntil;
import std.array : split;

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
		bool hasInput(string s) {
			return countUntil(inputs, s) != -1;
		}
		bool hasOutput(string s) {
			return countUntil(outputs, s) != -1;
		}
	}
	protected static immutable string[] outChannelNames = 
			["outputL", "outputR", "surroundL", "surroundR", "center", "lowfreq"];
	protected Tag					root;
	protected ModuleManager			manager;
	protected RoutingNode[]			rns;
	protected AudioModule[]			modules;
	protected string[]				modNames;
	public this(string src, ModuleManager manager) {
		root = parseSource(src);
		this.manager = manager;
	}
	public void loadConfig(string src) {
		root = parseSource(src);
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
		if (isRunning)
			manager.suspendAudioThread();
		foreach (Tag t0; root.tags) {
			switch (t0.name) {
				case "module":
					string modName = t0.values[1].get!string;
					AudioModule currMod;
					switch (t0.values[0].get!string) {
						case "QM816":
							import pixelperfectengine.audio.modules.qm816;
							currMod = new QM816();
							break;
						case "PCM8":
							import pixelperfectengine.audio.modules.pcm8;
							currMod = new PCM8();
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
					rns ~= node;
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
			foreach (string key; modIns) {
				ptrdiff_t n = countUntil!("a.hasInput(b)")(rns, key);
				if (n != -1) {
					inBufs ~= n;
					inChs ~= cast(ubyte)n;
				}
			}
			foreach (string key; modOuts) {
				ptrdiff_t n = countUntil!("a.hasOutput(b)")(rns, key);
				if (n != -1) {
					outBufs ~= n;
					outChs ~= cast(ubyte)n;
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
			case ".voc":
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
		mod.waveformDataReceive(waveID, f.rawData.dup, 
				WaveFormat(f.header.samplerate, f.header.bytesPerSecond, f.header.format, f.header.channels, 
				f.header.bytesPerSample, f.header.bitsPerSample));
	}
	/**
	 * Loads a Dialogic ADPCM (voc) file into a module.
	 * Params:
	 *  mod = The module, that needs the waveform data.
	 *  waveID = The waveform ID. Conflicting waveforms will be automatically overwitten.
	 *  path = Path of the file to be loaded.
	 *  dataPak = If a DataPak is used, then the path to it must be specified there, otherwise it's null.
	 */
	protected void loadVocFile(AudioModule mod, int waveID, string path, string dataPak = null) {
		import std.stdio : File;
		File f = File(path);
		ubyte[] buf;
		buf.length = cast(size_t)f.size();
		f.rawRead(buf);
		mod.waveformDataReceive(waveID, buf, WaveFormat(8000, 4000, AudioFormat.DIALOGIC_OKI_ADPCM, 1, 1, 4));
	}
	/**
	 * Edits a preset parameter.
	 * Params:
	 *  modID = The module identifier string, usually its name within the configuration.
	 *  presetID = The preset identifier number.
	 *  paramID = The ID of the parameter, either the type of a string, or a long.
	 *  value = The value to be written into the preset.
	 */
	public void editPresetParameter(T, U)(string modID, int presetID, U paramID, T value) {
		foreach (Tag t0 ; root.tags) {
			if (t0.name == "module") {
				if (t0.values[1].get!string == modID) {
					foreach (Tag t1 ; t0.tags) {
						if (t1.name == "presetRecall" && t1.values[0].peek!int && t1.values[0].get!int() == presetID) {

						}
					}
					Tag t_1 = new Tag(t0, null, "presetRecall", [Value!int(presetID)], null);
				}
			}
		}

	}
}