module PixelPerfectEngine.audio.base.pluginbase;

import std.bitmanip;

/*
 * Copyright (C) 2015-2021, by Laszlo Szeremi under the Boost license.
 *
 * Pixel Perfect Engine, audio.base.handler module.
 */

/**
 * Implements the base class for all plugins.
 */
public abstract class PluginBase {
	/**
	 * Contains all data related to plugin info.
	 */
	public struct PluginInfo {
		public ubyte		nOfAudioInput;		///Number of audio input channels
		public ubyte		nOfAudioOutput;		///Number of audio output channels
		public ubyte		nOfMIDIIn;			///Number of MIDI inputs
		public ubyte		nOfMIDIOut;			///Number of MIDI outputs, including sendbacks for MIDI 2.0
		mixin(bitfields!(
			bool, "isInstrument", 1,
			bool, "isEffect", 1,
			bool, "midiSendback", 1,
			uint, "reserved", 29,
		));
    }
	private int		sampleRate;			///The sample rate that the audio subsystem runs at
	private PluginInfo info;///Basic info about the plugin
	/**
	 * Returns the basic informations about this plugin.
	 */
	public PluginInfo getInfo() @nogc @safe pure nothrow const {
		return info;
	}
	/**
	 * Returns the current sample rate.
	 */
	public int getSamplerate() @nogc @safe pure nothrow const {
		return rate;
	}
	/**
	 * MIDI 2.0 data received here.
	 *
	 * data: up to 128 bits of MIDI 2.0 commands. Any packets that are shorter should be padded with zeros.
	 * offsetMSecs: time offset of the command. This can reduce jitter caused by the asynchronous operation of the 
	 * sequencer and the audio plugin system.
	 */
	public abstract void midiReceive(uint[4] data, uint offsetMSecs) @nogc nothrow;
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
}