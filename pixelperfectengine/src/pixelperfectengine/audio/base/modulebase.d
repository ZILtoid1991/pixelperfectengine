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
}