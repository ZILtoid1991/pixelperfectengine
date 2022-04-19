module pixelperfectengine.audio.modules.pcm8;

import pixelperfectengine.audio.base.modulebase;
import pixelperfectengine.audio.base.types;
import pixelperfectengine.audio.base.envgen;
import pixelperfectengine.audio.base.func;
import pixelperfectengine.audio.base.envgen;
import pixelperfectengine.audio.base.osc;


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
	
	public static immutable float[128] ADSR_TIME_TABLE;
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
	alias DecodeFunc = void function(ubyte[] src, int[] dest, ref Workpad wp) @nogc nothrow pure;
	/**
	Defines a single sample.
	*/
	protected struct Sample {
		///Stores sample data, which later can be decompressed
		ubyte[]		sampleData;
		///Stores what kind of format the sample has
		WaveFormat	format;
		///Points to the decoder function
		DecodeFunc	decode;
		size_t samplesLength() @nogc @safe pure nothrow const {
			return (sampleData.length * 8) / format.bitsPerSample;
		}
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
		///-1, if looppoint is not available.
		int			loopBegin	=	-1;
		///End of a looppoint.
		///-1, if looppoint is not available.
		int			loopEnd		=	-1;
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
		float			lfoToVol;	///Tremolo level (LFO to volume)
		float			adsrToVol;	///ADSR amount 

		uint			flags;		///Contains various binary settings
	}
	protected enum PresetFlags {
		cutoffOnKeyOff		=	1<<0,		///If set, the sample playback will cut off on every key off event
		modwheelToLFO		=	1<<1,		///Assigns modulation wheel to amplitude LFO levels
		panningLFO			=	1<<2,		///Sets amplitude LFO to panning on this channel
		ADSRtoVol			=	1<<3,		///If set, then envGen will control the volume
	}
	protected enum ChannelStatusFlags {
		noteOn				=	1<<0,
		sampleRunout		=	1<<1,
		inLoop				=	1<<2,
	}
	/**
	Defines a single channel's statuses.
	*/
	protected struct Channel {
		int[257]		decoderBuffer;		///Stores decoded samples.
		Preset			presetCopy;			///The copy of the preset.
		Workpad			decoderWorkpad;		///Stores the current state of the decoder.
		Workpad			savedDWState;		///The state of the decoder when the beginning of the looppoint has been reached.
		WavemodWorkpad	waveModWorkpad;		///Stores the current state of the wave modulator.
		double			freqRatio;			///Sampling-to-playback frequency ratio, with pitch bend, LFO, and envGen applied.
		uint 			jumpAm;				///Jump amount for current sample, calculated from freqRatio.
		uint			outPos;				///Position in decoded amount.
		//WavemodWorkpad	savedWMWState;		///The state of the wave modulator when the beginning of the looppoint has been reached.
		ADSREnvelopGenerator	envGen;		///Channel envelop generator.

		ubyte			currNote;			///The currently played note, or 255 if samples ran out.
		ubyte			presetNum;			///Selected preset.
		ushort			bankNum;			///Bank select number.
		uint			status;				///Channel status flags. Bit 1: Note on, Bit 2: Sample run out approaching, Bit 3: In loop

		float			velocity;			///Velocity normalized between 0 and 1
		float			modWheel;			///Modulation wheel normalized between 0 and 1

		float			currShpA;			///The current attack shape
		float			currShpR;			///The current release shape
		/**
		Decodes one more block worth of samples, depending on internal state.
		*/
		void decodeMore(ref SampleAssignment sa, ref Sample slmp) @nogc nothrow pure {
			if (status & 2) currNote = 255;
			if (currNote == 255) return;
			//Save final sample in case we will need it later on during resampling.
			decoderBuffer[0] = decoderBuffer[256];
			//Determine how much samples we will need.
			int samplesNeeded = 256;
			
			//SampleAssignment sa = presetCopy.sampleMapping[currNote];
			//Sample slmp = sampleBank[sa.sampleNum];
			const bool keyOn = (status & 1) == 1;
			const bool isLooping = !(sa.loopBegin == -1 || sa.loopEnd == -1) && keyOn;
			
			//Case 1: sample is running out, and there are no looppoints.
			if (!isLooping && (decoderWorkpad.pos + samplesNeeded >= slmp.samplesLength())) {
				samplesNeeded = cast(int)(decoderWorkpad.pos + samplesNeeded - slmp.samplesLength());
				status |= 2;
				for (int i = samplesNeeded ; i <= 256 ; i++) 
					decoderBuffer[i] = 0;
			}
			while (samplesNeeded > 0) {
				//Case 2: sample might enter the beginning or the end of the loop.
				//If loop is short enough, it can happen multiple times
				const bool loopBegin = isLooping && (decoderWorkpad.pos + samplesNeeded >= sa.loopBegin) && 
						!(status & ChannelStatusFlags.inLoop);
				const bool loopEnd = isLooping && (decoderWorkpad.pos + samplesNeeded >= sa.loopEnd);
				const size_t samplesToDecode = loopBegin ? decoderWorkpad.pos + samplesNeeded - sa.loopBegin : (loopEnd ? 
						decoderWorkpad.pos + samplesNeeded - sa.loopEnd : samplesNeeded);
				slmp.decode(slmp.sampleData, decoderBuffer[1..samplesNeeded + 1], decoderWorkpad);
				if (loopBegin) {
					status |= ChannelStatusFlags.inLoop;
					savedDWState = decoderWorkpad;
				} else if (loopEnd)
					decoderWorkpad = savedDWState;
				samplesNeeded -= samplesToDecode;
			}
			
		}
	}
	alias SampleMap = TreeMap!(uint, Sample);
	alias PresetMap = TreeMap!(uint, Preset);
	protected SampleMap		sampleBank;			///Stores all current samples.
	protected PresetMap		presetBank;			///Stores all current presets. (bits: 0-6: preset number, 7-13: bank lsb, 14-20: bank msb)
	protected Channel[8]	channels;			///Channel status data.
	protected Oscillator	lfo;				///Low frequency oscillator to modify values in real-time
	protected float[]		lfoOut;				///LFO output buffer
	protected int[]			iBuf;				///Integer output buffers
	protected __m128[]		lBuf;				///Local output buffer

	public this() @safe nothrow {
		info.nOfAudioInput = 0;
		info.nOfAudioOutput = 4;
		info.outputChNames = ["mainL", "mainR", "auxSendA", "auxSendB"];
		info.isInstrument = true;
		info.hasMidiIn = true;
		info.hasMidiOut = true;
		info.midiSendback = true;
	}
	/**
	 * Sets the module up.
	 *
	 * Can be overridden in child classes to allow resets.
	 */
	public override void moduleSetup(ubyte[] inputs, ubyte[] outputs, int sampleRate, size_t bufferSize, 
			ModuleManager handler) @safe nothrow {
		enabledInputs = StreamIDSet(inputs);
		enabledOutputs = StreamIDSet(outputs);
		this.sampleRate = sampleRate;
		this.bufferSize = bufferSize;
		/+for (int i ; i < 8 ; i++) {
			channels[i].decoderBuffer.length = bufferSize * 2;
		}+/
		
		iBuf.length = bufferSize;
		lBuf.length = bufferSize;
		lfoOut.length = bufferSize;
		this.handler = handler;
	}
	/**
	 * MIDI 2.0 data received here.
	 *
	 * data0: Header of the up to 128 bit MIDI 2.0 data.
	 * data1-3: Other packets if needed.
	 */
	public override void midiReceive(UMP data0, uint data1 = 0, uint data2 = 0, uint data3 = 0) @nogc nothrow {
		switch (data0.msgType) {
			case MessageType.MIDI1:
				if (data0.channel < 8) {

				}
				break;
			case MessageType.MIDI2:
				if (data0.channel < 8) {
					switch (data0.status) {
						case MIDI2_0Cmd.NoteOn:
							break;
						case MIDI2_0Cmd.NoteOff:
							break;
						default:
							break;
					}
				}
				break;
			default:
				break;
		}
	}
	protected void keyOn(ubyte note, ubyte ch, float vel, float bend = float.nan) @nogc pure nothrow {

	}
	protected void keyOff(ubyte note, ubyte ch, float vel, float bend = float.nan) @nogc pure nothrow {

	}
	/** 
	 * Creates a decoder function.
	 * Params:
	 *   fmt = the format of the sample.
	 * Returns: The decoder function, or null if format not supported.
	 */
	protected DecodeFunc getDecoderFunction(WaveFormat fmt) @nogc pure nothrow {
		switch (fmt.format) {		//Hope this branching won't impact performance too much
			case AudioFormat.PCM:
				if (fmt.bitsPerSample == 8)
					return (ubyte[] src, int[] dest, ref Workpad wp) {decode8bitPCM(cast(const(ubyte)[])src, dest, wp);};
				else if (fmt.bitsPerSample == 16)
					return (ubyte[] src, int[] dest, ref Workpad wp) {decode16bitPCM(cast(const(short)[])src, dest, wp);};
				return null;
			case AudioFormat.ADPCM:
				return (ubyte[] src, int[] dest, ref Workpad wp) {decode4bitIMAADPCM(ADPCMStream(src, src.length/2), dest, wp);};
				
			case AudioFormat.DIALOGIC_OKI_ADPCM:
				return (ubyte[] src, int[] dest,ref Workpad wp){decode4bitDialogicADPCM(ADPCMStream(src, src.length/2), dest, wp);};
				
			case AudioFormat.MULAW:
				return (ubyte[] src, int[] dest, ref Workpad wp) {decodeMuLawStream(cast(const(ubyte)[])src, dest, wp);};
				
			case AudioFormat.ALAW:
				return (ubyte[] src, int[] dest, ref Workpad wp) {decodeALawStream(cast(const(ubyte)[])src, dest, wp);};
				
			default:
				return null;
		}
	}
	/**
	 * Renders the current audio frame.
	 * 
	 * input: the input buffers if any, null if none.
	 * output: the output buffers if any, null if none.
	 *
	 * NOTE: Buffers must have matching sizes.
	 */
	public override void renderFrame(float*[] input, float*[] output) @nogc nothrow {
		for (int i ; i < 8 ; i++) {
			if (channels[i].currNote == 255) continue;
			//get the data for the sample
			SampleAssignment sa = channels[i].presetCopy.sampleMapping[channels[i].currNote];
			Sample slmp = sampleBank[sa.sampleNum];
			if (!slmp.sampleData.length) continue;
			int samplesNeeded = cast(int)bufferSize;
			while (samplesNeeded) {
				///Calculate the amount of samples that are needed for this block
				uint samplesToAdvance = cast(uint)((channels[i].waveModWorkpad.lookupVal + (channels[i].jumpAm * samplesNeeded))
						>>24);
				const uint decoderBufPos = channels[i].outPos & 255;
				///Determine if there's enough decoded samples, if not then reduce the amount of samplesToAdvance
				if (256 - decoderBufPos <= samplesToAdvance){
					samplesToAdvance = 256 - decoderBufPos;
				}
				const uint samplesOutputted = cast(uint)(samplesToAdvance / channels[i].freqRatio);
				const int bias = channels[i].waveModWorkpad.lookupVal & 0x_FF_FF_FF ? 0 : 1;
				stretchAudioNoIterpol(channels[i].decoderBuffer[bias + decoderBufPos..$], iBuf[0..samplesOutputted], 
						channels[i].waveModWorkpad, channels[i].jumpAm);
				samplesNeeded -= samplesOutputted;
				if (samplesNeeded) channels[i].decodeMore(sa, slmp);
			}
			//apply envelop (if needed) and volume, then mix it to the local buffer
			__m128 levels;
			levels[0] = channels[i].presetCopy.masterVol - channels[i].presetCopy.balance;
			levels[1] = channels[i].presetCopy.masterVol - (1 - channels[i].presetCopy.balance);
			levels[2] = channels[i].presetCopy.auxSendA;
			levels[3] = channels[i].presetCopy.auxSendB;
			for (int j ; j < bufferSize ; j++) {
				__m128 sample = _mm_cvtepi32_ps(__m128i(iBuf[j]));
				/+const float adsrEnv = (channels[i].presetCopy.flags & PresetFlags.ADSRtoVol ? 
						channels[i].envGen.shp(channels[i].envGen.currStage == ADSREnvelopGenerator.Stage.Attack ? 
						channels[i].currShpA : channels[i].currShpR) : 
						1.0) / ushort.max;
				channels[i].envGen.advance();
				sample *= __m128(adsrEnv) * __m128(lfoOut[j]);+/
			}
		}
		//apply filtering and mix to destination
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
			sampleBank[id] = Sample(rawData, format, getDecoderFunction(format));
			return 0;
		}
	}
	/**
	 * Restores a parameter to the given preset.
	 * Returns an errorcode on failure.
	 */
	public override int recallParam_int(uint presetID, uint paramID, int value) nothrow {
		return 0;
	}
	/**
	 * Restores a parameter to the given preset.
	 * Returns an errorcode on failure.
	 */
	public override int recallParam_uint(uint presetID, uint paramID, uint value) nothrow {
		return 0;
	}
	/**
	 * Restores a parameter to the given preset.
	 * Returns an errorcode on failure.
	 */
	public override int recallParam_double(uint presetID, uint paramID, double value) nothrow {
		return 0;
	}
	/**
	 * Restores a parameter to the given preset.
	 * Returns an errorcode on failure.
	 */
	public override int recallParam_string(uint presetID, uint paramID, string value) nothrow {
		return 0;
	}
}