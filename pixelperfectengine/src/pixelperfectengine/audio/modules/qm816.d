module pixelperfectengine.audio.modules.qm816;

import pixelperfectengine.audio.base.modulebase;
import pixelperfectengine.audio.base.envgen;

import midi2.types.structs;
import midi2.types.enums;

import inteli.emmintrin;

import std.math;

/**
QM816 - implements a Quadrature-Amplitude synthesizer. This technique was used in early 
digital FM synths, since it allowed allowed a cheap implementation of the same thing as
long as the modulator was a sinusoidal waveform.

It has 16 2 operator channels that can be individually paired-up for 4 operator channels,
for more complex sounds. Also all operators have the option for feedback, including 
carriers. 2 operator channels have 2, 4 operator channels have 3*4 algorithms.

Before use, the synth needs to be supplied with a wavetable file, in 16 bit wav format.
*/
public class QM816 : AudioModule {
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
	Defines operator parameter numbers, within the unregistered namespace.
	*/
	public enum OperatorParamNums {
		//Unregistered
		Level		=	0,
		Attack		=	1,
		Decay		=	2,
		SusLevel	=	3,
		SusCtrl		=	4,
		Release		=	5,
		Waveform	=	6,
		Feedback	=	7,
		TuneCor		=	8,
		TuneFine	=	9,
		ShpA		=	10,
		ShpR		=	11,
		VelToLevel	=	12,
		MWToLevel	=	13,
		LFOToLevel	=	14,
		OpCtrl		=	15,
		VelToFB		=	16,
		MWToFB		=	17,
		LFOToFB		=	18,
		EEGToFB		=	19,
		VelToShpA	=	20,
		VelToShpR	=	21,
	}
	/**
	Defines channel parameter numbers, within the unregistered namespace.
	*/
	public enum ChannelParamNums {
		MasterVol	=	0,
		Bal			=	1,
		AuxSLA		=	2,
		AuxSLB		=	3,
		EEGDetune	=	4,
		PLFO		=	5,
		Attack		=	6,
		Decay		=	7,
		SusLevel	=	8,
		SusCtrl		=	9,
		Release		=	10,
		ShpA		=	11,
		ShpR		=	12,
		ChCtrl		=	16,
		RingMod		=	17,
		EEGToLeft	=	18,
		EEGToRight	=	19,
		EEGToAuxA	=	20,
		EEGToAuxB	=	21,
		LFOToLeft	=	22,
		LFOToRight	=	23,
		LFOToAuxA	=	24,
		LFOToAuxB	=	25,
	}
	/**
	Defines channel parameters within the registered namespace
	*/
	public enum ChannelRegParams {
		PitchBendSens,
		TuneCor,
		TuneFine,
	}
	/**
	Defines global parameter nummbers, within the unregistered namespace
	*/
	public enum GlobalParamNums {
		PLFORate	=	0,
		PLFOWF		=	1,
		ALFORate	=	2,
		ALFOWF		=	3,
		FilterLCFreq=	4,
		FilterLCQ	=	5,
		FilterRCFreq=	6,
		FilterRCQ	=	7,
		FilterACFreq=	8,
		FilterACQ	=	9,
		FilterBCFreq=	10,
		FilterBCQ	=	11,
	}
	/**
	Implements a single operator.
	
	Contains an oscillator, an ADSR envelop generator, and locals.
	*/
	public struct Operator {
		///The envelop generator of the operator.
		ADSREnvelopGenerator	eg;
		///The current position of the oscillator, including fractions.
		uint			pos;	
		///The amount the oscillator must be stepped forward each cycle, including fractions.
		uint			step;
		///Operator tuning
		///Bit 31-25: Coarse detuning (-24 to +103 seminotes)
		///Bit 24-0: Fine detuning (-100 to 100 cents), 0x1_00_00_00 is center
		uint			tune	=	0x31_00_00_00;
		enum TuneCtrlFlags : uint {
			FineTuneMidPoint	=	0x1_00_00_00,
			CorTuneMidPoint		=	0x30_00_00_00,
			FineTuneTest		=	0x1_FF_FF_FF,
			CorTuneTest			=	0xFE_00_00_00,
		}
		///Input register.
		///The amount which the oscillator will be offsetted.
		int				input;
		///Feedback register. Either out_0[n-1] or out[n-1] multiplied by feedback amount.
		///The amount which the oscillator will be offsetted.
		///Negative if inverted.
		int				feedback;
		///Output register.
		///Not affected by either level or EG
		int				output;
		///Output level (between 0.0 and 1.0)
		float			outL	=	1.0;
		///Feedback level (between 0.0 and 1.0)
		float			fbL		=	0.0;
		///Output level controller assignment
		///Index notation: 0: velocity 1: modulation wheel 2: Amplitude LFO 3: unused
		__m128			outLCtrl=	__m128(0.0);
		///Feedback level controller assignment
		///Index notation: 0: velocity 1: modulation wheel 2: Amplitude LFO 3: Extra envelop generator
		__m128			fbLCtrl	=	__m128(0.0);
		///Live calculated out of shpA
		float			shpA0	=	0.0;
		///Live calculated out of shpR
		float			shpR0	=	0.0;
		///Output affected by EEG and level.
		///Either used for audible output, or to modulate other operators
		int				output_0;
		///Control flags and Wavetable selector
		uint			opCtrl;
		///Defines control values
		enum OpCtrlFlags {
			WavetableSelect	=	127,		///Wavetable select flags
			FBMode			=	1 << 7,		///Feedback mode (L: After Envelop Generator, H: Before Envelop Generator)
			FBNeg			=	1 << 8,		///Feedback mode (L: Positive, H: Negative)
			MWNeg			=	1 << 9,		///Invert modulation wheel control
			VelNeg			=	1 << 10,	///Invert velocity control
			EGRelAdaptive	=	1 << 11,	///Adaptive release time based on current output level
			FixedPitch		=	1 << 12,	///Enables fixed pitch mode
		}
		///Attack time control (between 0 and 127)
		ubyte			atk;
		///Decay time control (between 0 and 127)
		ubyte			dec;
		///Release time control (between 0 and 127)
		ubyte			rel;
		///Sustain curve control (between 0 and 127)
		///0: Percussive mode
		///1 - 63: Descending over time
		///64: Constant
		///65 - 127: Ascending over time
		ubyte			susCC;
		///ADSR shaping parameter (for the attack phase)
		float			shpA	=	0.5;
		///ADSR shaping parameter (for the decay/release phase)
		float			shpR	=	0.5;
		///Assigns velocity to shpA
		float			shpAVel	=	0.0;
		///Assigns velocity to shpR
		float			shpRVel =	0.0;
	}
	/**
	Defines channel common parameters.
	*/
	public struct Channel {
		///Extra envelop generator that can be assigned for multiple purpose.
		ADSREnvelopGenerator	eeg;
		///ADSR shaping parameter (for the attack phase)
		float			shpAX;
		///ADSR shaping parameter (for the decay/release phase)
		float			shpRX;
		///Pitch amount for EEG
		///Bit 31-25: Coarse (-64 to +63 seminotes)
		///Bit 24-0: Fine (0 to 100 cents)
		uint			eegDetuneAm;
		///Pitch bend sensitivity
		///Bit 31-25: Coarse (0 to 127 seminotes)
		///Bit 24-0: Fine (0 to 100 cents)
		uint			pitchBendSens;
		///A-4 channel tuning in hertz.
		float			chnlTun = 440.0;
		///Stores channel control flags.
		uint			chCtrl;
		///Defines channel control flags.
		enum ChCtrlFlags {
			///Channel combination turned off, the channel pair is independent
			ComboModeOff	=	0b0000,	
			///Channel combination mode 1: Secondary channel's output is fed into primary operator 0.
			ComboMode1		=	0b0001,
			///Channel combination mode 2: Secondary channel's output is fed into primary operator 1 if primary 
			///is in serial mode, or into both if primary is in parallel mode.
			ComboMode2		=	0b0010,
			///Channel combination mode 3: Secondary channel's output is fed into main output, except if primary 
			///channel set to parallel and secondary set to serial, then S1, P0, and P1 are connected to output, while
			///S0 is modulating all of them.
			ComboMode3		=	0b0011,
			///Used for testing combo mode.
			ComboModeTest	=	ComboMode3,
			Algorithm		=	1<<2,	///Channel algorithm (H: Parallel, L: Series)
			IndivOutChLev	=	1<<3,	///Enables the setting of individual output channel levels
			LFOPan			=	1<<4,	///Enables LFO Panning
			EEGPan			=	1<<5,	///Enables EEG Panning
			MWToTrem		=	1<<6,	///Assigns modwheel to amplitude LFO
			MWToVibr		=	1<<7,	///Assigns modwheel to pitch LFO
			MWToAux			=	1<<8,	///Assigns modwheel to aux levels
		}
		///Master volume (0.0 to 1.0)
		float			masterVol;
		///Master balance (0.0 to 1.0)
		float			masterBal;
		///Calculated output level controls + aux send levels
		///Index notation: 0: Left channel 1: Right channel 2: Aux send A, 3: Aux send B
		__m128			outLevels;
		///EEG assign levels
		///Index notation: 0: Left channel 1: Right channel 2: Aux send A, 3: Aux send B
		__m128			eegLevels;
		///Amplitude LFO assign levels
		///Index notation: 0: Left channel 1: Right channel 2: Aux send A, 3: Aux send B
		__m128			aLFOlevels;
		///Ring modulation amount
		///Only available on select algorithms
		int				rmAmount;
		///Pitch LFO level
		float			pLFOlevel;
		///Amplitude LFO to 
		///Attack time control (between 0 and 127)
		ubyte			atkX;
		///Decay time control (between 0 and 127)
		ubyte			decX;
		///Release time control (between 0 and 127)
		ubyte			relX;
		///Sustain curve control (between 0 and 127)
		///0: Percussive mode
		///1 - 63: Descending over time
		///64: Constant
		///65 - 127: Ascending over time
		ubyte			susCCX;
	}
	/**
	Stores channel controller values (modwheel, velocity, etc.)
	*/
	public struct ChControllers {
		///Modulation wheel parameter, normalized between 0.0 and 1.0
		float			modwheel;
		///Velocity parameter, normalized between 0.0 and 1.0
		float			velocity;
		///Pitch bend parameter, with the amount of pitch shifting in semitones + fractions
		float			pitchBend;
		///The note that is currently being played
		ubyte			note;
	}
	/**
	Defines a preset.
	*/
	public struct Preset {
		///Operator tuning
		///Bit 31-25: Coarse detuning (-24 to +103 seminotes)
		///Bit 24-0: Fine detuning (0 to 100 cents)
		uint			tune0	=	0x30_00_00_00;
		///Output level (between 0.0 and 1.0)
		float			outL0	=	1.0;
		///Feedback level (between 0.0 and 1.0)
		float			fbL0	=	0.0;
		///ADSR shaping parameter (for the attack phase)
		float			shpA0	=	0.5;
		///ADSR shaping parameter (for the decay/release phase)
		float			shpR0	=	0.5;
		///Velocity amount for operator
		float			velAm0	=	1.0;
		///Control flags and Wavetable selector
		uint			opCtrl0;
		///Attack time control (between 0 and 127)
		ubyte			atk0;
		///Decay time control (between 0 and 127)
		ubyte			dec0;
		///Release time control (between 0 and 127)
		ubyte			rel0;
		///Sustain curve control (between 0 and 127)
		///0: Percussive mode
		///1 - 63: Descending over time
		///64: Constant
		///65 - 127: Ascending over time
		ubyte			susCC0;
		///Operator tuning
		///Bit 31-25: Coarse detuning (-24 to +103 seminotes)
		///Bit 24-0: Fine detuning (0 to 100 cents)
		uint			tune1	=	0x30_00_00_00;
		///Output level (between 0.0 and 1.0)
		float			outL1	=	1.0;
		///Feedback level (between 0.0 and 1.0)
		float			fbL1	=	0.0;
		///ADSR shaping parameter (for the attack phase)
		float			shpA1	=	0.5;
		///ADSR shaping parameter (for the decay/release phase)
		float			shpR1	=	0.5;
		///Velocity amount for operator
		float			velAm1	=	1.0;
		///Control flags and Wavetable selector
		uint			opCtrl1;
		///Attack time control (between 0 and 127)
		ubyte			atk1;
		///Decay time control (between 0 and 127)
		ubyte			dec1;
		///Release time control (between 0 and 127)
		ubyte			rel1;
		///Sustain curve control (between 0 and 127)
		///0: Percussive mode
		///1 - 63: Descending over time
		///64: Constant
		///65 - 127: Ascending over time
		ubyte			susCC1;
		///ADSR shaping parameter (for the attack phase)
		float			shpAX;
		///ADSR shaping parameter (for the decay/release phase)
		float			shpRX;
		///Pitch amount for EEG
		///Bit 31-25: Coarse (-64 to +63 seminotes)
		///Bit 24-0: Fine (0 to 100 cents)
		uint			eegDetuneAm;
		///Pitch bend sensitivity
		///Bit 31-25: Coarse (0 to 127 seminotes)
		///Bit 24-0: Fine (0 to 100 cents)
		uint			pitchBendSens;
		///A-4 channel tuning in hertz.
		float			chnlTun = 440.0;
		///Amount of how much amplitude values must be affected by EEG
		float			eegAmpAmount;
		///Stores channel control flags.
		uint			chCtrl;
		///Master volume (0.0 to 1.0)
		float			masterVol;
		///Master balance (0.0 to 1.0)
		float			masterBal;
		///Aux send level 0
		float			auxSend0;
		///Aux send level 1
		float			auxSend1;
		///Amplitude LFO level
		float			aLFOlevel;
		///Pitch LFO level
		float			pLFOlevel;
		///Velocity amount
		float			velAmount;
		///Modulation wheel amount
		float			modwheelAmount;
		///Attack time control (between 0 and 127)
		ubyte			atkX;
		///Decay time control (between 0 and 127)
		ubyte			decX;
		///Release time control (between 0 and 127)
		ubyte			relX;
		///Sustain curve control (between 0 and 127)
		///0 = Percussive mode
		///1 - 63: Descending over time
		///64 = Constant
		///65 - 127: Ascending over time
		ubyte			susCCX;
	}
	///Contains the wavetables for the operators and LFOs.
	///Value might be divided to limit the values between 2047 and -2048 via bitshifting,
	///otherwise the full range can be used for audio output, etc.
	///Loaded from a 16 bit wave file.
	protected short[1024][128]	wavetables;
	///Stores presets.
	///8 banks of 128 presets are available for a total of 1024.
	///Note: Combined channel presets must be loaded in pairs to each channels.
	protected Preset[128][8]	soundBank;
	///Operator data.
	///See rendering function on updating.
	protected Operator[32]		operators;
	///Channel data.
	///See rendering function on updating.
	protected Channel[16]		channels;
	///Channel control data.
	protected ChControllers[16]	chCtrls;
	///Preset numbers per channels.
	protected ubyte[16]			presetNum;
	///Bank numbers per channels.
	protected ubyte[16]			bankNum;
	///Keeps the registered/unregistered parameter positions (LSB = 0).
	protected ubyte[2]			paramNum;
	///Stores LFO waveform selection. 1: Amplitude; 0: Pitch
	protected ubyte[2]			lfoWaveform;
	///Stores temporary parameter values
	protected ubyte[4]			paramTemp;
	///Stores ALFO position
	protected uint				aLFOPos;
	///Stores ALFO rate
	protected uint				aLFORate;
	///Stores output filter values.
	///0: a0; 1: a1; 2: a2; 3: b0; 4: b1; 5: b2; 6: n-1; 7: n-2;
	protected __m128[8]			filterVals;
	///Stores control values of the output values.
	///Layout: [LF, LQ, RF, RQ, AF, AQ, BF, BQ]
	protected float[8]			filterCtrl;
	///Initial mixing buffers
	///Output is directed there before filtering
	///Layout is: LRAB
	protected float[]			initBuffers;
	///Dummy buffer
	///Only used if one or more outputs haven't been defined
	protected float[]			dummyBuf;
	///Amplitude LFO buffer. Values are between 0.0 and 1.0
	protected float[]			aLFOBuf;
	///Pitch LFO output. Values are between -1.0 and 1.0
	protected float				pLFOOut;
	///Stores PLFO position
	protected uint				pLFOPos;
	///Stores PLFO rate
	protected uint				pLFORate;
	alias ChFun = void delegate(int chNum, size_t length) @nogc pure nothrow;
	///Channel update delegates
	protected ChFun[16]			chDeleg;
	/**
	Creates an instance of QM816
	*/
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
		int errorcode;
		if (format.channels != 1) errorcode |= SampleLoadErrorCode.ChNumNotSupported;
		if (format.bitsPerSample != 16) errorcode |= SampleLoadErrorCode.BitdepthNotSupported;
		if (format.format != AudioFormat.PCM) errorcode |= SampleLoadErrorCode.FormatNotSupported;
		if (rawData.length != 128 * 1024 * 2) errorcode |= SampleLoadErrorCode.SampleLenghtNotSupported;
		if (errorcode) {
			return errorcode;
		} else {
			import core.stdc.string : memcpy;
			memcpy (wavetables.ptr, rawData.ptr, 128 * 1024 * 2);
			return 0;
		}
	}
	/**
	 * MIDI 2.0 data received here.
	 *
	 * data: up to 128 bits of MIDI 2.0 commands. Any packets that are shorter should be padded with zeros.
	 * offset: time offset of the command. This can reduce jitter caused by the asynchronous operation of the 
	 * sequencer and the audio plugin system.
	 */
	public override void midiReceive(uint[4] data, uint offset) @nogc nothrow {
		UMP firstPacket;
		firstPacket.base = data[0];
		switch (firstPacket.msgType) {
			case MessageType.SysCommMsg:	//Process system common message
				break;
			case MessageType.MIDI1:			//Process MIDI 1.0 messages
				switch (firstPacket.status) {
					case MIDI1_0Cmd.CtrlCh:	//Process MIDI 1.0 control change messages
						switch (firstPacket.note) {
							case 0, 32:			//Bank select
								bankNum[firstPacket.channel] = firstPacket.value;
								break;
							case 1:				//Modulation wheel
								chCtrls[firstPacket.channel].modwheel = cast(double)(firstPacket.value) / byte.max;
								break;
							case 6:			//Data Entry MSB
								paramNum[1] = firstPacket.value;
								break;
							case 38:		//Data Entry LSB
								paramNum[0] = firstPacket.value;
								break;
							case 98:		//Non Registered Parameter Number LSB
								setUnregisteredParam(firstPacket.value, paramNum, 0, firstPacket.channel);
								break;
							case 99:		//Non Registered Parameter Number LSB
								setUnregisteredParam(firstPacket.value, paramNum, 0, firstPacket.channel);
								break;
							default:
								break;
						}
						break;
					case MIDI1_0Cmd.NoteOn:
						break;
					case MIDI1_0Cmd.NoteOff:
						break;
					case MIDI1_0Cmd.PrgCh:
						break;
					
					default:
						break;
				}
				break;
			case MessageType.MIDI2:
				switch (firstPacket.status) {
					case MIDI2_0Cmd.CtrlCh:	//Control change
						setUnregisteredParam(data[1], [firstPacket.index, firstPacket.value], 0, firstPacket.channel);
						break;
					default:
						break;
				}
				break;
			default:
				break;
		}
	}
	/**
	Sets a registered parameter

	If type is not zero, then the MSB is being set, otherwise the LSB will be used
	*/
	protected void setRegisteredParam(T)(T val, ubyte[2] paramNum, ubyte type, ubyte chNum) @nogc @safe pure nothrow {
		switch (paramNum[0]) {
			case ChannelRegParams.PitchBendSens:
				break;
			case ChannelRegParams.TuneFine:			//Channel master tuning (fine)
				break;
			case ChannelRegParams.TuneCor:			//Channel master tuning (coarse)
				break;
			default: break;
		}
	}
	/**
	Sets an unregistered parameter

	If type is not zero, then the MSB is being set, otherwise the LSB will be used
	*/
	protected void setUnregisteredParam(T)(T val, ubyte[2] paramNum, ubyte type, ubyte chNum) @nogc @safe pure nothrow {
		void setOpParam(int chNum) {
			switch (paramNum[0]) {
				case OperatorParamNums.Attack:
					static if (is(T == uint)) {
						operators[chNum].atk = cast(ubyte)(val >> 25);
					} else static if (is(T == ubyte)) {
						operators[chNum].atk = val;
					}
					if (operators[chNum].atk) {
						operators[chNum].eg.attackRate = calculateRate(ADSR_TIME_TABLE[operators[chNum].atk], sampleRate);
					} else {
						operators[chNum].eg.attackRate = 1.0;
					}
					break;
				case OperatorParamNums.Decay:
					static if (is(T == uint)) {
						operators[chNum].dec = cast(ubyte)(val >> 25);
					} else static if (is(T == ubyte)) {
						operators[chNum].dec = val;
					}
					if (operators[chNum].dec) {
						operators[chNum].eg.decayRate = calculateRate(ADSR_TIME_TABLE[operators[chNum].dec] * 2, sampleRate, 
								ADSREnvelopGenerator.maxOutput, operators[chNum].eg.sustainLevel);
					} else {
						operators[chNum].eg.decayRate = 1.0;
					}
					break;
				case OperatorParamNums.Feedback:
					static if (is(T == uint)) {
						const double valF = cast(double)val / uint.max;
						operators[chNum].fbL = valF * valF;
					} else static if (is(T == ubyte)) {
						if (type)
							paramTemp[2] = val;
						else
							paramTemp[3] = val;
						if (paramNum[0] == paramTemp[0] && paramNum[1] == paramTemp[1]) {	//Set parameter if  found.
							const uint val32 = paramTemp[3] | paramTemp[2]<<7;
							const double valF = cast(double)(val32) / cast(double)(ushort.max>>2);
							operators[chNum].fbL = valF * valF;
						} else {		//Set temp for next command (assume MSB-LSB order)
							paramNum[0] = paramTemp[0];
							paramNum[1] = paramTemp[1];
						}
					}
					break;
				case OperatorParamNums.Level:
					static if (is(T == uint)) {
						const double valF = cast(double)val / uint.max;
						operators[chNum].outL = valF * valF;
					} else static if (is(T == ubyte)) {
						if (type)
							paramTemp[2] = val;
						else
							paramTemp[3] = val;
						if (paramNum[0] == paramTemp[0] && paramNum[1] == paramTemp[1]) {	//Set parameter if  found.
							const uint val32 = paramTemp[3] | paramTemp[2]<<7;
							const double valF = cast(double)(val32) / cast(double)(ushort.max>>2);
							operators[chNum].outL = valF * valF;
						} else {		//Set temp for next command (assume MSB-LSB order)
							paramNum[0] = paramTemp[0];
							paramNum[1] = paramTemp[1];
						}
					}
					break;
				case OperatorParamNums.OpCtrl:
					static if (is(T == uint)) {
						operators[chNum].opCtrl = val;
					} else static if (is(T == ubyte)) {
						operators[chNum].opCtrl &= ~(byte.max<<7);
						operators[chNum].opCtrl |= val<<7;
					}
					break;
				case OperatorParamNums.Release:
					static if (is(T == uint)) {
						operators[chNum].rel = cast(ubyte)(val >> 25);
					} else static if (is(T == ubyte)) {
						operators[chNum].rel = val;
					}
					if (operators[chNum].rel) {
						operators[chNum].eg.releaseRate = calculateRate(ADSR_TIME_TABLE[operators[chNum].rel] * 2, sampleRate, 
								operators[chNum].eg.sustainLevel);
					} else {
						operators[chNum].eg.releaseRate = 1.0;
					}
					break;
				case OperatorParamNums.ShpA:
					static if (is(T == uint)) {
						operators[chNum].shpA = cast(double)val / uint.max;
					} else static if (is(T == ubyte)) {
						if (type)
							paramTemp[2] = val;
						else
							paramTemp[3] = val;
						if (paramNum[0] == paramTemp[0] && paramNum[1] == paramTemp[1]) {	//Set parameter if  found.
							const uint val32 = paramTemp[3] | paramTemp[2]<<7;
							operators[chNum].shpA = cast(double)(val32) / cast(double)(ushort.max>>2);
						} else {		//Set temp for next command (assume MSB-LSB order)
							paramNum[0] = paramTemp[0];
							paramNum[1] = paramTemp[1];
						}
					}
					break;
				case OperatorParamNums.ShpR:
					static if (is(T == uint)) {
						operators[chNum].shpR = cast(double)val / uint.max;
					} else static if (is(T == ubyte)) {
						if (type)
							paramTemp[2] = val;
						else
							paramTemp[3] = val;
						if (paramNum[0] == paramTemp[0] && paramNum[1] == paramTemp[1]) {	//Set parameter if  found.
							const uint val32 = paramTemp[3] | paramTemp[2]<<7;
							operators[chNum].shpR = cast(double)(val32) / cast(double)(ushort.max>>2);
						} else {		//Set temp for next command (assume MSB-LSB order)
							paramNum[0] = paramTemp[0];
							paramNum[1] = paramTemp[1];
						}
					}
					break;
				case OperatorParamNums.SusCtrl:
					static if (is(T == uint)) {
						operators[chNum].susCC = cast(ubyte)(val >> 25);
					} else static if (is(T == ubyte)) {
						operators[chNum].susCC = val;
					}
					if (operators[chNum].susCC) {
						operators[chNum].eg.isPercussive = false;
						if (operators[chNum].susCC == 64) {
							operators[chNum].eg.sustainControl = 0.0;
						} else if (operators[chNum].susCC < 64) {
							operators[chNum].eg.sustainControl = -1.0 * 
									calculateRate(SUSTAIN_CONTROL_TIME_TABLE[operators[chNum].susCC - 1], sampleRate);
						} else {
							operators[chNum].eg.sustainControl = 
									calculateRate(SUSTAIN_CONTROL_TIME_TABLE[operators[chNum].susCC - 64], sampleRate);
						}
					} else {
						operators[chNum].eg.isPercussive = true;
						operators[chNum].eg.sustainControl = 0.0;
					}
					break;
				case OperatorParamNums.SusLevel:
					static if (is(T == uint)) {
						operators[chNum].eg.sustainLevel = cast(double)val / uint.max;
					} else static if (is(T == ubyte)) {
						if (type)
							paramTemp[2] = val;
						else
							paramTemp[3] = val;
						if (paramNum[0] == paramTemp[0] && paramNum[1] == paramTemp[1]) {	//Set parameter if  found.
							const uint val32 = paramTemp[3] | paramTemp[2]<<7;
							operators[chNum].eg.sustainLevel = cast(double)(val32) / cast(double)(ushort.max>>2);
						} else {		//Set temp for next command (assume MSB-LSB order)
							paramNum[0] = paramTemp[0];
							paramNum[1] = paramTemp[1];
						}
						
					}
					//Recalculate decay and release rates to new sustain levels
					if (operators[chNum].dec) {
						operators[chNum].eg.decayRate = calculateRate(ADSR_TIME_TABLE[operators[chNum].dec] * 2, sampleRate, 
								ADSREnvelopGenerator.maxOutput, operators[chNum].eg.sustainLevel);
					} else {
						operators[chNum].eg.decayRate = 1.0;
					}
					if (operators[chNum].rel) {
						operators[chNum].eg.releaseRate = calculateRate(ADSR_TIME_TABLE[operators[chNum].rel] * 2, sampleRate, 
								operators[chNum].eg.sustainLevel);
					} else {
						operators[chNum].eg.releaseRate = 1.0;
					}
					break;
				case OperatorParamNums.TuneCor:
					static if (is(T == uint)) {
						operators[chNum].tune = val;
					} else static if (is(T == ubyte)) {
						if (type)
							paramTemp[2] = val;
						else
							paramTemp[3] = val;
						if (paramNum[0] == paramTemp[0] && paramNum[1] == paramTemp[1]) {	//Set parameter if  found.
							const uint val32 = paramTemp[3] | paramTemp[2]<<7;
							//operators[chNum].velAm = val32 / ushort.max>>2;
							operators[chNum].tune &= ~(uint.max<<18);
							operators[chNum].tune |= val32<<18;
						} else {		//Set temp for next command (assume MSB-LSB order)
							paramNum[0] = paramTemp[0];
							paramNum[1] = paramTemp[1];
						}
					}
					break;
				case OperatorParamNums.TuneFine:
					operators[chNum].tune &= uint.max>>7;
					static if (is(T == uint)) {
						operators[chNum].tune |= val>>7;
					} else static if (is(T == ubyte)) {
						if (type)
							paramTemp[2] = val;
						else
							paramTemp[3] = val;
						if (paramNum[0] == paramTemp[0] && paramNum[1] == paramTemp[1]) {	//Set parameter if  found.
							const uint val32 = paramTemp[3] | paramTemp[2]<<7;
							operators[chNum].tune |= val32<<10 | val32>>5;
						} else {		//Set temp for next command (assume MSB-LSB order)
							paramNum[0] = paramTemp[0];
							paramNum[1] = paramTemp[1];
						}
					}
					break;
				case OperatorParamNums.VelToLevel:
					static if (is(T == uint)) {
						operators[chNum].outLCtrl[0] = cast(double)val / uint.max;
					} else static if (is(T == ubyte)) {
						if (type)
							paramTemp[2] = val;
						else
							paramTemp[3] = val;
						if (paramNum[0] == paramTemp[0] && paramNum[1] == paramTemp[1]) {	//Set parameter if  found.
							const uint val32 = paramTemp[3] | paramTemp[2]<<7;
							operators[chNum].outLCtrl[0] = cast(double)(val32) / cast(double)(ushort.max>>2);
						} else {		//Set temp for next command (assume MSB-LSB order)
							paramNum[0] = paramTemp[0];
							paramNum[1] = paramTemp[1];
						}
					}
					break;
				case OperatorParamNums.MWToLevel:
					static if (is(T == uint)) {
						operators[chNum].outLCtrl[1] = cast(double)val / uint.max;
					} else static if (is(T == ubyte)) {
						if (type)
							paramTemp[2] = val;
						else
							paramTemp[3] = val;
						if (paramNum[0] == paramTemp[0] && paramNum[1] == paramTemp[1]) {	//Set parameter if  found.
							const uint val32 = paramTemp[3] | paramTemp[2]<<7;
							operators[chNum].outLCtrl[1] = cast(double)(val32) / cast(double)(ushort.max>>2);
						} else {		//Set temp for next command (assume MSB-LSB order)
							paramNum[0] = paramTemp[0];
							paramNum[1] = paramTemp[1];
						}
					}
					break;
				case OperatorParamNums.LFOToLevel:
					static if (is(T == uint)) {
						operators[chNum].outLCtrl[2] = cast(double)val / uint.max;
					} else static if (is(T == ubyte)) {
						if (type)
							paramTemp[2] = val;
						else
							paramTemp[3] = val;
						if (paramNum[0] == paramTemp[0] && paramNum[1] == paramTemp[1]) {	//Set parameter if  found.
							const uint val32 = paramTemp[3] | paramTemp[2]<<7;
							operators[chNum].outLCtrl[2] = cast(double)(val32) / cast(double)(ushort.max>>2);
						} else {		//Set temp for next command (assume MSB-LSB order)
							paramNum[0] = paramTemp[0];
							paramNum[1] = paramTemp[1];
						}
					}
					break;
				case OperatorParamNums.VelToFB:
					static if (is(T == uint)) {
						operators[chNum].fbLCtrl[0] = cast(double)val / uint.max;
					} else static if (is(T == ubyte)) {
						if (type)
							paramTemp[2] = val;
						else
							paramTemp[3] = val;
						if (paramNum[0] == paramTemp[0] && paramNum[1] == paramTemp[1]) {	//Set parameter if  found.
							const uint val32 = paramTemp[3] | paramTemp[2]<<7;
							operators[chNum].fbLCtrl[0] = cast(double)(val32) / cast(double)(ushort.max>>2);
						} else {		//Set temp for next command (assume MSB-LSB order)
							paramNum[0] = paramTemp[0];
							paramNum[1] = paramTemp[1];
						}
					}
					break;
				case OperatorParamNums.MWToFB:
					static if (is(T == uint)) {
						operators[chNum].fbLCtrl[1] = cast(double)val / uint.max;
					} else static if (is(T == ubyte)) {
						if (type)
							paramTemp[2] = val;
						else
							paramTemp[3] = val;
						if (paramNum[0] == paramTemp[0] && paramNum[1] == paramTemp[1]) {	//Set parameter if  found.
							const uint val32 = paramTemp[3] | paramTemp[2]<<7;
							operators[chNum].fbLCtrl[1] = cast(double)(val32) / cast(double)(ushort.max>>2);
						} else {		//Set temp for next command (assume MSB-LSB order)
							paramNum[0] = paramTemp[0];
							paramNum[1] = paramTemp[1];
						}
					}
					break;
				case OperatorParamNums.LFOToFB:
					static if (is(T == uint)) {
						operators[chNum].fbLCtrl[2] = cast(double)val / uint.max;
					} else static if (is(T == ubyte)) {
						if (type)
							paramTemp[2] = val;
						else
							paramTemp[3] = val;
						if (paramNum[0] == paramTemp[0] && paramNum[1] == paramTemp[1]) {	//Set parameter if  found.
							const uint val32 = paramTemp[3] | paramTemp[2]<<7;
							operators[chNum].fbLCtrl[2] = cast(double)(val32) / cast(double)(ushort.max>>2);
						} else {		//Set temp for next command (assume MSB-LSB order)
							paramNum[0] = paramTemp[0];
							paramNum[1] = paramTemp[1];
						}
					}
					break;
				case OperatorParamNums.EEGToFB:
					static if (is(T == uint)) {
						operators[chNum].fbLCtrl[3] = cast(double)val / uint.max;
					} else static if (is(T == ubyte)) {
						if (type)
							paramTemp[2] = val;
						else
							paramTemp[3] = val;
						if (paramNum[0] == paramTemp[0] && paramNum[1] == paramTemp[1]) {	//Set parameter if  found.
							const uint val32 = paramTemp[3] | paramTemp[2]<<7;
							operators[chNum].fbLCtrl[3] = cast(double)(val32) / cast(double)(ushort.max>>2);
						} else {		//Set temp for next command (assume MSB-LSB order)
							paramNum[0] = paramTemp[0];
							paramNum[1] = paramTemp[1];
						}
					}
					break;
				case OperatorParamNums.VelToShpA:
					static if (is(T == uint)) {
						operators[chNum].shpAVel = cast(double)val / uint.max;
					} else static if (is(T == ubyte)) {
						if (type)
							paramTemp[2] = val;
						else
							paramTemp[3] = val;
						if (paramNum[0] == paramTemp[0] && paramNum[1] == paramTemp[1]) {	//Set parameter if  found.
							const uint val32 = paramTemp[3] | paramTemp[2]<<7;
							operators[chNum].shpAVel = cast(double)(val32) / cast(double)(ushort.max>>2);
						} else {		//Set temp for next command (assume MSB-LSB order)
							paramNum[0] = paramTemp[0];
							paramNum[1] = paramTemp[1];
						}
					}
					break;
				case OperatorParamNums.VelToShpR:
					static if (is(T == uint)) {
						operators[chNum].shpRVel = cast(double)val / uint.max;
					} else static if (is(T == ubyte)) {
						if (type)
							paramTemp[2] = val;
						else
							paramTemp[3] = val;
						if (paramNum[0] == paramTemp[0] && paramNum[1] == paramTemp[1]) {	//Set parameter if  found.
							const uint val32 = paramTemp[3] | paramTemp[2]<<7;
							operators[chNum].shpRVel = cast(double)(val32) / cast(double)(ushort.max>>2);
						} else {		//Set temp for next command (assume MSB-LSB order)
							paramNum[0] = paramTemp[0];
							paramNum[1] = paramTemp[1];
						}
					}
					break;
				case OperatorParamNums.Waveform:
					operators[chNum].opCtrl &= ~Operator.OpCtrlFlags.WavetableSelect;
					static if (is(T == uint)) {
						operators[chNum].opCtrl |= cast(ubyte)(val >> 25);
					} else static if (is(T == ubyte)) {
						operators[chNum].opCtrl |= val;
					}
					break;
				default: break;
			}
		}
		switch (paramNum[1]) {
			case 0:			//Channel operator 0
				chNum *= 2;
				setOpParam(chNum);
				break;
			case 1:			//Channel operator 1
				chNum *= 2;
				setOpParam(chNum + 1);
				break;
			case 2:			//Channel common values
				switch (paramNum[0]) { 
					//case ChannelParamNums.ALFO: break;
					case ChannelParamNums.Attack:
						static if (is(T == uint)) {
							channels[chNum].atkX = cast(ubyte)(val >> 25);
						} else static if (is(T == ubyte)) {
							channels[chNum].atkX = val;
						}
						if (channels[chNum].atkX) {
							channels[chNum].eeg.attackRate = calculateRate(ADSR_TIME_TABLE[channels[chNum].atkX], sampleRate);
						} else {
							channels[chNum].eeg.attackRate = 1.0;
						}
						break;
					case ChannelParamNums.AuxSLA:
						static if (is(T == uint)) {
							const double valF = cast(double)val / uint.max;
							channels[chNum].outLevels[2] = valF * valF;
						} else static if (is(T == ubyte)) {
							if (type)
								paramTemp[2] = val;
							else
								paramTemp[3] = val;
							if (paramNum[0] == paramTemp[0] && paramNum[1] == paramTemp[1]) {	//Set parameter if  found.
								const uint val32 = paramTemp[3] | paramTemp[2]<<7;
								const double valF = cast(double)(val32) / cast(double)(ushort.max>>2);
								channels[chNum].outLevels[2] = valF * valF;
							} else {		//Set temp for next command (assume MSB-LSB order)
								paramNum[0] = paramTemp[0];
								paramNum[1] = paramTemp[1];
							}
						}
						break;
					case ChannelParamNums.AuxSLB: 
						static if (is(T == uint)) {
							const double valF = cast(double)val / uint.max;
							channels[chNum].outLevels[2] = valF * valF;
						} else static if (is(T == ubyte)) {
							if (type)
								paramTemp[2] = val;
							else
								paramTemp[3] = val;
							if (paramNum[0] == paramTemp[0] && paramNum[1] == paramTemp[1]) {	//Set parameter if  found.
								const uint val32 = paramTemp[3] | paramTemp[2]<<7;
								const double valF = cast(double)(val32) / cast(double)(ushort.max>>2);
								channels[chNum].outLevels[2] = valF * valF;
							} else {		//Set temp for next command (assume MSB-LSB order)
								paramNum[0] = paramTemp[0];
								paramNum[1] = paramTemp[1];
							}
						}
						break;
					case ChannelParamNums.Bal: 
						static if (is(T == uint)) {
							channels[chNum].masterBal = cast(double)val / uint.max;
						} else static if (is(T == ubyte)) {
							if (type)
								paramTemp[2] = val;
							else
								paramTemp[3] = val;
							if (paramNum[0] == paramTemp[0] && paramNum[1] == paramTemp[1]) {	//Set parameter if  found.
								const uint val32 = paramTemp[3] | paramTemp[2]<<7;
								channels[chNum].masterBal = cast(double)(val32) / cast(double)(ushort.max>>2);
							} else {		//Set temp for next command (assume MSB-LSB order)
								paramNum[0] = paramTemp[0];
								paramNum[1] = paramTemp[1];
								return;
							}
						}
						if (channels[chNum].chCtrl & Channel.ChCtrlFlags.IndivOutChLev) {
							channels[chNum].outLevels[1] = channels[chNum].masterBal * channels[chNum].masterBal;
						} else {
							channels[chNum].outLevels[0] = channels[chNum].masterVol - channels[chNum].masterBal;
							channels[chNum].outLevels[1] = channels[chNum].masterVol - (1.0 - channels[chNum].masterBal);
						}
						break;
					case ChannelParamNums.ChCtrl:
						static if (is(T == uint)) {
							channels[chNum].chCtrl = val;
						} else static if (is(T == ubyte)) {
							if (type) {
								channels[chNum].chCtrl &= ~(byte.max<<7);
								channels[chNum].chCtrl |= val<<7;
							} else {
								channels[chNum].chCtrl &= ~(cast(uint)byte.max);
								channels[chNum].chCtrl |= val;
							}
						}
						break;
					//case ChannelParamNums.ChCtrlL: break;
					case ChannelParamNums.Decay:
						static if (is(T == uint)) {
							channels[chNum].decX = cast(ubyte)(val >> 25);
						} else static if (is(T == ubyte)) {
							channels[chNum].decX = val;
						}
						if (channels[chNum].decX) {
							channels[chNum].eeg.decayRate = calculateRate(ADSR_TIME_TABLE[channels[chNum].decX] * 2, sampleRate);
						} else {
							channels[chNum].eeg.decayRate = 1.0;
						}
						break;
					case ChannelParamNums.EEGDetune:
						static if (is(T == uint)) {
							channels[chNum].eegDetuneAm = val;
						} else static if (is(T == ubyte)) {
							if (type)
								paramTemp[2] = val;
							else
								paramTemp[3] = val;
							if (paramNum[0] == paramTemp[0] && paramNum[1] == paramTemp[1]) {	//Set parameter if  found.
								channels[chNum].eegDetuneAm = paramTemp[3] | paramTemp[2]<<7;
							} else {		//Set temp for next command (assume MSB-LSB order)
								paramNum[0] = paramTemp[0];
								paramNum[1] = paramTemp[1];
							}
						}
						break;
					case ChannelParamNums.MasterVol: 
						static if (is(T == uint)) {
							const double valF = cast(double)val / uint.max;
							channels[chNum].outLevels[2] = valF * valF;
						} else static if (is(T == ubyte)) {
							if (type)
								paramTemp[2] = val;
							else
								paramTemp[3] = val;
							if (paramNum[0] == paramTemp[0] && paramNum[1] == paramTemp[1]) {	//Set parameter if  found.
								const uint val32 = paramTemp[3] | paramTemp[2]<<7;
								const double valF = cast(double)(val32) / cast(double)(ushort.max>>2);
								channels[chNum].outLevels[2] = valF * valF;
							} else {		//Set temp for next command (assume MSB-LSB order)
								paramNum[0] = paramTemp[0];
								paramNum[1] = paramTemp[1];
							}
						}
						if (channels[chNum].chCtrl & Channel.ChCtrlFlags.IndivOutChLev) {
							channels[chNum].outLevels[1] = channels[chNum].masterBal * channels[chNum].masterBal;
						} else {
							channels[chNum].outLevels[0] = channels[chNum].masterVol - channels[chNum].masterBal;
							channels[chNum].outLevels[1] = channels[chNum].masterVol - (1.0 - channels[chNum].masterBal);
						}
						break;
					case ChannelParamNums.PLFO: 
						static if (is(T == uint)) {
							channels[chNum].pLFOlevel = cast(double)val / uint.max;
						} else static if (is(T == ubyte)) {
							if (type)
								paramTemp[2] = val;
							else
								paramTemp[3] = val;
							if (paramNum[0] == paramTemp[0] && paramNum[1] == paramTemp[1]) {	//Set parameter if  found.
								const uint val32 = paramTemp[3] | paramTemp[2]<<7;
								channels[chNum].pLFOlevel = cast(double)(val32) / cast(double)(ushort.max>>2);
							} else {		//Set temp for next command (assume MSB-LSB order)
								paramNum[0] = paramTemp[0];
								paramNum[1] = paramTemp[1];
							}
						}
						break;
					case ChannelParamNums.Release: 
						static if (is(T == uint)) {
							channels[chNum].relX = cast(ubyte)(val >> 25);
						} else static if (is(T == ubyte)) {
							channels[chNum].relX = val;
						}
						if (channels[chNum].relX) {
							channels[chNum].eeg.releaseRate = calculateRate(ADSR_TIME_TABLE[channels[chNum].relX] * 2, sampleRate);
						} else {
							channels[chNum].eeg.releaseRate = 1.0;
						}
						break;
					case ChannelParamNums.ShpA:
						static if (is(T == uint)) {
							channels[chNum].shpAX = cast(double)val / uint.max;
						} else static if (is(T == ubyte)) {
							if (type)
								paramTemp[2] = val;
							else
								paramTemp[3] = val;
							if (paramNum[0] == paramTemp[0] && paramNum[1] == paramTemp[1]) {	//Set parameter if  found.
								const uint val32 = paramTemp[3] | paramTemp[2]<<7;
								channels[chNum].shpAX = cast(double)(val32) / cast(double)(ushort.max>>2);
							} else {		//Set temp for next command (assume MSB-LSB order)
								paramNum[0] = paramTemp[0];
								paramNum[1] = paramTemp[1];
							}
						}
						break;
					case ChannelParamNums.ShpR:
						static if (is(T == uint)) {
							channels[chNum].shpRX = cast(double)val / uint.max;
						} else static if (is(T == ubyte)) {
							if (type)
								paramTemp[2] = val;
							else
								paramTemp[3] = val;
							if (paramNum[0] == paramTemp[0] && paramNum[1] == paramTemp[1]) {	//Set parameter if  found.
								const uint val32 = paramTemp[3] | paramTemp[2]<<7;
								channels[chNum].shpRX = cast(double)(val32) / cast(double)(ushort.max>>2);
							} else {		//Set temp for next command (assume MSB-LSB order)
								paramNum[0] = paramTemp[0];
								paramNum[1] = paramTemp[1];
							}
						}
						break;
					case ChannelParamNums.SusCtrl: 
						static if (is(T == uint)) {
							channels[chNum].susCCX = cast(ubyte)(val >> 25);
						} else static if (is(T == ubyte)) {
							channels[chNum].susCCX = val;
						}
						if (channels[chNum].susCCX) {
							channels[chNum].eeg.isPercussive = false;
							if (channels[chNum].susCCX == 64) {
								channels[chNum].eeg.sustainControl = 0.0;
							} else if (channels[chNum].susCCX < 64) {
								channels[chNum].eeg.sustainControl = -1.0 * 
										calculateRate(SUSTAIN_CONTROL_TIME_TABLE[channels[chNum].susCCX - 1], sampleRate);
							} else {
								channels[chNum].eeg.sustainControl = 
										calculateRate(SUSTAIN_CONTROL_TIME_TABLE[channels[chNum].susCCX - 64], sampleRate);
							}
						} else {
							channels[chNum].eeg.isPercussive = true;
							channels[chNum].eeg.sustainControl = 0.0;
						}
						break;
					case ChannelParamNums.SusLevel: 
						static if (is(T == uint)) {
							channels[chNum].eeg.sustainLevel = cast(double)val / uint.max;
						} else static if (is(T == ubyte)) {
							if (type)
								paramTemp[2] = val;
							else
								paramTemp[3] = val;
							if (paramNum[0] == paramTemp[0] && paramNum[1] == paramTemp[1]) {	//Set parameter if  found.
								const uint val32 = paramTemp[3] | paramTemp[2]<<7;
								channels[chNum].eeg.sustainLevel = cast(double)(val32) / cast(double)(ushort.max>>2);
							} else {		//Set temp for next command (assume MSB-LSB order)
								paramNum[0] = paramTemp[0];
								paramNum[1] = paramTemp[1];
							}
						}
						break;
					case ChannelParamNums.RingMod: 
						static if (is(T == uint)) {
							channels[chNum].rmAmount = val>>16;
						} else static if (is(T == ubyte)) {
							if (type)
								paramTemp[2] = val;
							else
								paramTemp[3] = val;
							if (paramNum[0] == paramTemp[0] && paramNum[1] == paramTemp[1]) {	//Set parameter if  found.
								const uint val32 = paramTemp[3] | paramTemp[2]<<7;
								channels[chNum].eeg.sustainLevel = val32<<2 | val32>>12;
							} else {		//Set temp for next command (assume MSB-LSB order)
								paramNum[0] = paramTemp[0];
								paramNum[1] = paramTemp[1];
							}
						}
						break;
					case ChannelParamNums.EEGToLeft:
						static if (is(T == uint)) {
							const double valF = cast(double)val / uint.max;
							channels[chNum].eegLevels[0] = valF * valF;
						} else static if (is(T == ubyte)) {
							if (type)
								paramTemp[2] = val;
							else
								paramTemp[3] = val;
							if (paramNum[0] == paramTemp[0] && paramNum[1] == paramTemp[1]) {	//Set parameter if  found.
								const uint val32 = paramTemp[3] | paramTemp[2]<<7;
								const double valF = cast(double)(val32) / cast(double)(ushort.max>>2);
								channels[chNum].eegLevels[0] = valF * valF;
							} else {		//Set temp for next command (assume MSB-LSB order)
								paramNum[0] = paramTemp[0];
								paramNum[1] = paramTemp[1];
							}
						}
						break;
					case ChannelParamNums.EEGToRight:
						static if (is(T == uint)) {
							const double valF = cast(double)val / uint.max;
							channels[chNum].eegLevels[1] = valF * valF;
						} else static if (is(T == ubyte)) {
							if (type)
								paramTemp[2] = val;
							else
								paramTemp[3] = val;
							if (paramNum[0] == paramTemp[0] && paramNum[1] == paramTemp[1]) {	//Set parameter if  found.
								const uint val32 = paramTemp[3] | paramTemp[2]<<7;
								const double valF = cast(double)(val32) / cast(double)(ushort.max>>2);
								channels[chNum].eegLevels[1] = valF * valF;
							} else {		//Set temp for next command (assume MSB-LSB order)
								paramNum[0] = paramTemp[0];
								paramNum[1] = paramTemp[1];
							}
						}
						break;
					case ChannelParamNums.EEGToAuxA:
						static if (is(T == uint)) {
							const double valF = cast(double)val / uint.max;
							channels[chNum].eegLevels[2] = valF * valF;
						} else static if (is(T == ubyte)) {
							if (type)
								paramTemp[2] = val;
							else
								paramTemp[3] = val;
							if (paramNum[0] == paramTemp[0] && paramNum[1] == paramTemp[1]) {	//Set parameter if  found.
								const uint val32 = paramTemp[3] | paramTemp[2]<<7;
								const double valF = cast(double)(val32) / cast(double)(ushort.max>>2);
								channels[chNum].eegLevels[2] = valF * valF;
							} else {		//Set temp for next command (assume MSB-LSB order)
								paramNum[0] = paramTemp[0];
								paramNum[1] = paramTemp[1];
							}
						}
						break;
					case ChannelParamNums.EEGToAuxB:
						static if (is(T == uint)) {
							const double valF = cast(double)val / uint.max;
							channels[chNum].eegLevels[3] = valF * valF;
						} else static if (is(T == ubyte)) {
							if (type)
								paramTemp[2] = val;
							else
								paramTemp[3] = val;
							if (paramNum[0] == paramTemp[0] && paramNum[1] == paramTemp[1]) {	//Set parameter if  found.
								const uint val32 = paramTemp[3] | paramTemp[2]<<7;
								const double valF = cast(double)(val32) / cast(double)(ushort.max>>2);
								channels[chNum].eegLevels[3] = valF * valF;
							} else {		//Set temp for next command (assume MSB-LSB order)
								paramNum[0] = paramTemp[0];
								paramNum[1] = paramTemp[1];
							}
						}
						break;
					case ChannelParamNums.LFOToLeft:
						static if (is(T == uint)) {
							const double valF = cast(double)val / uint.max;
							channels[chNum].aLFOlevels[0] = valF * valF;
						} else static if (is(T == ubyte)) {
							if (type)
								paramTemp[2] = val;
							else
								paramTemp[3] = val;
							if (paramNum[0] == paramTemp[0] && paramNum[1] == paramTemp[1]) {	//Set parameter if  found.
								const uint val32 = paramTemp[3] | paramTemp[2]<<7;
								const double valF = cast(double)(val32) / cast(double)(ushort.max>>2);
								channels[chNum].aLFOlevels[0] = valF * valF;
							} else {		//Set temp for next command (assume MSB-LSB order)
								paramNum[0] = paramTemp[0];
								paramNum[1] = paramTemp[1];
							}
						}
						break;
					case ChannelParamNums.LFOToRight:
						static if (is(T == uint)) {
							const double valF = cast(double)val / uint.max;
							channels[chNum].aLFOlevels[1] = valF * valF;
						} else static if (is(T == ubyte)) {
							if (type)
								paramTemp[2] = val;
							else
								paramTemp[3] = val;
							if (paramNum[0] == paramTemp[0] && paramNum[1] == paramTemp[1]) {	//Set parameter if  found.
								const uint val32 = paramTemp[3] | paramTemp[2]<<7;
								const double valF = cast(double)(val32) / cast(double)(ushort.max>>2);
								channels[chNum].aLFOlevels[1] = valF * valF;
							} else {		//Set temp for next command (assume MSB-LSB order)
								paramNum[0] = paramTemp[0];
								paramNum[1] = paramTemp[1];
							}
						}
						break;
					case ChannelParamNums.LFOToAuxA:
						static if (is(T == uint)) {
							const double valF = cast(double)val / uint.max;
							channels[chNum].aLFOlevels[2] = valF * valF;
						} else static if (is(T == ubyte)) {
							if (type)
								paramTemp[2] = val;
							else
								paramTemp[3] = val;
							if (paramNum[0] == paramTemp[0] && paramNum[1] == paramTemp[1]) {	//Set parameter if  found.
								const uint val32 = paramTemp[3] | paramTemp[2]<<7;
								const double valF = cast(double)(val32) / cast(double)(ushort.max>>2);
								channels[chNum].aLFOlevels[2] = valF * valF;
							} else {		//Set temp for next command (assume MSB-LSB order)
								paramNum[0] = paramTemp[0];
								paramNum[1] = paramTemp[1];
							}
						}
						break;
					case ChannelParamNums.LFOToAuxB:
						static if (is(T == uint)) {
							const double valF = cast(double)val / uint.max;
							channels[chNum].aLFOlevels[3] = valF * valF;
						} else static if (is(T == ubyte)) {
							if (type)
								paramTemp[2] = val;
							else
								paramTemp[3] = val;
							if (paramNum[0] == paramTemp[0] && paramNum[1] == paramTemp[1]) {	//Set parameter if  found.
								const uint val32 = paramTemp[3] | paramTemp[2]<<7;
								const double valF = cast(double)(val32) / cast(double)(ushort.max>>2);
								channels[chNum].aLFOlevels[3] = valF * valF;
							} else {		//Set temp for next command (assume MSB-LSB order)
								paramNum[0] = paramTemp[0];
								paramNum[1] = paramTemp[1];
							}
						}
						break;
					default:
						break;
				}
				break;
			case 16:		//LFO and master filter settings
				void setFilterFreq(int num) @nogc @safe pure nothrow {
					static if (is(T == uint)) {
						const double valF = cast(double)val / uint.max;
						filterCtrl[num] = valF * valF * 22_000;
					} else static if (is(T == ubyte)) {
						if (type)
							paramTemp[2] = val;
						else
							paramTemp[3] = val;
						if (paramNum[0] == paramTemp[0] && paramNum[1] == paramTemp[1]) {	//Set parameter if  found.
							const uint val32 = paramTemp[3] | paramTemp[2]<<7;
							const double valF = cast(double)(val32) / cast(double)(ushort.max>>2);
							filterCtrl[num] = valF * valF * 22_000;
						} else {		//Set temp for next command (assume MSB-LSB order)
							paramNum[0] = paramTemp[0];
							paramNum[1] = paramTemp[1];
						}
					}
				}
				void setFilterQ(int num) @nogc @safe pure nothrow {
					static if (is(T == uint)) {
						const double valF = cast(double)val / uint.max;
						filterCtrl[num] = valF * 2;
					} else static if (is(T == ubyte)) {
						if (type)
							paramTemp[2] = val;
						else
							paramTemp[3] = val;
						if (paramNum[0] == paramTemp[0] && paramNum[1] == paramTemp[1]) {	//Set parameter if  found.
							const uint val32 = paramTemp[3] | paramTemp[2]<<7;
							const double valF = cast(double)(val32) / cast(double)(ushort.max>>2);
							filterCtrl[num] = valF * 2;
						} else {		//Set temp for next command (assume MSB-LSB order)
							paramNum[0] = paramTemp[0];
							paramNum[1] = paramTemp[1];
						}
					}
				}
				switch (paramNum[0]) {
					case GlobalParamNums.PLFORate:
						double valF;
						static if (is(T == uint)) {
							valF = cast(double)val / uint.max;
						} else static if (is(T == ubyte)) {
							if (type)
								paramTemp[2] = val;
							else
								paramTemp[3] = val;
							if (paramNum[0] == paramTemp[0] && paramNum[1] == paramTemp[1]) {	//Set parameter if  found.
								const uint val32 = paramTemp[3] | paramTemp[2]<<7;
								valF = cast(double)(val32) / cast(double)(ushort.max>>2);
							} else {		//Set temp for next command (assume MSB-LSB order)
								paramNum[0] = paramTemp[0];
								paramNum[1] = paramTemp[1];
								return;
							}
						}
						valF *= 16;
						const double cycleLen = sampleRate / (1.0 / valF);
						pLFORate = cast(int)(cycleLen * ((1<<20) / 1024.0));
						break;
					case GlobalParamNums.PLFOWF:
						static if (is(T == uint)) {
							lfoWaveform[0] = cast(ubyte)(val >> 25);
						} else static if (is(T == ubyte)) {
							lfoWaveform[0] = val;
						}
						break;
					case GlobalParamNums.ALFORate:
						double valF;
						static if (is(T == uint)) {
							valF = cast(double)val / uint.max;
						} else static if (is(T == ubyte)) {
							if (type)
								paramTemp[2] = val;
							else
								paramTemp[3] = val;
							if (paramNum[0] == paramTemp[0] && paramNum[1] == paramTemp[1]) {	//Set parameter if  found.
								const uint val32 = paramTemp[3] | paramTemp[2]<<7;
								valF = cast(double)(val32) / cast(double)(ushort.max>>2);
							} else {		//Set temp for next command (assume MSB-LSB order)
								paramNum[0] = paramTemp[0];
								paramNum[1] = paramTemp[1];
								return;
							}
						}
						valF *= 16;
						const double cycleLen = sampleRate / (1.0 / valF);
						aLFORate = cast(int)(cycleLen * ((1<<20) / 1024.0));
						break;
					case GlobalParamNums.ALFOWF:
						static if (is(T == uint)) {
							lfoWaveform[1] = cast(ubyte)(val >> 25);
						} else static if (is(T == ubyte)) {
							lfoWaveform[1] = val;
						}
						break;
					case GlobalParamNums.FilterLCFreq:
						setFilterFreq(0);
						break;
					case GlobalParamNums.FilterLCQ: 
						setFilterQ(1);
						break;
					case GlobalParamNums.FilterRCFreq: 
						setFilterFreq(2);
						break;
					case GlobalParamNums.FilterRCQ: 
						setFilterQ(3);
						break;
					case GlobalParamNums.FilterACFreq:
						setFilterFreq(4);
						break;
					case GlobalParamNums.FilterACQ: 
						setFilterQ(5);
						break;
					case GlobalParamNums.FilterBCFreq: 
						setFilterFreq(6);
						break;
					case GlobalParamNums.FilterBCQ: 
						setFilterQ(7);
						break;
					default:
						break;
				}
				break;
			default: break;
		}
	}
	///Updates an operator for a cycle
	///chCtrl index notation: 0: velocity, 1: modulation wheel, 2: Amplitude LFO, 3: Extra Envelop Generator
	pragma(inline, true)
	protected final void updateOperator(ref Operator op, __m128 chCtrl) @nogc @safe pure nothrow {
		op.output = wavetables[op.opCtrl & Operator.OpCtrlFlags.WavetableSelect][(op.pos>>20 + op.input>>4 + op.feedback>>3) 
				& 0x3_FF];
		const double egOut = op.eg.shp(op.eg.position == ADSREnvelopGenerator.Stage.Attack ? op.shpA0 : op.shpR0);
		const double out0 = op.output;
		__m128 outCtrl = (op.outLCtrl * chCtrl) + (__m128(1.0) - (__m128(1.0) * op.outLCtrl));
		__m128 fbCtrl = (op.fbLCtrl * chCtrl) + (__m128(1.0) - (__m128(1.0) * op.fbLCtrl));
		const double out1 = out0 * egOut;
		//vel = op.opCtrl & Operator.OpCtrlFlags.VelNegative ? 1.0 - vel : vel;
		op.feedback = cast(int)((op.opCtrl & Operator.OpCtrlFlags.FBMode ? out0 : out1) * op.fbL * fbCtrl[0] * fbCtrl[1] * 
				fbCtrl[2] * fbCtrl[3]);
		//op.feedback *= op.opCtrl & Operator.OpCtrlFlags.FBNeg ? -1 : 1;
		op.output_0 = cast(int)(out1 * op.outL * outCtrl[0] * outCtrl[1] * outCtrl[2]);
		op.pos += op.step;
		//op.input = 0;
		op.eg.advance();
	}
	///Macro for channel update constants that need to be calculated once per frame
	///Kept in at one place to make updates easier and more consistent
	static immutable string CHNL_UPDATE_CONSTS =
		`const int opOffset = chNum * 2;` ~
		`__m128 aLFOOutMW = __m128(channels[chNum].chCtrl & Channel.ChCtrlFlags.MWToTrem ? chCtrls[chNum].modwheel : 1.0);` ~
		`const float auxSendAmMW = (channels[chNum].chCtrl & Channel.ChCtrlFlags.MWToAux ? chCtrls[chNum].modwheel : 1.0);` ~
		`__m128 opCtrl0, opCtrl1, mwAuxCtrl;` ~
		`opCtrl0[0] = operators[opOffset].opCtrl & Operator.OpCtrlFlags.VelNeg ? 1 - chCtrls[chNum].velocity : ` ~
				`chCtrls[chNum].velocity;` ~
		`opCtrl1[0] = operators[opOffset + 1].opCtrl & Operator.OpCtrlFlags.VelNeg ? 1 - chCtrls[chNum].velocity : ` ~
				`chCtrls[chNum].velocity;` ~
		`opCtrl0[1] = operators[opOffset].opCtrl & Operator.OpCtrlFlags.MWNeg ? 1 - chCtrls[chNum].modwheel : ` ~
				`chCtrls[chNum].modwheel;` ~
		`opCtrl1[1] = operators[opOffset + 1].opCtrl & Operator.OpCtrlFlags.MWNeg ? 1 - chCtrls[chNum].modwheel : ` ~
				`chCtrls[chNum].modwheel;` ~
		`mwAuxCtrl[0] = 1.0;` ~
		`mwAuxCtrl[1] = 1.0;` ~
		`mwAuxCtrl[2] = auxSendAmMW;` ~
		`mwAuxCtrl[3] = auxSendAmMW;` ~
		`const float lfopan = (channels[chNum].chCtrl & Channel.ChCtrlFlags.LFOPan ? 1.0 : 0);` ~
		`const float eegpan = (channels[chNum].chCtrl & Channel.ChCtrlFlags.EEGPan ? 1.0 : 0);`
		;
	///Macro for channel update constants that need to be calculated once per frame, for combined channels' second half
	///Kept in at one place to make updates easier and more consistent
	static immutable string CHNL_UPDATE_CONSTS0 =
		`__m128 opCtrl2, opCtrl3;` ~
		`opCtrl2[0] = operators[opOffset + 16].opCtrl & Operator.OpCtrlFlags.VelNeg ? 1 - chCtrls[chNum].velocity : ` ~
				`chCtrls[chNum].velocity;` ~
		`opCtrl3[0] = operators[opOffset + 17].opCtrl & Operator.OpCtrlFlags.VelNeg ? 1 - chCtrls[chNum].velocity : ` ~
				`chCtrls[chNum].velocity;` ~
		`opCtrl2[1] = operators[opOffset + 16].opCtrl & Operator.OpCtrlFlags.MWNeg ? 1 - chCtrls[chNum].modwheel : ` ~
				`chCtrls[chNum].modwheel;` ~
		`opCtrl3[1] = operators[opOffset + 17].opCtrl & Operator.OpCtrlFlags.MWNeg ? 1 - chCtrls[chNum].modwheel : ` ~
				`chCtrls[chNum].modwheel;` ~
		`const float eegpan0 = (channels[chNum + 8].chCtrl & Channel.ChCtrlFlags.EEGPan ? 1.0 : 0);`
		;
	///Macro for channel update constants that need to be calculated for each cycle
	///Kept in at one place to make updates easier and more consistent
	static immutable string CHNL_UPDATE_CONSTS_CYCL = 
		`const float eegOut = channels[chNum].eeg.shp(channels[chNum].eeg.position == ADSREnvelopGenerator.Stage.Attack ? ` ~
				`channels[chNum].shpAX : channels[chNum].shpRX);` ~
		`__m128 eegToMast = __m128(eegOut), lfoToMast = __m128(aLFOBuf[i]);` ~
		`eegToMast[0] = abs(eegpan - eegToMast[0]);` ~
		`lfoToMast[0] = abs(lfopan - lfoToMast[0]);` ~
		`opCtrl0[2] = aLFOBuf[i];` ~
		`opCtrl1[2] = aLFOBuf[i];` ~
		`opCtrl0[3] = eegOut;` ~
		`opCtrl1[3] = eegOut;`
		;
	
	///Macro for channel update constants that need to be calculated for each cycle for combined channels' second half
	///Kept in at one place to make updates easier and more consistent
	static immutable string CHNL_UPDATE_CONSTS_CYCL0 = 
		`const float eegOut0 = channels[chNum + 8].eeg.shp(channels[chNum + 8].eeg.position == ` ~
				`ADSREnvelopGenerator.Stage.Attack ? channels[chNum + 8].shpAX : channels[chNum + 8].shpRX);` ~
		`__m128 eegToMast0 = __m128(eegOut0);` ~
		`eegToMast0[0] = abs(eegpan0 - eegToMast0[0]);` ~
		`opCtrl2[2] = aLFOBuf[i];` ~
		`opCtrl3[2] = aLFOBuf[i];` ~
		`opCtrl2[3] = eegOut0;` ~
		`opCtrl3[3] = eegOut0;`
		;
			
	///Macro for output mixing
	static immutable string CHNL_UPDATE_MIX =
		"__m128 outlevels = channels[chNum].outLevels * mwAuxCtrl;" ~
		"outlevels *= (channels[chNum].eegLevels * eegToMast) + (__m128(1.0) - (__m128(1.0) * channels[chNum].eegLevels));" ~
		"outlevels *= (channels[chNum].aLFOlevels * lfoToMast) + (__m128(1.0) - (__m128(1.0) * channels[chNum].aLFOlevels));"~
		"_mm_store1_ps(initBuffers.ptr + (i<<2), _mm_load_ps(initBuffers.ptr + (i<<2)) + outlevels *" ~ 
		"		_mm_cvtepi32_ps(outSum));"
		;
	///Macro for output mixing in case of combo modes
	static immutable string CHNL_UPDATE_MIX0 =
		"__m128 outlevels = channels[chNum].outLevels * mwAuxCtrl;" ~
		"outlevels *= (channels[chNum].eegLevels * eegToMast) + (__m128(1.0) - (__m128(1.0) * channels[chNum].eegLevels));" ~
		"outlevels *= (channels[chNum + 8].eegLevels * eegToMast0) + (__m128(1.0) - " ~
		" (__m128(1.0) * channels[chNum + 8].eegLevels));" ~
		"outlevels *= (channels[chNum].aLFOlevels * lfoToMast) + (__m128(1.0) - (__m128(1.0) * channels[chNum].aLFOlevels));"~
		"_mm_store1_ps(initBuffers.ptr + (i<<2), _mm_load_ps(initBuffers.ptr + (i<<2)) + outlevels *" ~ 
		"		_mm_cvtepi32_ps(outSum));"
		;
	

	///Algorithm Mode 0/0 (Serial)
	protected void updateChannelM00(int chNum, size_t length) @nogc pure nothrow {
		mixin(CHNL_UPDATE_CONSTS);
		for (size_t i ; i < length ; i++) {
			mixin(CHNL_UPDATE_CONSTS_CYCL);
			updateOperator(operators[opOffset], opCtrl0);
			operators[opOffset + 1].input = operators[opOffset].output_0;
			updateOperator(operators[opOffset + 1], opCtrl1);
			//const int outSum = operators[opOffset].output_0;
			__m128i outSum = __m128i(operators[opOffset + 1].output_0);
			mixin(CHNL_UPDATE_MIX);
			channels[chNum].eeg.advance();
		}
	}
	///Algorithm Mode0/1 (Parallel)
	protected void updateChannelM01(int chNum, size_t length) @nogc pure nothrow {
		mixin(CHNL_UPDATE_CONSTS);
		for (size_t i ; i < length ; i++) {
			mixin(CHNL_UPDATE_CONSTS_CYCL);
			updateOperator(operators[opOffset], opCtrl0);
			updateOperator(operators[opOffset + 1], opCtrl1);
			//const int outSum = operators[opOffset].output_0 + operators[opOffset + 1].output_0;
			__m128i outSum = __m128i(operators[opOffset].output_0 + operators[opOffset + 1].output_0 + 
					((operators[opOffset].output_0 * operators[opOffset + 1].output)>>16 * channels[chNum].rmAmount)>>16);
			mixin(CHNL_UPDATE_MIX);
			channels[chNum].eeg.advance();
		}
	}
	///Algorithm Mode1/00 ([S0]->[S1]->[P0]->[P1])
	protected void updateChannelM100(int chNum, size_t length) @nogc pure nothrow {
		mixin(CHNL_UPDATE_CONSTS);
		mixin(CHNL_UPDATE_CONSTS0);
		for (size_t i ; i < length ; i++) {
			mixin(CHNL_UPDATE_CONSTS_CYCL);
			mixin(CHNL_UPDATE_CONSTS_CYCL0);
			updateOperator(operators[opOffset + 16], opCtrl2);	//S0
			operators[opOffset + 17].input = operators[opOffset + 16].output_0;
			updateOperator(operators[opOffset + 17], opCtrl3);	//S1
			operators[opOffset].input = operators[opOffset + 17].output_0;
			updateOperator(operators[opOffset], opCtrl0);		//P0
			operators[opOffset + 1].input = operators[opOffset].output_0;
			updateOperator(operators[opOffset + 1], opCtrl1);	//P1
			//const int outSum = operators[opOffset + 1].output_0;
			__m128i outSum = __m128i(operators[opOffset + 1].output_0);
			mixin(CHNL_UPDATE_MIX);
			channels[chNum].eeg.advance();
			channels[chNum + 8].eeg.advance();
		}
	}
	///Dummy algorithm for combined channels
	protected void updateChannelMD(int chNum, size_t length) @nogc pure nothrow {

	}
	/**
	Algorithm Mode1/10
	[S0]\
    	 ->[P0]->[P1]->
	[S1]/
	*/
	protected void updateChannelM110(int chNum, size_t length) @nogc pure nothrow {
		mixin(CHNL_UPDATE_CONSTS);
		mixin(CHNL_UPDATE_CONSTS0);
		for (size_t i ; i < length ; i++) {
			mixin(CHNL_UPDATE_CONSTS_CYCL);
			mixin(CHNL_UPDATE_CONSTS_CYCL0);
			updateOperator(operators[opOffset + 16], opCtrl2);	//S0
			//operators[opOffset + 17].input = operators[opOffset + 16].output_0;
			updateOperator(operators[opOffset + 17], opCtrl3);	//S1
			operators[opOffset].input = operators[opOffset + 17].output_0 + operators[opOffset + 16].output_0;
			updateOperator(operators[opOffset], opCtrl0);		//P0
			operators[opOffset + 1].input = operators[opOffset].output_0;
			updateOperator(operators[opOffset + 1], opCtrl1);	//P1
			//const int outSum = operators[opOffset + 1].output_0;
			__m128i outSum = __m128i(operators[opOffset + 1].output_0);
			mixin(CHNL_UPDATE_MIX);
			channels[chNum].eeg.advance();
			channels[chNum + 8].eeg.advance();
		}
	}
	/**
	Algorithm Mode1/01
	[S0]->[S1]->[P0]->
            	[P1]->
	*/
	protected void updateChannelM101(int chNum, size_t length) @nogc pure nothrow {
		mixin(CHNL_UPDATE_CONSTS);
		mixin(CHNL_UPDATE_CONSTS0);
		for (size_t i ; i < length ; i++) {
			mixin(CHNL_UPDATE_CONSTS_CYCL);
			mixin(CHNL_UPDATE_CONSTS_CYCL0);
			updateOperator(operators[opOffset + 16], opCtrl2);	//S0
			operators[opOffset + 17].input = operators[opOffset + 16].output_0;
			updateOperator(operators[opOffset + 17], opCtrl3);	//S1
			operators[opOffset].input = operators[opOffset + 17].output_0;
			updateOperator(operators[opOffset], opCtrl0);		//P0
			//operators[opOffset + 1].input = operators[opOffset].output_0;
			updateOperator(operators[opOffset + 1], opCtrl1);	//P1
			//const int outSum = operators[opOffset + 1].output_0;
			__m128i outSum = __m128i(operators[opOffset].output_0 + operators[opOffset + 1].output_0 + 
					((operators[opOffset].output_0 * operators[opOffset + 1].output)>>16 * channels[chNum].rmAmount)>>16);
			mixin(CHNL_UPDATE_MIX);
			channels[chNum].eeg.advance();
			channels[chNum + 8].eeg.advance();
		}
	}
	/**
	Algorithm Mode1/11
	[S0]\
    	 ->[P0]->
	[S1]/  [P1]->
	*/
	protected void updateChannelM111(int chNum, size_t length) @nogc pure nothrow {
		mixin(CHNL_UPDATE_CONSTS);
		mixin(CHNL_UPDATE_CONSTS0);
		for (size_t i ; i < length ; i++) {
			mixin(CHNL_UPDATE_CONSTS_CYCL);
			mixin(CHNL_UPDATE_CONSTS_CYCL0);
			updateOperator(operators[opOffset + 16], opCtrl2);	//S0
			//operators[opOffset + 17].input = operators[opOffset + 16].output_0;
			updateOperator(operators[opOffset + 17], opCtrl3);	//S1
			operators[opOffset].input = operators[opOffset + 17].output_0 + operators[opOffset + 16].output_0;
			updateOperator(operators[opOffset], opCtrl0);		//P0
			//operators[opOffset + 1].input = operators[opOffset].output_0;
			updateOperator(operators[opOffset + 1], opCtrl1);	//P1
			//const int outSum = operators[opOffset + 1].output_0;
			__m128i outSum = __m128i(operators[opOffset].output_0 + operators[opOffset + 1].output_0 + 
					((operators[opOffset].output_0 * operators[opOffset + 1].output)>>16 * channels[chNum].rmAmount)>>16);
			mixin(CHNL_UPDATE_MIX);
			channels[chNum].eeg.advance();
			channels[chNum + 8].eeg.advance();
		}
	}
	/**
	Algorithm Mode2/00
	[S0]->[S1]\
	           ->[P1]->
    	  [P0]/
	*/
	protected void updateChannelM200(int chNum, size_t length) @nogc pure nothrow {
		mixin(CHNL_UPDATE_CONSTS);
		mixin(CHNL_UPDATE_CONSTS0);
		for (size_t i ; i < length ; i++) {
			mixin(CHNL_UPDATE_CONSTS_CYCL);
			mixin(CHNL_UPDATE_CONSTS_CYCL0);
			updateOperator(operators[opOffset + 16], opCtrl2);	//S0
			operators[opOffset + 17].input = operators[opOffset + 16].output_0;
			updateOperator(operators[opOffset + 17], opCtrl3);	//S1
			//operators[opOffset].input = operators[opOffset + 17].output_0;
			updateOperator(operators[opOffset], opCtrl0);		//P0
			operators[opOffset + 1].input = operators[opOffset].output_0 + operators[opOffset + 17].output_0;
			updateOperator(operators[opOffset + 1], opCtrl1);	//P1
			//const int outSum = operators[opOffset + 1].output_0;
			__m128i outSum = __m128i(operators[opOffset + 1].output_0);
			mixin(CHNL_UPDATE_MIX);
			channels[chNum].eeg.advance();
			channels[chNum + 8].eeg.advance();
		}
	}
	/**
	Algorithm Mode2/10
	[S0]\
	[S1]-->[P1]->
	[P0]/
	*/
	protected void updateChannelM210(int chNum, size_t length) @nogc pure nothrow {
		mixin(CHNL_UPDATE_CONSTS);
		mixin(CHNL_UPDATE_CONSTS0);
		for (size_t i ; i < length ; i++) {
			mixin(CHNL_UPDATE_CONSTS_CYCL);
			mixin(CHNL_UPDATE_CONSTS_CYCL0);
			updateOperator(operators[opOffset + 16], opCtrl2);	//S0
			//operators[opOffset + 17].input = operators[opOffset + 16].output_0;
			updateOperator(operators[opOffset + 17], opCtrl3);	//S1
			//operators[opOffset].input = operators[opOffset + 17].output_0;
			updateOperator(operators[opOffset], opCtrl0);		//P0
			operators[opOffset + 1].input = operators[opOffset].output_0 + operators[opOffset + 17].output_0 + 
					operators[opOffset + 16].output_0;
			updateOperator(operators[opOffset + 1], opCtrl1);	//P1
			//const int outSum = operators[opOffset + 1].output_0;
			__m128i outSum = __m128i(operators[opOffset + 1].output_0);
			mixin(CHNL_UPDATE_MIX);
			channels[chNum].eeg.advance();
			channels[chNum + 8].eeg.advance();
		}
	}
	/**
	Algorithm Mode2/01
	          /[P0]->
	[S0]->[S1]
    	      \[P1]->
	*/
	protected void updateChannelM201(int chNum, size_t length) @nogc pure nothrow {
		mixin(CHNL_UPDATE_CONSTS);
		mixin(CHNL_UPDATE_CONSTS0);
		for (size_t i ; i < length ; i++) {
			mixin(CHNL_UPDATE_CONSTS_CYCL);
			mixin(CHNL_UPDATE_CONSTS_CYCL0);
			updateOperator(operators[opOffset + 16], opCtrl2);	//S0
			operators[opOffset + 17].input = operators[opOffset + 16].output_0;
			updateOperator(operators[opOffset + 17], opCtrl3);	//S1
			operators[opOffset].input = operators[opOffset + 17].output_0;
			updateOperator(operators[opOffset], opCtrl0);		//P0
			operators[opOffset + 1].input = operators[opOffset + 17].output_0;
			updateOperator(operators[opOffset + 1], opCtrl1);	//P1
			//const int outSum = operators[opOffset + 1].output_0;
			__m128i outSum = __m128i(operators[opOffset + 1].output_0 + operators[opOffset].output_0 + 
					((operators[opOffset].output_0 * operators[opOffset + 1].output)>>16 * channels[chNum].rmAmount)>>16);
			mixin(CHNL_UPDATE_MIX);
			channels[chNum].eeg.advance();
			channels[chNum + 8].eeg.advance();
		}
	}
	/**
	Algorithm Mode2/11
	[S0]\ /[P0]->
	     -
	[S1]/ \[P1]->
	*/
	protected void updateChannelM211(int chNum, size_t length) @nogc pure nothrow {
		mixin(CHNL_UPDATE_CONSTS);
		mixin(CHNL_UPDATE_CONSTS0);
		for (size_t i ; i < length ; i++) {
			mixin(CHNL_UPDATE_CONSTS_CYCL);
			mixin(CHNL_UPDATE_CONSTS_CYCL0);
			updateOperator(operators[opOffset + 16], opCtrl2);	//S0
			//operators[opOffset + 17].input = operators[opOffset + 16].output_0;
			updateOperator(operators[opOffset + 17], opCtrl3);	//S1
			operators[opOffset].input = operators[opOffset + 17].output_0 + operators[opOffset + 16].output_0;
			updateOperator(operators[opOffset], opCtrl0);		//P0
			operators[opOffset + 1].input = operators[opOffset + 17].output_0 + operators[opOffset + 16].output_0;
			updateOperator(operators[opOffset + 1], opCtrl1);	//P1
			//const int outSum = operators[opOffset + 1].output_0;
			__m128i outSum = __m128i(operators[opOffset + 1].output_0 + operators[opOffset].output_0 + 
					((operators[opOffset].output_0 * operators[opOffset + 1].output)>>16 * channels[chNum].rmAmount)>>16);
			mixin(CHNL_UPDATE_MIX);
			channels[chNum].eeg.advance();
			channels[chNum + 8].eeg.advance();
		}
	}
	/**
	Algorithm Mode3/00
	[S0]->[S1]->
	[P0]->[P1]->
	*/
	protected void updateChannelM300(int chNum, size_t length) @nogc pure nothrow {
		mixin(CHNL_UPDATE_CONSTS);
		mixin(CHNL_UPDATE_CONSTS0);
		for (size_t i ; i < length ; i++) {
			mixin(CHNL_UPDATE_CONSTS_CYCL);
			mixin(CHNL_UPDATE_CONSTS_CYCL0);
			updateOperator(operators[opOffset + 16], opCtrl2);	//S0
			operators[opOffset + 17].input = operators[opOffset + 16].output_0;
			updateOperator(operators[opOffset + 17], opCtrl3);	//S1
			//operators[opOffset].input = operators[opOffset + 17].output_0;
			updateOperator(operators[opOffset], opCtrl0);		//P0
			operators[opOffset + 1].input = operators[opOffset].output_0;
			updateOperator(operators[opOffset + 1], opCtrl1);	//P1
			//const int outSum = operators[opOffset + 1].output_0;
			__m128i outSum = __m128i(operators[opOffset + 1].output_0 + operators[opOffset + 17].output_0 + 
					((operators[opOffset + 1].output_0 * operators[opOffset + 17].output)>>16 * channels[chNum].rmAmount)>>16);
			mixin(CHNL_UPDATE_MIX);
			channels[chNum].eeg.advance();
			channels[chNum + 8].eeg.advance();
		}
	}
	/**
	Algorithm Mode3/10
	      [S0]->
    	  [S1]->
	[P0]->[P1]->
	*/
	protected void updateChannelM310(int chNum, size_t length) @nogc pure nothrow {
		mixin(CHNL_UPDATE_CONSTS);
		mixin(CHNL_UPDATE_CONSTS0);
		for (size_t i ; i < length ; i++) {
			mixin(CHNL_UPDATE_CONSTS_CYCL);
			mixin(CHNL_UPDATE_CONSTS_CYCL0);
			updateOperator(operators[opOffset + 16], opCtrl2);	//S0
			//operators[opOffset + 17].input = operators[opOffset + 16].output_0;
			updateOperator(operators[opOffset + 17], opCtrl3);	//S1
			//operators[opOffset].input = operators[opOffset + 17].output_0;
			updateOperator(operators[opOffset], opCtrl0);		//P0
			operators[opOffset + 1].input = operators[opOffset].output_0;
			updateOperator(operators[opOffset + 1], opCtrl1);	//P1
			//const int outSum = operators[opOffset + 1].output_0;
			__m128i outSum = __m128i(operators[opOffset + 1].output_0 + operators[opOffset + 17].output_0 + 
					operators[opOffset + 16].output_0 + 
					((operators[opOffset + 1].output_0 * operators[opOffset + 17].output)>>16 * channels[chNum].rmAmount)>>16);
			mixin(CHNL_UPDATE_MIX);
			channels[chNum].eeg.advance();
			channels[chNum + 8].eeg.advance();
		}
	}
	/**
	Algorithm Mode3/01
	    />[S1]->
	[S0]->[P0]->
    	\>[P1]->
	*/
	protected void updateChannelM301(int chNum, size_t length) @nogc pure nothrow {
		mixin(CHNL_UPDATE_CONSTS);
		mixin(CHNL_UPDATE_CONSTS0);
		for (size_t i ; i < length ; i++) {
			mixin(CHNL_UPDATE_CONSTS_CYCL);
			mixin(CHNL_UPDATE_CONSTS_CYCL0);
			updateOperator(operators[opOffset + 16], opCtrl2);	//S0
			operators[opOffset + 17].input = operators[opOffset + 16].output_0;
			updateOperator(operators[opOffset + 17], opCtrl3);	//S1
			operators[opOffset].input = operators[opOffset + 16].output_0;
			updateOperator(operators[opOffset], opCtrl0);		//P0
			operators[opOffset + 1].input = operators[opOffset + 16].output_0;
			updateOperator(operators[opOffset + 1], opCtrl1);	//P1
			//const int outSum = operators[opOffset + 1].output_0;
			__m128i outSum = __m128i(operators[opOffset].output_0 + operators[opOffset + 1].output_0 + 
					operators[opOffset + 17].output_0 + 
					((operators[opOffset + 1].output_0 * operators[opOffset + 17].output)>>16 * channels[chNum].rmAmount)>>16);
			mixin(CHNL_UPDATE_MIX);
			channels[chNum].eeg.advance();
			channels[chNum + 8].eeg.advance();
		}
	}
	/**
	Algorithm Mode3/11
	[S0]->
	[S1]->
	[P0]->
	[P1]->
	*/
	protected void updateChannelM311(int chNum, size_t length) @nogc pure nothrow {
		mixin(CHNL_UPDATE_CONSTS);
		mixin(CHNL_UPDATE_CONSTS0);
		for (size_t i ; i < length ; i++) {
			mixin(CHNL_UPDATE_CONSTS_CYCL);
			mixin(CHNL_UPDATE_CONSTS_CYCL0);
			updateOperator(operators[opOffset + 16], opCtrl2);	//S0
			operators[opOffset + 17].input = operators[opOffset + 16].output_0;
			updateOperator(operators[opOffset + 17], opCtrl3);	//S1
			operators[opOffset].input = operators[opOffset + 17].output_0;
			updateOperator(operators[opOffset], opCtrl0);		//P0
			operators[opOffset + 1].input = operators[opOffset].output_0;
			updateOperator(operators[opOffset + 1], opCtrl1);	//P1
			//const int outSum = operators[opOffset + 1].output_0;
			__m128i outSum = __m128i(operators[opOffset].output_0 + operators[opOffset].output_0 +
					operators[opOffset + 17].output_0 + operators[opOffset + 16].output_0 + 
					((operators[opOffset + 1].output_0 * operators[opOffset + 17].output)>>16 * channels[chNum].rmAmount)>>16);
			mixin(CHNL_UPDATE_MIX);
			channels[chNum].eeg.advance();
			channels[chNum + 8].eeg.advance();
		}
	}
}