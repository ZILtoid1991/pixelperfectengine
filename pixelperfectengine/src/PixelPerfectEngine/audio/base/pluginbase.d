module PixelPerfectEngine.audio.base.pluginbase;

import std.bitmanip;

import PixelPerfectEngine.audio.base.types;
import PixelPerfectEngine.audio.base.handler;


/*
 * Copyright (C) 2015-2021, by Laszlo Szeremi under the Boost license.
 *
 * Pixel Perfect Engine, audio.base.pluginbase module.
 */

/**
 * Implements the base class for all plugins.
 */
public abstract class AudioPlugin {
	/**
	 * Contains all data related to plugin info.
	 */
	public struct PluginInfo {
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
	protected int			sampleRate;			///The sample rate that the audio subsystem runs at
	protected PluginInfo	info;				///Basic info about the plugin
	protected PluginManager	handler;			///The main audio handler, also MIDI outs can be passed there
	public @nogc nothrow void delegate(uint[4] data, uint offset)	midiOut;	///A delegate where MIDI messages are being routed
	/**
	 * Returns the basic informations about this plugin.
	 */
	public PluginInfo getInfo() @nogc @safe pure nothrow {
		return info;
	}
	/**
	 * Returns the current sample rate.
	 */
	public int getSamplerate() @nogc @safe pure nothrow const {
		return sampleRate;
	}
	/**
	 * MIDI 2.0 data received here.
	 *
	 * data: up to 128 bits of MIDI 2.0 commands. Any packets that are shorter should be padded with zeros.
	 * offset: time offset of the command. This can reduce jitter caused by the asynchronous operation of the 
	 * sequencer and the audio plugin system.
	 */
	public abstract void midiReceive(uint[4] data, uint offset) @nogc nothrow;
	/**
	 * Renders the current audio frame.
	 * 
	 * input: the input buffers if any, null if none.
	 * output: the output buffers if any, null if none.
	 * length: the lenth of the current audio frame in samples.
	 *
	 * NOTE: Buffers must have matching sizes.
	 */
	public abstract void renderFrame(float*[] input, float*[] output, size_t length) @nogc nothrow;
	/**
	 * Receives waveform data that has been loaded from disk for reading. Returns zero if successful, or a specific 
	 * errorcode.
	 *
	 * id: The ID of the waveform.
	 * rawData: The data itself, in unprocessed form.
	 * format: The format of the wave data, including the data type, bit depth, base sampling rate
	 */
	public abstract int waveformDataReceive(uint id, ubyte[] rawData, WaveFormat format) nothrow;
}