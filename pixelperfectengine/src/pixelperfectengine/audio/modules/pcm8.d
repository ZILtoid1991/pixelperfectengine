module pixelperfectengine.audio.modules.pcm8;

import pixelperfectengine.audio.base.modulebase;
import pixelperfectengine.audio.base.types;
import pixelperfectengine.audio.base.envgen;
import pixelperfectengine.audio.base.func;

import collections.treemap;

import inteli.emmintrin;

import midi2.types.structs;
import midi2.types.enums;

import bitleveld.datatypes;

/**
PCM8 - implements a sample-based synthesizer.

It has support for 
 * 8 bit and 16 bit linear PCM
 * Mu-Law and A-Law PCM
 * IMA ADPCM
 * Dialogic ADPCM

The module has 8 sample-based channels with looping capabilities and each has an ADSR envelop, and 4 outputs with a filter.
*/
public class PCM8 : AudioModule {
	/** 
	Contains a table to calculate Attack, Decay, and Release values.

	All values are seconds with factions. Actual values are live-calculated depending on sustain-level and sampling
	frequency.
	*/
	public static immutable float[128] ADSR_TIME_TABLE = [
	//	0     |1     |2     |3     |4     |5     |6     |7     |8     |9     |A     |B     |C     |D     |E     |F
		0.000, 0.0005,0.001, 0.0015,0.002, 0.0025,0.003, 0.0035,0.004, 0.0045,0.005, 0.006, 0.007, 0.008, 0.009, 0.010,//0
		0.011, 0.012, 0.013, 0.014, 0.015, 0.017, 0.019, 0.021, 0.023, 0.025, 0.028, 0.031, 0.034, 0.038, 0.042, 0.047,//1
		0.052, 0.057, 0.062, 0.067, 0.073, 0.079, 0.085, 0.092, 0.099, 0.107, 0.116, 0.126, 0.137, 0.149, 0.162, 0.176,//2
		0.191, 0.207, 0.224, 0.242, 0.261, 0.281, 0.302, 0.324, 0.347, 0.371, 0.396, 0.422, 0.449, 0.477, 0.506, 0.536,//3
		0.567, 0.599, 0.632, 0.666, 0.701, 0.737, 0.774, 0.812, 0.851, 0.891, 0.932, 0.974, 1.017, 1.061, 1.106, 1.152,//4
		1.199, 1.247, 1.296, 1.346, 1.397, 1.499, 1.502, 1.556, 1.611, 1.667, 1.724, 1.782, 1.841, 1.901, 1.962, 2.024,//5
		2.087, 2.151, 2.216, 2.282, 2.349, 2.417, 2.486, 2.556, 2.627, 2.699, 2.772, 2.846, 2.921, 2.997, 3.074, 3.152,//6
		3.231, 3.331, 3.392, 3.474, 3.557, 3.621, 3.726, 3.812, 3.899, 3.987, 4.076, 4.166, 4.257, 4.349, 4.442, 4.535,//7
		
	];
	/**
	Contains a table to calculate Sustain control values.

	All values are seconds with fractions. Actual values are live-calculated depending on sustain level and sampling
	frequency. Please note that with certain levels of sustain, the actual max time might be altered.
	*/
	public static immutable float[63] SUSTAIN_CONTROL_TIME_TABLE = [
	//	0     |1     |2     |3     |4     |5     |6     |7     |8     |9     |A     |B     |C     |D     |E     |F
		70.00, 60.00, 55.00, 50.00, 45.00, 42.50, 40.00, 38.50, 35.00, 32.50, 30.00, 27.50, 25.00, 24.00, 23.00, 22.00,//0
		21.00, 20.00, 19.00, 18.00, 17.50, 17.00, 16.50, 16.00, 15.50, 15.00, 14.50, 14.00, 13.50, 13.00, 12.50, 12.25,//1
		12.00, 11.75, 11.50, 11.25, 11.00, 10.75, 10.50, 10.25, 10.00, 9.750, 9.500, 9.250, 9.000, 8.750, 8.500, 8.250,//2
		8.000, 7.750, 7.500, 7.250, 7.000, 6.750, 6.500, 6.250, 6.000, 5.750, 5.500, 5.250, 5.000, 4.750, 4.500        //3
	];
	/**
	Defines a single sample.
	*/
	protected struct Sample {
		///Stores sample data, which later can be decompressed
		ubyte[]		sampleData;
		///Stores what kind of format the sample has
		WaveFormat	format;
	}
	/**
	Defines a single sample-to-note assignment.
	*/
	protected struct SampleAssignment {
		///Number of sample that is assigned.
		uint		sampleNum;
		///The base frequency of the sample.
		///Overrides the format definition.
		float		baseFreq;
		///Start of a looppoint.
		///0, if looppoint is not available.
		uint		loopBegin;
		///End of a looppoint.
		///0, if looppoint is not available.
		uint		loopEnd;
	}
	/**
	Defines a single channel's statuses.
	*/
	protected struct Channel {
		Workpad			decoderWorkpad;
		ubyte			currNote;
		ubyte			presetNum;
		ushort			bankNum;
		float			velocity;
		float			modWheel;
	}
	/** 
	Stores preset information.
	*/
	protected struct Preset {
		/// Stores sample mappings for each note.
		SampleAssignment[128]	sampleMapping;
		ubyte			eAtk;		///Attack time selector
		ubyte			eDec;		///Decay time selector
		ubyte			eSusC;		///Sustain control (0: percussive; 1-63: descending; 64: constant; 65-127: ascending)
		ubyte			eRel;		///Release time selector
		float			eAtkShp = 0.5;///Attack shaping
		float			eRelShp = 0.5;///Release shaping
		float			eSusLev = 1;///Sustain level
		float			masterVol = 1;///Master output volume
		float			balance = 0.5;///Master output balance
		float			auxSendA = 0;///Aux send level A
		float			auxSendB = 0;///Aux send level B
		float			velToLevelAm = 0;///Assigns velocity to output levels
		float			velToAuxSendAm = 0;///Assigns velocity to aux send levels
		float			velToAtkShp = 0;///Assigns velocity to attack shape of envelop generator
		float			velToRelShp = 0;///Assigns velocity to release shape of envelop generator
		uint			flags;		///Contains various binary settings
	}
	protected enum PresetFlags {
		cutoffOnKeyOff		=	1<<0,		///If set, the sample playback will cut off on every key off event
		modwheelToALFO		=	1<<1,		///Assigns modulation wheel to amplitude LFO levels
		modwheelToPLFO		=	1<<2,		///Assigns modulation wheel to pitch LFO levels
		panningALFO			=	1<<3,		///Sets amplitude LFO to panning on this channel
	}
	alias SampleMap = TreeMap!(uint, Sample);
	alias PresetMap = TreeMap!(uint, Preset);
	protected SampleMap		sampleBank;			///Stores all current samples.
	protected PresetMap		presetBank;			///Stores all current presets. (bits: 0-6: preset number, 7-13: bank lsb, 14-20: bank msb)

