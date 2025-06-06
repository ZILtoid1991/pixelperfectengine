module pixelperfectengine.audio.base.modulebase;

import std.bitmanip;
import collections.sortedlist;
import midi2.types.structs;

public import pixelperfectengine.audio.base.types;
public import pixelperfectengine.audio.base.handler;


/*
 * Copyright (C) 2015-2021, by Laszlo Szeremi under the Boost license.
 *
 * Pixel Perfect Engine, audio.base.modulebase module.
 */

/**
 * Implements the base class for all audio modules.
 */
public abstract class AudioModule {
	/**
	 * Contains all data related to module info.
	 */
	public struct ModuleInfo {
		public ubyte		nOfAudioInput;		///Number of audio input channels
		public ubyte		nOfAudioOutput;		///Number of audio output channels
		mixin(bitfields!(
			bool, "isInstrument", 1,
			bool, "isEffect", 1,
			bool, "midiSendback", 1,
			bool, "hasMidiIn", 1,
			bool, "hasMidiOut", 1,
			uint, "reserved", 11,
		));
		public string[]		inputChNames;		///Names of the input channels
		public string[]		outputChNames;		///Names of the output channels
    }
	protected size_t		bufferSize;			///The size of the output buffers (must kept as a constant)
	protected int			sampleRate;			///The sample rate that the audio subsystem runs at
	protected ModuleInfo	info;				///Basic info about the plugin
	protected ModuleManager	handler;			///The main audio handler, also MIDI outs can be passed there
	alias StreamIDSet = SortedList!(ubyte, "a < b", false);
	protected StreamIDSet	enabledInputs;		///List of enabled input channel numbers
	protected StreamIDSet	enabledOutputs;		///List of enabled output channel numbers
	public @nogc nothrow void delegate(UMP data0, uint data1 = 0, uint data2 = 0, uint data3 = 0)	midiOut;	///A delegate where MIDI messages are being routed
	/**
	 * Returns the basic informations about this module.
	 */
	public ModuleInfo getInfo() @nogc @safe pure nothrow {
		return info;
	}
	/**
	 * Returns the current sample rate.
	 */
	public int getSamplerate() @nogc @safe pure nothrow const {
		return sampleRate;
	}
	/**
	 * Sets the module up.
	 *
	 * Can be overridden in child classes to allow resets.
	 */
	public void moduleSetup(ubyte[] inputs, ubyte[] outputs, int sampleRate, size_t bufferSize, ModuleManager handler) 
			@safe nothrow {
		enabledInputs = StreamIDSet(inputs);
		enabledOutputs = StreamIDSet(outputs);
		this.sampleRate = sampleRate;
		this.bufferSize = bufferSize;
		this.handler = handler;
	}
	/**
	 * MIDI 2.0 data received here.
	 *
	 * data0: Header of the up to 128 bit MIDI 2.0 data.
	 * data1-3: Other packets if needed.
	 */
	public abstract void midiReceive(UMP data0, uint data1 = 0, uint data2 = 0, uint data3 = 0) @nogc nothrow;
	/**
	 * Renders the current audio frame.
	 * 
	 * input: the input buffers if any, null if none.
	 * output: the output buffers if any, null if none.
	 *
	 * NOTE: Buffers must have matching sizes.
	 */
	public abstract void renderFrame(float*[] input, float*[] output) @nogc nothrow;
	/**
	 * Receives waveform data that has been loaded from disk for reading. Returns zero if successful, or a specific 
	 * errorcode.
	 *
	 * id: The ID of the waveform.
	 * rawData: The data itself, in unprocessed form.
	 * format: The format of the wave data, including the data type, bit depth, base sampling rate
	 */
	public abstract int waveformDataReceive(uint id, ubyte[] rawData, WaveFormat format) nothrow;
	/** 
	 * Creates a new waveform from an existing one using slicing.
	 * Params:
	 *   id = The ID of the new sample.
	 *   src = The ID of the original sample.
	 *   pos = The position where the slice begins.
	 *   length = The length of the slice.
	 * Returns: 0 on success, -1 if module don't support this feature, -2 if slice is out of bounds (longer than the
	 * sample, etc.), -3 if sample is not slicable (ADPCM, etc.).
	 */
	public int waveformSlice(uint id, uint src, uint pos, uint length) nothrow {
		return -1;
	}
	/** 
	 * Returns the waveform data from the
	 * Params:
	 *   id = The ID of the waveform.
	 * Returns: The raw waveform data, or null on error (unsupported feature, waveform not found, etc.)
	 */
	public const(ubyte)[] getWaveformData(uint id) nothrow {
		return null;
	}
	/** 
	 * Returns the format of the selected waveform
	 * Params:
	 *   id = The ID of the waveform.
	 * Returns: The format of the waveform data, or WaveFormat.init if not available.
	 */
	public WaveFormat getWaveformDataFormat(uint id) nothrow {
		return WaveFormat.init;
	}
	///Returns the available waveform ID list
	public uint[] getWaveformIDList() nothrow {
		return null;
	}
	///Returns the list of internal waveform IDs if there are any.
	public uint[] getInternalWaveformIDList() nothrow {
		return null;
	}
	///Returns the names of the internal waveforms if there are any.
	public string[] getInternalWaveformNames() nothrow {
		return null;
	}
	/**
	 * Restores a parameter to the given preset.
	 * Returns an errorcode on failure.
	 */
	public abstract int writeParam_int(uint presetID, uint paramID, int value) nothrow;
	/**
	 * Restores a parameter to the given preset.
	 * Returns an errorcode on failure.
	 */
	public abstract int writeParam_long(uint presetID, uint paramID, long value) nothrow;
	/**
	 * Restores a parameter to the given preset.
	 * Returns an errorcode on failure.
	 */
	public abstract int writeParam_double(uint presetID, uint paramID, double value) nothrow;
	/**
	 * Restores a parameter to the given preset.
	 * Returns an errorcode on failure.
	 */
	public abstract int writeParam_string(uint presetID, uint paramID, string value) nothrow;
	/** 
	 * Returns all the possible parameters this module has.
	 */
	public abstract MValue[] getParameters() nothrow;
	/** 
	 * Reads the given value (int).
	 * Params:
	 *   presetID = The preset ID, or uint.max for global module values.
	 *   paramID = The parameter ID.
	 * Returns: The value of the given preset and parameter
	 */
	public abstract int readParam_int(uint presetID, uint paramID) nothrow;
	/** 
	 * Reads the given value (int).
	 * Params:
	 *   presetID = The preset ID, or uint.max for global module values.
	 *   paramID = The parameter ID.
	 * Returns: The value of the given preset and parameter
	 */
	public abstract long readParam_long(uint presetID, uint paramID) nothrow;
	/** 
	 * Reads the given value (int).
	 * Params:
	 *   presetID = The preset ID, or uint.max for global module values.
	 *   paramID = The parameter ID.
	 * Returns: The value of the given preset and parameter
	 */
	public abstract double readParam_double(uint presetID, uint paramID) nothrow;
	/** 
	 * Reads the given value (int).
	 * Params:
	 *   presetID = The preset ID, or uint.max for global module values.
	 *   paramID = The parameter ID.
	 * Returns: The value of the given preset and parameter
	 */
	public abstract string readParam_string(uint presetID, uint paramID) nothrow;
	/** 
	 * Sets the master level of the module or the module's channel.
	 * Params:
	 *   level = the new audio level, linear, between 0.0 and 1.0.
	 *   channel = the given channel, or -1 if module master level is needed.
	 * Returns: The new level, or NaN if either channel number or value is out of bounds
	 */
	public abstract float setMasterLevel(float level, int channel = -1) @nogc nothrow;
	/// Returns the names of the available channels.
	public string[] getChannelNames() nothrow {
		return null;
	}
	/// Returns all the available channels
	public ubyte[] getAvailableChannels() nothrow {
		return null;
	}
}
