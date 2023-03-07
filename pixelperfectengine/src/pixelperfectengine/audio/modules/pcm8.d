module pixelperfectengine.audio.modules.pcm8;

import pixelperfectengine.audio.base.modulebase;
import pixelperfectengine.audio.base.types;
import pixelperfectengine.audio.base.envgen;
import pixelperfectengine.audio.base.func;
import pixelperfectengine.audio.base.envgen;
import pixelperfectengine.audio.base.osc;
import pixelperfectengine.system.etc : min;

import std.math;
import core.stdc.string;

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
	shared static this () {
		import std.range : iota;
		import std.conv : to;
		for (uint i ; i < 128 ; i++) {		//TODO: Make a version to leave this out, otherwise it'll just consume memory for the end user.
			SAMPLE_SET_VALS ~= MValue(MValueType.Int32, i | 0x10_00, "Sample-"~to!string(i)~"_Select");
			SAMPLE_SET_VALS ~= MValue(MValueType.Float, i | 0x11_00, "Sample-"~to!string(i)~"_SlmpFreq");
			SAMPLE_SET_VALS ~= MValue(MValueType.Int32, i | 0x12_00, "Sample-"~to!string(i)~"_LoopBegin");
			SAMPLE_SET_VALS ~= MValue(MValueType.Int32, i | 0x13_00, "Sample-"~to!string(i)~"_LoopEnd");
		}
		for (int i ; i < 128 ; i++) {
			ADSR_TIME_TABLE[i] = pow(i / 64.0, 1.8);
		}
	}
	protected static MValue[] SAMPLE_SET_VALS;
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
	alias DecodeFunc = void function(ubyte[] src, int[] dest, ref DecoderWorkpad wp) @nogc nothrow pure;
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
		float			lfoToVol = 0;	///Tremolo level (LFO to volume)
		float			adsrToVol = 0;	///ADSR to output level amount 
		float			adsrToDetune = 0;///ADSR to pitch bend amount
		float			vibrAm = 0;	///FLO to pitch bend amount

		float			pitchBendAm = 2;///Pitch bend range

		uint			flags;		///Contains various binary settings
	}
	///Defines preset setting flags.
	protected enum PresetFlags {
		cutoffOnKeyOff		=	1<<0,		///If set, the sample playback will cut off on every key off event
		modwheelToLFO		=	1<<1,		///Assigns modulation wheel to amplitude and/or pitch LFO levels
		panningLFO			=	1<<2,		///Sets amplitude LFO to panning on this channel
		/* ADSRtoVol			=	1<<3,		///If set, then envGen will control the volume */
	}
	///Defines LFO setting flags.
	protected enum LFOFlags {
		saw					=	1<<0,
		triangle			=	1<<1,
		pulse				=	1<<2,
		sawpulse			=	1<<3,
		invert				=	1<<4,
		ringmod				=	1<<5
	}
	///Defines channel statuses.
	protected enum ChannelStatusFlags {
		noteOn				=	1<<0,	///Set if key is on
		sampleRunout		=	1<<1,	///Set if sample have ran out (decoder proceeds to stop)
		inLoop				=	1<<2,	///Set if sample is looping
	}
	/**
	Defines a single channel's statuses.
	*/
	protected struct Channel {
		//int[256]		decoderBuffer;
		int[256]		decoderBuffer;		///Stores decoded samples.
		Preset			presetCopy;			///The copy of the preset.
		DecoderWorkpad	decoderWorkpad;		///Stores the current state of the decoder.
		DecoderWorkpad	savedDWState;		///The state of the decoder when the beginning of the looppoint has been reached.
		WavemodWorkpad	waveModWorkpad;		///Stores the current state of the wave modulator.
		double			freqRatio;			///Sampling-to-playback frequency ratio, with pitch bend, LFO, and envGen applied.
		long			outPos;				///Position in decoded amount, including fractions
		uint			decodeAm;			///Decoded amount, mainly used to determine output buffer half
		uint 			jumpAm;				///Jump amount for current sample, calculated from freqRatio.
		//WavemodWorkpad	savedWMWState;		///The state of the wave modulator when the beginning of the looppoint has been reached.
		ADSREnvelopGenerator	envGen;		///Channel envelop generator.

		ubyte			currNote = 255;		///The currently played note + Bit 8 indicates suspension.
		ubyte			presetNum;			///Selected preset.
		ushort			bankNum;			///Bank select number.
		uint			status;				///Channel status flags. Bit 1: Note on, Bit 2: Sample run out approaching, Bit 3: In loop

		float			pitchBend = 0;		///Current amount of pitch bend.

		float			velocity;			///Velocity normalized between 0 and 1
		float			modWheel;			///Modulation wheel normalized between 0 and 1

		float			currShpA;			///The current attack shape
		float			currShpR;			///The current release shape
		/**
		Decodes one more block worth of samples, depending on internal state.

		Bugs: 
		* Upon pitchbend and when looping, it can cause buffer alignment issues, which in turn will cause audio glitches.
		*/
		void decodeMore(ref SampleAssignment sa, ref Sample slmp) @nogc nothrow pure {
			if (status & ChannelStatusFlags.sampleRunout) {
				currNote = 255;
			}
			if (currNote == 255) {
				return;
			}
			//Determine how much samples we will need.
			sizediff_t samplesNeeded = 128;
			//Determine offset based on which cycle we will need
			const size_t offset = decodeAm & 0x01 ? 128 : 0;
			
			const bool keyOn = (status & 1) == 1;
			const bool isLooping = (sa.loopBegin != -1 && sa.loopEnd != -1) && ((sa.loopEnd - sa.loopBegin) > 0) && keyOn;
			
			//Case 1: sample is running out, and there are no looppoints.
			if (!isLooping && (decoderWorkpad.pos + samplesNeeded >= slmp.samplesLength())) {
				samplesNeeded -= decoderWorkpad.pos + samplesNeeded - slmp.samplesLength();
				status |= ChannelStatusFlags.sampleRunout;
				for (size_t i = samplesNeeded ; i < 128 ; i++) 
					decoderBuffer[offset + i] = 0;
			}
			size_t dPos = offset;	//Decoder position
			while (samplesNeeded > 0) {
				//Case 2: sample might enter the beginning or the end of the loop.
				//If loop is short enough, it can happen multiple times
				const bool loopBegin = isLooping && (decoderWorkpad.pos + samplesNeeded >= sa.loopBegin) && 
						!(status & ChannelStatusFlags.inLoop);
				const bool loopEnd = isLooping && (decoderWorkpad.pos + samplesNeeded >= sa.loopEnd);
				/* const size_t samplesToDecode = loopBegin ? decoderWorkpad.pos + samplesNeeded - sa.loopBegin : (loopEnd ? 
						decoderWorkpad.pos + samplesNeeded - sa.loopEnd : samplesNeeded); */
				const size_t samplesToDecode = loopBegin ? samplesNeeded - (sa.loopBegin - decoderWorkpad.pos) : (loopEnd ? 
						samplesNeeded - (sa.loopEnd - decoderWorkpad.pos) : samplesNeeded);
				slmp.decode(slmp.sampleData, decoderBuffer[dPos..dPos + samplesToDecode], decoderWorkpad);
				if (loopBegin) {
					status |= ChannelStatusFlags.inLoop;
					savedDWState = decoderWorkpad;
				} else if (loopEnd) {
					decoderWorkpad = savedDWState;
					outPos = savedDWState.pos<<24;	//this is the only way the looping can somewhat working, using decodeAm instead of decoderWorkpad.pos is buggy for some weird reason
					//waveModWorkpad.lookupVal &= 0xFFFF_FFFF_FF00_0000;
				}
				samplesNeeded -= samplesToDecode;
				dPos += samplesToDecode;
				//decodeAm += samplesToDecode;
				//outPos += samplesToAdvance;
			}
			decodeAm++;
		}
		///Calculates jump amount for the sample.
		void calculateJumpAm(int sampleRate) @nogc @safe pure nothrow {
			freqRatio = sampleRate / bendFreq(presetCopy.sampleMapping[currNote & 127].baseFreq, pitchBend);
			jumpAm = cast(uint)((1<<24) / freqRatio);
		}
		///Resets all internal states.
		void reset() @nogc @safe pure nothrow {
			outPos = 0;
			status = 0;
			decodeAm = 0;
			decoderWorkpad = DecoderWorkpad.init;
			savedDWState = DecoderWorkpad.init;
			waveModWorkpad = WavemodWorkpad.init;
		}
		///Recalculates shape params.
		void setShpVals(float vel = 1.0) @nogc @safe pure nothrow {
			currShpA = presetCopy.eAtkShp - (presetCopy.velToAtkShp * presetCopy.eAtkShp) + 
					(presetCopy.velToAtkShp * presetCopy.eAtkShp * vel);
			currShpR = presetCopy.eRelShp - (presetCopy.velToRelShp * presetCopy.eRelShp) + 
					(presetCopy.velToRelShp * presetCopy.eRelShp * vel);
		}
	}
	alias SampleMap = TreeMap!(uint, Sample);
	alias PresetMap = TreeMap!(uint, Preset);
	protected SampleMap		sampleBank;			///Stores all current samples.
	protected PresetMap		presetBank;			///Stores all current presets. (bits: 0-6: preset number, 7-13: bank lsb, 14-20: bank msb)
	protected Channel[8]	channels;			///Channel status data.
	protected MultiTapOsc	lfo;				///Low frequency oscillator to modify values in real-time
	protected float[]		lfoOut;				///LFO output buffer
	protected uint			lfoFlags;			///LFO state flags
	protected float			lfoFreq;			///LFO frequency
	protected float			lfoPWM;				///LFO pulse width modulation
	protected float[]		dummyBuf;			///Dummy buffer if one or more output aren't used
	protected int[]			iBuf;				///Integer output buffers
	protected __m128[]		lBuf;				///Local output buffer
	///Stores output filter values.
	///0: a0; 1: a1; 2: a2; 3: b0; 4: b1; 5: b2; 6: x[n-1]; 7: x[n-2]; 8: y[n-1] 9: y[n-2]
	protected __m128[10]		filterVals;
	///Stores control values of the output values.
	///Layout: [LF, LQ, RF, RQ, AF, AQ, BF, BQ]
	protected float[8]			filterCtrl	=	[16_000, 0.707, 16_000, 0.707, 16_000, 0.707, 16_000, 0.707];
	protected float				mixdownVal = short.max + 1;
	protected ubyte[32]			sysExBuf;		///SysEx command buffer [0-30] + length [31]
	protected ubyte[68][9]		chCtrlLower;	///Lower parts of the channel controllers (0-31 / 32-63) + (Un)registered parameter select (64-65)
	public this() @safe nothrow {
		info.nOfAudioInput = 0;
		info.nOfAudioOutput = 4;
		info.outputChNames = ["mainL", "mainR", "auxSendA", "auxSendB"];
		info.isInstrument = true;
		info.hasMidiIn = true;
		info.hasMidiOut = true;
		info.midiSendback = true;
		lfo = MultiTapOsc.init;
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
		dummyBuf.length = bufferSize;
		iBuf.length = bufferSize;
		lBuf.length = bufferSize;
		lfoOut.length = bufferSize;
		this.handler = handler;
		//Reset filters
		for (int i ; i < 4 ; i++) {
			resetLPF(i);
			filterVals[6][i] = 0;
			filterVals[7][i] = 0;
			filterVals[8][i] = 0;
			filterVals[9][i] = 0;
		}
	}
	///Recalculates the low pass filter vlues for the given output channel.
	protected void resetLPF(int i) @nogc @safe pure nothrow {
		BiquadFilterValues vals = createLPF(sampleRate, filterCtrl[i * 2], filterCtrl[(i * 2) + 1]);
		filterVals[0][i] = vals.a0;
		filterVals[1][i] = vals.a1;
		filterVals[2][i] = vals.a2;
		filterVals[3][i] = vals.b0;
		filterVals[4][i] = vals.b1;
		filterVals[5][i] = vals.b2;
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
					switch (data0.status) {
						case MIDI1_0Cmd.PitchBend:
							channels[data0.channel].pitchBend = channels[data0.channel].presetCopy.pitchBendAm * 
									((cast(double)data0.bend - 0x20_00) / 0x3F_FF);
							//channels[data0.channel].calculateJumpAm(sampleRate);
							break;
						case MIDI1_0Cmd.NoteOn:
							keyOn(data0.note, data0.channel, data0.value/127.0);
							break;
						case MIDI1_0Cmd.NoteOff:
							keyOff(data0.note, data0.channel, data0.value/127.0);
							break;
						case MIDI1_0Cmd.CtrlCh:
							uint val;
							if (data0.note < 64) {
								chCtrlLower[data0.channel][data0.note] = data0.value;
								val = convertM1CtrlValToM2(chCtrlLower[data0.channel][data0.note & 0x1F], 
										chCtrlLower[data0.channel][data0.note | 0x20]);
							} else if (data0.note >= 70 && data0.note <= 73) {
								val = data0.value<<25;
							} else {
								val = convertM1CtrlValToM2(data0.value, data0.value);
							}
							if (data0.note == 0 || data0.note == 32)
								channels[data0.channel].bankNum = (chCtrlLower[data0.channel][0]<<7) | chCtrlLower[data0.channel][32];
							else
								ctrlCh (data0.channel, data0.note, val);
							break;
						case MIDI1_0Cmd.PrgCh:
							channels[data0.channel].presetCopy = presetBank[(channels[data0.channel].bankNum<<7) | data0.note];
							channels[data0.channel].presetNum = data0.note;
							break;
						default:
							break;
					}
				}
				break;
			case MessageType.MIDI2:
				if (data0.channel < 8) {
					switch (data0.status) {
						case MIDI2_0Cmd.PitchBend:
							channels[data0.channel].pitchBend = channels[data0.channel].presetCopy.pitchBendAm * 
									((cast(double)data1 - int.max) / (int.max));
							//channels[data0.channel].calculateJumpAm(sampleRate);
							break;
						case MIDI2_0Cmd.NoteOn:
							NoteVals nv = *cast(NoteVals*)&data1;
							keyOn(data0.note, data0.channel, nv.velocity / ushort.max);
							break;
						case MIDI2_0Cmd.NoteOff:
							NoteVals nv = *cast(NoteVals*)&data1;
							keyOff(data0.note, data0.channel, nv.velocity / ushort.max);
							break;
						case MIDI2_0Cmd.CtrlChOld, MIDI2_0Cmd.CtrlCh:
							ctrlCh(data0.channel, data0.note, data1);
							break;
						case MIDI2_0Cmd.PrgCh:
							channels[data0.channel].bankNum = data1 & ushort.max;
							channels[data0.channel].presetNum = data1>>24;
							presetRecall(data0.channel);
							break;
						default:
							break;
					}
				}
				break;
			case MessageType.Data64:
				if (data0.status == SysExSt.Start || data0.status == SysExSt.Complete)
					sysExBuf[31] = 0;
				ubyte[4] packet1 = [cast(ubyte)(data1>>24), cast(ubyte)(data1>>16), cast(ubyte)(data1>>8), cast(ubyte)data1];
				int length = data0.channel;
				for (int i ; i < 2 && length - 4 > 0 ; i++, length--) {
					sysExBuf[sysExBuf[31]] = data0.bytes[i];
					sysExBuf[31]++;
					if (sysExBuf[31] > 30) {
						length = 0;
						sysExBuf[31] = 0;
					}
				}
				for (int i ; i < 4 && length > 0 ; i++, length--) {
					sysExBuf[sysExBuf[31]] = packet1[i];
					sysExBuf[31]++;
					if (sysExBuf[31] > 30) {
						length = 0;
						sysExBuf[31] = 0;
					}
				}
				if (data0.status == SysExSt.Complete || data0.status == SysExSt.End)
					sysExCmd(sysExBuf[0..sysExBuf[31]]);
				break;
			case MessageType.Data128:
				if (data0.status == SysExSt.Start || data0.status == SysExSt.Complete)
					sysExBuf[31] = 0;
				ubyte[13] data = [data0.value, 
						cast(ubyte)(data1>>24), cast(ubyte)(data1>>16), cast(ubyte)(data1>>8), cast(ubyte)data1,
						cast(ubyte)(data2>>24), cast(ubyte)(data2>>16), cast(ubyte)(data2>>8), cast(ubyte)data2,
						cast(ubyte)(data3>>24), cast(ubyte)(data3>>16), cast(ubyte)(data3>>8), cast(ubyte)data3];
				for (int i ; i < data0.channel ; i++, sysExBuf[31]++) {
					sysExBuf[sysExBuf[31]] = data[i];
					if (sysExBuf[31] > 30)
						sysExBuf[31] = 0;
				}
				if (data0.status == SysExSt.Complete || data0.status == SysExSt.End)
					sysExCmd(sysExBuf[0..sysExBuf[31]]);
				break;
			default:
				break;
		}
	}
	protected void keyOn(ubyte note, ubyte ch, float vel) @nogc pure nothrow {
		channels[ch].currNote = note;
		channels[ch].velocity = vel;
		channels[ch].calculateJumpAm(sampleRate);
		channels[ch].setShpVals(vel);
		//reset all on channel
		channels[ch].reset();
		//set noteOn status flag
		channels[ch].status |= ChannelStatusFlags.noteOn;
	}
	protected void keyOff(ubyte note, ubyte ch, float vel) @nogc pure nothrow {
		if (!(channels[ch].currNote & 128))
			channels[ch].currNote = note;
		channels[ch].velocity = vel;
		channels[ch].calculateJumpAm(sampleRate);
		channels[ch].setShpVals(vel);
		channels[ch].status &= ~ChannelStatusFlags.noteOn;
	}
	protected void ctrlCh(ubyte ch, ubyte param, uint val) @nogc pure nothrow {
		if (param >= 32 && param < 64) param &= 0x1F;
		if (ch <= 7) {	//Channel locals
			switch (param) {
				case 7:
					channels[ch].presetCopy.masterVol = (1.0 / uint.max) * val;
					break;
				case 8:
					channels[ch].presetCopy.balance = (1.0 / uint.max) * val;
					break;
				case 91:
					channels[ch].presetCopy.auxSendA = (1.0 / uint.max) * val;
					break;
				case 92:
					channels[ch].presetCopy.auxSendB = (1.0 / uint.max) * val;
					break;
				case 73:
					channels[ch].presetCopy.eAtk = cast(ubyte)(val>>25);
					break;
				case 14:
					channels[ch].presetCopy.eAtkShp = (1.0 / uint.max) * val;
					break;
				case 70:
					channels[ch].presetCopy.eDec = cast(ubyte)(val>>25);
					break;
				case 71:
					channels[ch].presetCopy.eSusC = cast(ubyte)(val>>25);
					break;
				case 9:
					channels[ch].presetCopy.eSusLev = (1.0 / uint.max) * val;
					break;
				case 72:
					channels[ch].presetCopy.eRel = cast(ubyte)(val>>25);
					break;
				case 15:
					channels[ch].presetCopy.eRelShp = (1.0 / uint.max) * val;
					break;
				case 20:
					channels[ch].presetCopy.velToLevelAm = (1.0 / uint.max) * val;
					break;
				case 21:
					channels[ch].presetCopy.velToAuxSendAm = (1.0 / uint.max) * val;
					break;
				case 22:
					channels[ch].presetCopy.velToAtkShp = (1.0 / uint.max) * val;
					break;
				case 23:
					channels[ch].presetCopy.velToRelShp = (1.0 / uint.max) * val;
					break;
				case 24:
					channels[ch].presetCopy.lfoToVol = (1.0 / uint.max) * val;
					break;
				case 25:
					channels[ch].presetCopy.adsrToVol = (1.0 / uint.max) * val;
					break;
				case 26:
					channels[ch].presetCopy.adsrToDetune = (1.0 / uint.max) * val * 24;
					break;
				case 27:
					channels[ch].presetCopy.vibrAm = (1.0 / uint.max) * val * 12;
					break;
				case 102:
					if (val)
						channels[ch].presetCopy.flags |= PresetFlags.cutoffOnKeyOff;
					else
						channels[ch].presetCopy.flags &= ~PresetFlags.cutoffOnKeyOff;
					break;
				case 103:
					if (val)
						channels[ch].presetCopy.flags |= PresetFlags.modwheelToLFO;
					else
						channels[ch].presetCopy.flags &= ~PresetFlags.modwheelToLFO;
					break;
				case 104:
					if (val)
						channels[ch].presetCopy.flags |= PresetFlags.panningLFO;
					else
						channels[ch].presetCopy.flags &= ~PresetFlags.panningLFO;
					break;
				default:
					break;
			}
		} else if (ch == 8) {	//Module globals
			switch (param) {
				case 2:
					filterCtrl[0] = (1.0 / uint.max) * val * 16_000;
					resetLPF(0);
					break;
				case 3:
					filterCtrl[1] = (1.0 / uint.max) * val * 40;
					resetLPF(0);
					break;
				case 4:
					filterCtrl[2] = (1.0 / uint.max) * val * 16_000;
					resetLPF(1);
					break;
				case 5:
					filterCtrl[3] = (1.0 / uint.max) * val * 40;
					resetLPF(1);
					break;
				case 6:
					filterCtrl[4] = (1.0 / uint.max) * val * 16_000;
					resetLPF(2);
					break;
				case 7:
					filterCtrl[5] = (1.0 / uint.max) * val * 40;
					resetLPF(2);
					break;
				case 8:
					filterCtrl[6] = (1.0 / uint.max) * val * 16_000;
					resetLPF(3);
					break;
				case 9:
					filterCtrl[7] = (1.0 / uint.max) * val * 40;
					resetLPF(3);
					break;
				case 10:
					if (lfoFlags & LFOFlags.ringmod)
						lfoFreq = noteToFreq((1.0 / uint.max) * val * 127);
					else
						lfoFreq = (1.0 / uint.max) * val * 20;
					resetLFO();
					break;
				case 11:
					lfoPWM = (1.0 / uint.max) * val;
					resetLFO();
					break;
				case 102:
					if (val)
						lfoFlags |= LFOFlags.saw;
					else
						lfoFlags &= ~LFOFlags.saw;
					resetLFO();
					break;
				case 103:
					if (val)
						lfoFlags |= LFOFlags.triangle;
					else
						lfoFlags &= ~LFOFlags.triangle;
					resetLFO();
					break;
				case 104:
					if (val)
						lfoFlags |= LFOFlags.pulse;
					else
						lfoFlags &= ~LFOFlags.pulse;
					resetLFO();
					break;
				case 105:
					if (val)
						lfoFlags |= LFOFlags.sawpulse;
					else
						lfoFlags &= ~LFOFlags.sawpulse;
					resetLFO();
					break;
				case 106:
					if (val)
						lfoFlags |= LFOFlags.invert;
					else
						lfoFlags &= ~LFOFlags.invert;
					resetLFO();
					break;
				case 107:
					if (val)
						lfoFlags |= LFOFlags.ringmod;
					else
						lfoFlags &= ~LFOFlags.ringmod;
					resetLFO();
					break;
				default:
					break;
			}
		}
	}
	protected void sysExCmd(ubyte[] msg) @nogc nothrow {
		//Check manufacturer ID (7D: internal use)
		if (msg[0] == 0x7D || msg[1] == 0x7D) {
			const int msgPos = msg[0] ? 1 : 2;
			switch (msg[msgPos]) {
				case 0x01:	//Suspend channel
					if (msg[msgPos + 1] >= 8) return;
					if (!(channels[msg[msgPos + 1]].status & ChannelStatusFlags.sampleRunout)) {
						channels[msg[msgPos + 1]].currNote |= 0x80;
					}
					break;
				case 0x02:	//Resume channel
					if (msg[msgPos + 1] >= 8) return;
					if (!(channels[msg[msgPos + 1]].status & ChannelStatusFlags.sampleRunout)) {
						channels[msg[msgPos + 1]].currNote &= 0x7F;
					}
					break;
				case 0x03:	//Overwrite preset
					if (msg[msgPos + 1] >= 8) return;
					if (msg.length == msgPos + 5) {
						channels[msg[msgPos + 1]].presetNum = msg[msgPos + 2];
						channels[msg[msgPos + 1]].bankNum = (msg[msgPos + 3]>>1) | msg[msgPos + 4];
					}
					*(presetBank.ptrOf((channels[msg[msgPos + 1]].bankNum<<7) | channels[msg[msgPos + 1]].presetNum)) = 
							channels[msg[msgPos + 1]].presetCopy;
					break;
				case 0x20:	//Jump to sample position by restoring codec data
					if (msg[msgPos + 1] >= 8) return;
					channels[msg[msgPos + 1]].decoderWorkpad.pos = (msg[msgPos + 2] << 21) | (msg[msgPos + 3] << 14) | 
						(msg[msgPos + 4] << 7) | msg[msgPos + 5];
					channels[msg[msgPos + 1]].waveModWorkpad.lookupVal = 0;
					if (msg.length == msgPos + 10) {
						channels[msg[msgPos + 1]].decoderWorkpad.pred = msg[msgPos + 6];
						channels[msg[msgPos + 1]].decoderWorkpad.outn1 = (msg[msgPos + 7]<<30) | (msg[msgPos + 8]<<23) | 
								(msg[msgPos + 9]<<16);
						channels[msg[msgPos + 1]].decoderWorkpad.outn1>>=16;
					}
					//decode the sample
					if (channels[msg[msgPos + 1]].currNote & 128) return;
					//get the data for the sample
					SampleAssignment sa = channels[msg[msgPos + 1]].presetCopy.sampleMapping[channels[msg[msgPos + 1]].currNote];
					Sample slmp = sampleBank[sa.sampleNum];
					channels[msg[msgPos + 1]].decodeMore(sa, slmp);
					break;
				case 0x21:	//Dump codec data
					if (msg[msgPos + 1] >= 8) return;
					uint[2] dump;
					const int delta = channels[msg[msgPos + 1]].decoderWorkpad.outn1;
					dump[0] = cast(uint)channels[msg[msgPos + 1]].decoderWorkpad.pos;
					dump[0] = ((dump[0] & 0xF_E0_00_00)<<3) | ((dump[0] & 0x1F_C0_00)<<2) | ((dump[0] & 0x3F_80)<<1) | (dump[0] & 0x7F);
					dump[1] = channels[msg[msgPos + 1]].decoderWorkpad.pred<<24;
					dump[1] |= ((delta & 0xC0_00)<<2) | ((delta & 0x3F_80)<<1) | (delta & 0x7F);
					if (midiOut !is null) midiOut(UMP(MessageType.Data128, 0x0, SysExSt.Complete, 9, 0x0, 0x7D), dump[0], 
							dump[1]);
					break;
				case 0xA0:	//Jump to sample position by restoring codec data (8bit)
					if (msg[msgPos + 1] >= 8) return;
					channels[msg[msgPos + 1]].decoderWorkpad.pos = (msg[msgPos + 2] << 24) | (msg[msgPos + 3] << 16) | 
						(msg[msgPos + 4] << 8) | msg[msgPos + 5];
					channels[msg[msgPos + 1]].waveModWorkpad.lookupVal = 0;
					if (msg.length == msgPos + 9) {
						channels[msg[msgPos + 1]].decoderWorkpad.pred = msg[msgPos + 6];
						channels[msg[msgPos + 1]].decoderWorkpad.outn1 = (msg[msgPos + 7]<<24) | (msg[msgPos + 8]<<16);
						channels[msg[msgPos + 1]].decoderWorkpad.outn1>>=16;
					}
					//decode the sample
					if (channels[msg[msgPos + 1]].currNote & 128) return;
					//get the data for the sample
					SampleAssignment sa = channels[msg[msgPos + 1]].presetCopy.sampleMapping[channels[msg[msgPos + 1]].currNote];
					Sample slmp = sampleBank[sa.sampleNum];
					channels[msg[msgPos + 1]].decodeMore(sa, slmp);
					break;
				case 0xA1:	//Dump codec data (8bit)
					if (msg[msgPos + 1] >= 8) return;
					uint[2] dump;
					dump[0] = cast(uint)channels[msg[msgPos + 1]].decoderWorkpad.pos;
					dump[1] = channels[msg[msgPos + 1]].decoderWorkpad.pred<<24;
					dump[1] |= (channels[msg[msgPos + 1]].decoderWorkpad.outn1 & ushort.max)<<8;
					if (midiOut !is null) midiOut(UMP(MessageType.Data128, 0x0, SysExSt.Complete, 8, 0x0, 0x7D), dump[0], 
							dump[1]);
					break;
				default:
					break;
			}
		}
	}
	protected void resetLFO() @nogc @safe pure nothrow {
		const int divident = ((lfoFlags>>3) & 1) + ((lfoFlags>>2) & 1) + ((lfoFlags>>1) & 1) + (lfoFlags & 1);
		const short value = cast(short)(short.max / divident * (lfoFlags & LFOFlags.invert ? -1 : 1));
		if (lfoFlags & LFOFlags.pulse)
			lfo.pulseAm = value;
		if (lfoFlags & LFOFlags.saw)
			lfo.sawAm = value;
		if (lfoFlags & LFOFlags.sawpulse)
			lfo.sawPulseAm = value;
		if (lfoFlags & LFOFlags.triangle)
			lfo.triAm = value;
		lfo.pulseWidth = cast(uint)(lfoPWM * uint.max);
		lfo.setRate(sampleRate, lfoFreq);
	}
	protected void presetRecall(ubyte ch) @nogc pure nothrow {
		channels[ch].presetCopy = presetBank[channels[ch].presetNum | (channels[ch].bankNum<<7)];
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
					return (ubyte[] src, int[] dest, ref DecoderWorkpad wp) {decode8bitPCM(cast(const(ubyte)[])src, dest, wp);};
				else if (fmt.bitsPerSample == 16)
					return (ubyte[] src, int[] dest, ref DecoderWorkpad wp) {decode16bitPCM(cast(const(short)[])src, dest, wp);};
				return null;
			case AudioFormat.ADPCM:
				return (ubyte[] src, int[] dest, ref DecoderWorkpad wp) 
						{decode4bitIMAADPCM(ADPCMStream(src, src.length*2), dest, wp);};
				
			case AudioFormat.DIALOGIC_OKI_ADPCM:
				return (ubyte[] src, int[] dest, ref DecoderWorkpad wp) 
						{decode4bitDialogicADPCM(ADPCMStream(src, src.length*2), dest, wp);};
				
			case AudioFormat.MULAW:
				return (ubyte[] src, int[] dest, ref DecoderWorkpad wp) {decodeMuLawStream(cast(const(ubyte)[])src, dest, wp);};
				
			case AudioFormat.ALAW:
				return (ubyte[] src, int[] dest, ref DecoderWorkpad wp) {decodeALawStream(cast(const(ubyte)[])src, dest, wp);};
				
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
		for (int i ; i < bufferSize ; i++) {
			lfoOut[i] = lfo.outputF(0.5, 1.0 / ushort.max);
		}
		for (int i ; i < 8 ; i++) {
			if (!(channels[i].currNote & 128) && channels[i].jumpAm) {
				channels[i].calculateJumpAm(sampleRate);
				//get the data for the sample
				SampleAssignment sa = channels[i].presetCopy.sampleMapping[channels[i].currNote];	//get sample assignment data
				Sample slmp = sampleBank[sa.sampleNum];		//get sample
				if (!slmp.sampleData.length) continue;		//break if no sample found
				size_t samplesNeeded = bufferSize;			//determine the amount of needed samples for this frame, initially it's equals with the frame buffer size
				size_t outpos;								//position in output buffer
				while (samplesNeeded && !(channels[i].currNote & 128)) {
					//Calculate the amount of samples that are needed for this block
					ulong samplesToAdvance = channels[i].jumpAm * samplesNeeded;
					//Determine if there's enough decoded samples in the output buffer.
					//If not, decode more.
					if ((channels[i].outPos + samplesToAdvance) > (channels[i].decoderWorkpad.pos<<24))
						channels[i].decodeMore(sa, slmp);
					const ulong decoderBufPos = (channels[i].decoderWorkpad.pos<<24L) - channels[i].outPos;		//Get the amount of unused samples in the decoder buffer with fractions
					//Determine if there's enough decoded samples, if not then reduce the amount of samplesToAdvance
					if ((128<<24L) - decoderBufPos <= samplesToAdvance){
						samplesToAdvance = (128<<24L) - decoderBufPos;
					}
					//Calculate how many samples will be outputted
					const size_t samplesOutputted = 
							cast(size_t)(samplesToAdvance / channels[i].jumpAm);
					stretchAudioNoIterpol(channels[i].decoderBuffer, iBuf[outpos..outpos + samplesOutputted], 
							channels[i].waveModWorkpad, channels[i].jumpAm);		//Output the audio to the intermediary buffer
					samplesNeeded -= samplesOutputted;		//substract the number of outputted samples from the needed samples
					channels[i].outPos += samplesToAdvance;	//add the samples needed to advance to the output position
					outpos += samplesOutputted;				//shift the output position by the amount of the outputted samples
				}
				//apply envelop (if needed) and volume, then mix it to the local buffer
				__m128 levels;
				levels[0] = channels[i].presetCopy.masterVol * channels[i].presetCopy.balance;
				levels[1] = channels[i].presetCopy.masterVol * (1 - channels[i].presetCopy.balance);
				levels[2] = channels[i].presetCopy.auxSendA;
				levels[3] = channels[i].presetCopy.auxSendB;
				for (int j ; j < bufferSize ; j++) {
					__m128 sample = _mm_cvtepi32_ps(__m128i(iBuf[j]));
					const float adsrEnv = channels[i].envGen.shp(channels[i].envGen.position == ADSREnvelopGenerator.Stage.Attack ? 
							channels[i].currShpA : channels[i].currShpR) * channels[i].presetCopy.adsrToVol;
					channels[i].envGen.advance();
					sample *= __m128((1 - channels[i].presetCopy.adsrToVol) + adsrEnv) * __m128((1 - channels[i].presetCopy.lfoToVol) + 
							(lfoOut[j] * channels[i].presetCopy.lfoToVol)) * levels;
					lBuf[j] += sample;
				}
				resetBuffer(iBuf);
			}
		}
		float*[4] outBuf;
		for (ubyte i, j ; i < 4 ; i++) {
			if (enabledOutputs.has(i)) {
				outBuf[i] = output[j];
				j++;
			} else {
				outBuf[i] = dummyBuf.ptr;
			}
		}
		//apply filtering and mix to destination
		const __m128 b0_a0 = filterVals[3] / filterVals[0], b1_a0 = filterVals[4] / filterVals[0], 
				b2_a0 = filterVals[5] / filterVals[0], a1_a0 = filterVals[1] / filterVals[0], a2_a0 = filterVals[2] / filterVals[0];
		for (int i ; i < bufferSize ; i++) {
			__m128 input0 = lBuf[i];
			input0 /= __m128(mixdownVal);
			input0 = _mm_max_ps(input0, __m128(-1.0));
			input0 = _mm_min_ps(input0, __m128(1.0));
			__m128 output0 = b0_a0 * input0 + b1_a0 * filterVals[6] + b2_a0 * filterVals[7] - a1_a0 * filterVals[8] - 
					a2_a0 * filterVals[9];
			for (int j ; j < 4 ; j++)
				outBuf[j][i] += output0[j];
			//	outBuf[j][i] += input0[j];
			filterVals[7] = filterVals[6];
			filterVals[6] = input0;
			filterVals[9] = filterVals[8];
			filterVals[8] = output0;
		}
		resetBuffer(lBuf);
	}
	/**
	 * Receives waveform data that has been loaded from disk for reading. Returns zero if successful, or a specific 
	 * errorcode.
	 *
	 * id: The ID of the waveform.
	 * rawData: The data itself, in unprocessed form.
	 * format: The format of the wave data, including the data type, bit depth, base sampling rate
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
	public override int writeParam_int(uint presetID, uint paramID, int value) nothrow {
		Preset* presetPtr = presetBank.ptrOf(presetID);
		if (presetPtr is null) {
			presetBank[presetID] = Preset.init;
			presetPtr = presetBank.ptrOf(presetID);
		}
		if (paramID & 0x10_00) {
			switch (paramID & 0x0F_00) {
				case 0x00_00:
					presetPtr.sampleMapping[paramID & 0x7F].sampleNum = value;
					return 0;
				case 0x02_00:
					presetPtr.sampleMapping[paramID & 0x7F].loopBegin = value;
					return 0;
				case 0x03_00:
					presetPtr.sampleMapping[paramID & 0x7F].loopEnd = value;
					return 0;
				default:
					break;
			}
		} else if (paramID & 0x80_00) {
			switch (paramID) {
				case 0x80_09:
					if (value)
						lfoFlags |= LFOFlags.saw;
					else
						lfoFlags &= ~LFOFlags.saw;
					resetLFO();
					return 0;
				case 0x80_0a:
					if (value)
						lfoFlags |= LFOFlags.triangle;
					else
						lfoFlags &= ~LFOFlags.triangle;
					resetLFO();
					return 0;
				case 0x80_0b:
					if (value)
						lfoFlags |= LFOFlags.pulse;
					else
						lfoFlags &= ~LFOFlags.pulse;
					resetLFO();
					return 0;
				case 0x80_0c:
					if (value)
						lfoFlags |= LFOFlags.sawpulse;
					else
						lfoFlags &= ~LFOFlags.sawpulse;
					resetLFO();
					return 0;
				case 0x80_0d:
					if (value)
						lfoFlags |= LFOFlags.invert;
					else
						lfoFlags &= ~LFOFlags.invert;
					resetLFO();
					return 0;
				case 0x80_0f:
					if (value)
						lfoFlags |= LFOFlags.ringmod;
					else
						lfoFlags &= ~LFOFlags.ringmod;
					resetLFO();
					return 0;
				default:
					break;
			}
		} else {
			switch (paramID) {
				case 0x00:
					presetPtr.eAtk = cast(ubyte)value;
					return 0;
				case 0x01:
					presetPtr.eDec = cast(ubyte)value;
					return 0;
				case 0x02:
					presetPtr.eSusC = cast(ubyte)value;
					return 0;
				case 0x03:
					presetPtr.eRel = cast(ubyte)value;
					return 0;
				case 0x10:
					presetPtr.flags = value;
					return 0;
				case 0x00_11:
					if (value)
						presetPtr.flags |= PresetFlags.cutoffOnKeyOff;
					else
						presetPtr.flags &= ~PresetFlags.cutoffOnKeyOff;
					return 0;
				case 0x00_12:
					if (value)
						presetPtr.flags |= PresetFlags.modwheelToLFO;
					else
						presetPtr.flags &= ~PresetFlags.modwheelToLFO;
					return 0;
				case 0x00_13:
					if (value)
						presetPtr.flags |= PresetFlags.panningLFO;
					else
						presetPtr.flags &= ~PresetFlags.panningLFO;
					return 0;
				/* case 0x00_14:
					if (value)
						presetPtr.flags |= PresetFlags.ADSRtoVol;
					else
						presetPtr.flags &= ~PresetFlags.ADSRtoVol;
					return 0; */
				default:
					break;
			}
		}
		return 1;
	}
	/**
	 * Restores a parameter to the given preset.
	 * Returns an errorcode on failure.
	 */
	public override int writeParam_long(uint presetID, uint paramID, long value) nothrow {
		return 0;
	}
	/**
	 * Restores a parameter to the given preset.
	 * Returns an errorcode on failure.
	 */
	public override int writeParam_double(uint presetID, uint paramID, double value) nothrow {
		Preset* presetPtr = presetBank.ptrOf(presetID);
		if (presetPtr is null) {
			presetBank[presetID] = Preset.init;
			presetPtr = presetBank.ptrOf(presetID);
		}
		if (paramID & 0x10_00) {
			switch (paramID & 0x0F_00) {
				case 0x01_00:
					presetPtr.sampleMapping[paramID & 0x7F].baseFreq = value;
					return 0;
				default:
					break;
			}
		} else if (paramID & 0x80_00) {
			switch (paramID) {
				case 0x80_00: 
					filterCtrl[0] = value; 
					resetLPF(0); 
					return 0;
				case 0x80_01: 
					filterCtrl[1] = value; 
					resetLPF(0); 
					return 0;
				case 0x80_02: 
					filterCtrl[2] = value; 
					resetLPF(1); 
					return 0;
				case 0x80_03: 
					filterCtrl[3] = value; 
					resetLPF(1); 
					return 0;
				case 0x80_04: 
					filterCtrl[4] = value; 
					resetLPF(2); 
					return 0;
				case 0x80_05: 
					filterCtrl[5] = value; 
					resetLPF(2); 
					return 0;
				case 0x80_06: 
					filterCtrl[6] = value; 
					resetLPF(3); 
					return 0;
				case 0x80_07: 
					filterCtrl[7] = value; 
					resetLPF(3); 
					return 0;
				case 0x80_08: 
					lfoFreq = value;
					resetLFO();
					return 0;
				case 0x80_0e: 
					lfoPWM = value;
					resetLFO();
					return 0;
				default:
					break;
			}
		} else {
			
			if (value < 0 || value > 1) return 2;
			switch (paramID) {
				case 0x00_04:
					presetPtr.eAtkShp = value;
					return 0;
				case 0x00_05:
					presetPtr.eRelShp = value;
					return 0;
				case 0x00_06:
					presetPtr.eSusLev = value;
					return 0;
				case 0x00_07:
					presetPtr.masterVol = value;
					return 0;
				case 0x00_08:
					presetPtr.balance = value;
					return 0;
				case 0x00_09:
					presetPtr.auxSendA = value;
					return 0;
				case 0x00_0A:
					presetPtr.auxSendB = value;
					return 0;
				case 0x00_0B:
					presetPtr.velToLevelAm = value;
					return 0;
				case 0x00_0C:
					presetPtr.velToAuxSendAm = value;
					return 0;
				case 0x00_0D:
					presetPtr.velToAtkShp = value;
					return 0;
				case 0x00_0E:
					presetPtr.velToRelShp = value;
					return 0;
				case 0x00_0F:
					presetPtr.adsrToVol = value;
					return 0;
				case 0x00_20:
					presetPtr.pitchBendAm = value;
					return 0;
				default:
					break;
			}
		}
		return 1;
	}
	/**
	 * Restores a parameter to the given preset.
	 * Returns an errorcode on failure.
	 */
	public override int writeParam_string(uint presetID, uint paramID, string value) nothrow {
		return 0;
	}
	/** 
	 * Returns all the possible parameters this module has.
	 */
	public override MValue[] getParameters() nothrow {
		return [
			MValue(MValueType.Int32, 0x00_00, "envGenAtk"), MValue(MValueType.Int32, 0x00_01, "envGenDec"),
			MValue(MValueType.Int32, 0x00_02, "envGenSusC"), MValue(MValueType.Int32, 0x00_03, "envGenDec"),
			MValue(MValueType.Float, 0x00_04, "envGenAtkShp"), MValue(MValueType.Float, 0x00_05, "envGenDecShp"),
			MValue(MValueType.Float, 0x00_06, "envGenSusLevel"), MValue(MValueType.Float, 0x00_07, "masterVol"),
			MValue(MValueType.Float, 0x00_08, "balance"), MValue(MValueType.Float, 0x00_09, "auxSendA"),
			MValue(MValueType.Float, 0x00_0A, "auxSendB"), MValue(MValueType.Float, 0x00_0B, "velToLevelAm"),
			MValue(MValueType.Float, 0x00_0C, "velToAuxSendAm"), MValue(MValueType.Float, 0x00_0D, "velToAtkShp"),
			MValue(MValueType.Float, 0x00_0E, "velToRelShp"), MValue(MValueType.Float, 0x00_0F, "adsrToVol"),
			MValue(MValueType.Int32, 0x00_10, "flags"),
			MValue(MValueType.Boolean, 0x00_11, "f_cutoffOnKeyOff"),
			MValue(MValueType.Boolean, 0x00_12, "f_modwheelToLFO"),
			MValue(MValueType.Boolean, 0x00_13, "f_panningLFO"),
			MValue(MValueType.Float, 0x00_20, "pitchBendRange"),
			/* MValue(MValueType.Boolean, 0x00_13, "f_ADSRtoVol"), */
		] ~ SAMPLE_SET_VALS.dup ~ [
			MValue(MValueType.Float, 0x80_00, `_FilterLCFreq`), MValue(MValueType.Float, 0x80_01, `_FilterLCQ`),
			MValue(MValueType.Float, 0x80_02, `_FilterRCFreq`), MValue(MValueType.Float, 0x80_03, `_FilterRCQ`),
			MValue(MValueType.Float, 0x80_04, `_FilterACFreq`), MValue(MValueType.Float, 0x80_05, `_FilterACQ`),
			MValue(MValueType.Float, 0x80_06, `_FilterBCFreq`), MValue(MValueType.Float, 0x80_07, `_FilterBCQ`),
			MValue(MValueType.Float, 0x80_08, "_LFOFreq"), MValue(MValueType.Boolean, 0x80_09, "_LFOSaw"),
			MValue(MValueType.Boolean, 0x80_0a, "_LFOTri"), MValue(MValueType.Boolean, 0x80_0b, "_LFOPul"), 
			MValue(MValueType.Boolean, 0x80_0c, "_LFOSawPul"), MValue(MValueType.Boolean, 0x80_0d, "_LFOInv"),
			MValue(MValueType.Float, 0x80_0e, "_LFOPWM"), MValue(MValueType.Boolean, 0x80_0f, "_LFORingmod")
		];
	}
	/** 
	 * Reads the given value (int).
	 * Params:
	 *   presetID = The preset ID, or uint.max for global module values.
	 *   paramID = The parameter ID.
	 * Returns: The value of the given preset and parameter
	 */
	public override int readParam_int(uint presetID, uint paramID) nothrow {
		Preset* presetPtr = presetBank.ptrOf(presetID);
		if (presetPtr is null) return 0;
		if (paramID & 0x10_00) {
			switch (paramID & 0x0F_00) {
				case 0x00_00:
					return presetPtr.sampleMapping[paramID & 0x7F].sampleNum;
				case 0x02_00:
					return presetPtr.sampleMapping[paramID & 0x7F].loopBegin;
				case 0x03_00:
					return presetPtr.sampleMapping[paramID & 0x7F].loopEnd;
				default:
					break;
			}
		} else if (paramID & 0x80_00) {
			switch (paramID) {
				case 0x80_09:
					return lfoFlags & LFOFlags.saw ? 1 : 0;
				case 0x80_0a:
					return lfoFlags & LFOFlags.triangle ? 1 : 0;
				case 0x80_0b:
					return lfoFlags & LFOFlags.pulse ? 1 : 0;
				case 0x80_0c:
					return lfoFlags & LFOFlags.sawpulse ? 1 : 0;
				case 0x80_0d:
					return lfoFlags & LFOFlags.invert ? 1 : 0;
				case 0x80_0f:
					return lfoFlags & LFOFlags.ringmod ? 1 : 0;
				default:
					break;
			}
		} else {
			switch (paramID) {
				case 0x00:
					return presetPtr.eAtk;
				case 0x01:
					return presetPtr.eDec;
				case 0x02:
					return presetPtr.eSusC;
				case 0x03:
					return presetPtr.eRel;
				case 0x10:
					return presetPtr.flags;
				case 0x00_11:
					return presetPtr.flags & PresetFlags.cutoffOnKeyOff ? 1 : 0;
				case 0x00_12:
					return presetPtr.flags & PresetFlags.modwheelToLFO ? 1 : 0;
				case 0x00_13:
					return presetPtr.flags & PresetFlags.panningLFO ? 1 : 0;
				/* case 0x00_14:
					return presetPtr.flags |= PresetFlags.ADSRtoVol ? 1 : 0; */
				default:
					break;
			}
		}
		return 0;
	}
	/** 
	 * Reads the given value (int).
	 * Params:
	 *   presetID = The preset ID, or uint.max for global module values.
	 *   paramID = The parameter ID.
	 * Returns: The value of the given preset and parameter
	 */
	public override long readParam_long(uint presetID, uint paramID) nothrow {
		return 0;
	}
	/** 
	 * Reads the given value (int).
	 * Params:
	 *   presetID = The preset ID, or uint.max for global module values.
	 *   paramID = The parameter ID.
	 * Returns: The value of the given preset and parameter
	 */
	public override double readParam_double(uint presetID, uint paramID) nothrow {
		Preset* presetPtr = presetBank.ptrOf(presetID);
		if (presetPtr is null) return double.nan;
		if (paramID & 0x10_00) {
			switch (paramID & 0x0F_00) {
				case 0x01_00:
					return presetPtr.sampleMapping[paramID & 0x7F].baseFreq;
				default:
					break;
			}
		} else if (paramID & 0x80_00) {
			switch (paramID) {
				case 0x80_00: 
					return filterCtrl[0];
				case 0x80_01: 
					return filterCtrl[1];
				case 0x80_02: 
					return filterCtrl[2];
				case 0x80_03: 
					return filterCtrl[3];
				case 0x80_04: 
					return filterCtrl[4];
				case 0x80_05: 
					return filterCtrl[5];
				case 0x80_06: 
					return filterCtrl[6];
				case 0x80_07: 
					return filterCtrl[7];
				case 0x80_08: 
					return lfoFreq;
				case 0x80_0e: 
					return lfoPWM;
				default:
					break;
			}
		} else {
			switch (paramID) {
				case 0x00_04:
					return presetPtr.eAtkShp;
				case 0x00_05:
					return presetPtr.eRelShp;
				case 0x00_06:
					return presetPtr.eSusLev;
				case 0x00_07:
					return presetPtr.masterVol;
				case 0x00_08:
					return presetPtr.balance;
				case 0x00_09:
					return presetPtr.auxSendA;
				case 0x00_0A:
					return presetPtr.auxSendB;
				case 0x00_0B:
					return presetPtr.velToLevelAm;
				case 0x00_0C:
					return presetPtr.velToAuxSendAm;
				case 0x00_0D:
					return presetPtr.velToAtkShp;
				case 0x00_0E:
					return presetPtr.velToRelShp;
				case 0x00_0F:
					return presetPtr.adsrToVol;
				case 0x0020:
					return presetPtr.pitchBendAm;
				default:
					break;
			}
		}
		return double.nan;
	}
	/** 
	 * Reads the given value (int).
	 * Params:
	 *   presetID = The preset ID, or uint.max for global module values.
	 *   paramID = The parameter ID.
	 * Returns: The value of the given preset and parameter
	 */
	public override string readParam_string(uint presetID, uint paramID) nothrow {
		return null;
	}
}