	public this(ModuleManager handler) @safe nothrow {
		this.handler = handler;
		info.nOfAudioInput = 0;
		info.nOfAudioOutput = 4;
		info.outputChNames = ["mainL", "mainR", "auxSendA", "auxSendB"];
		info.isInstrument = true;
		info.hasMidiIn = true;
		info.hasMidiOut = true;
		info.midiSendback = true;
	}

	/**
	 * MIDI 2.0 data received here.
	 *
	 * data: up to 128 bits of MIDI 2.0 commands. Any packets that are shorter should be padded with zeros.
	 * offset: time offset of the command. This can reduce jitter caused by the asynchronous operation of the 
	 * sequencer and the audio plugin system.
	 */
	public override void midiReceive(uint[4] data, uint offset) @nogc nothrow {

	}
	/**
	 * Renders the current audio frame.
	 * 
	 * input: the input buffers if any, null if none.
	 * output: the output buffers if any, null if none.
	 * length: the lenth of the current audio frame in samples.
	 *
	 * NOTE: Buffers must have matching sizes.
	 */
	public override void renderFrame(float*[] input, float*[] output) @nogc nothrow {

	}
	/**
	 * Receives waveform data that has been loaded from disk for reading. Returns zero if successful, or a specific 
	 * errorcode.
	 *
	 * id: The ID of the waveform.
	 * rawData: The data itself, in unprocessed form.
	 * format: The format of the wave data, including the data type, bit depth, base sampling rate
	 *
	 * Note: This function needs the audio system to be unlocked.
	 */
	public override int waveformDataReceive(uint id, ubyte[] rawData, WaveFormat format) nothrow {
		int result;
		if (!(format.format == AudioFormat.PCM || format.format == AudioFormat.MULAW || format.format == AudioFormat.ALAW || 
				format.format == AudioFormat.ADPCM || format.format == AudioFormat.DIALOGIC_OKI_ADPCM)) 
			result |= SampleLoadErrorCode.FormatNotSupported; 
		result |= format.channels == 1 ? 0 : SampleLoadErrorCode.ChNumNotSupported;
		if (result) {
			return result; 
		} else {
			sampleBank[id] = Sample(rawData, format);
			return 0;
		}
	}
	/**
	 * Restores a parameter to the given preset.
	 * Returns an errorcode on failure.
	 */
	public override int recallParam_int(uint presetID, uint paramID, int value) @nogc nothrow {
		return 0;
	}
	/**
	 * Restores a parameter to the given preset.
	 * Returns an errorcode on failure.
	 */
	public override int recallParam_uint(uint presetID, uint paramID, uint value) @nogc nothrow {
		return 0;
	}
	/**
	 * Restores a parameter to the given preset.
	 * Returns an errorcode on failure.
	 */
	public override int recallParam_double(uint presetID, uint paramID, double value) @nogc nothrow {
		return 0;
	}
	/**
	 * Restores a parameter to the given preset.
	 * Returns an errorcode on failure.
	 */
	public override int recallParam_string(uint presetID, uint paramID, string value) @nogc nothrow {
		return 0;
	}
}