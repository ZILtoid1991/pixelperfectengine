module pixelperfectengine.audio.modules.qm816;

import pixelperfectengine.audio.base.modulebase;
import pixelperfectengine.audio.base.envgen;

import midi2.types.structs;
import midi2.types.enums;

import inteli.emmintrin;

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
	public static immutable float[62] SUSTAIN_CONTROL_TIME_TABLE = [
	//	0     |1     |2     |3     |4     |5     |6     |7     |8     |9     |A     |B     |C     |D     |E     |F
		60.00, 55.00, 50.00, 45.00, 42.50, 40.00, 38.50, 35.00, 32.50, 30.00, 27.50, 25.00, 24.00, 23.00, 22.00, 21.00,//0
		20.00, 19.00, 18.00, 17.50, 17.00, 16.50, 16.00, 15.50, 15.00, 14.50, 14.00, 13.50, 13.00, 12.50, 12.25, 12.00,//1
		11.75, 11.50, 11.25, 11.00, 10.75, 10.50, 10.25, 10.00, 9.750, 9.500, 9.250, 9.000, 8.750, 8.500, 8.250, 8.000,//2
		7.750, 7.500, 7.250, 7.000, 6.750, 6.500, 6.250, 6.000, 5.750, 5.500, 5.250, 5.000, 4.750, 4.500               //3
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
		FBMode		=	12,
		OpCtrl		=	13,
	}
	/**
	Defines channel parameter numbers, within the unregistered namespace.
	*/
	public enum ChannelParamNums {
		MasterVol	=	0,
		Bal			=	1,
		AuxLA		=	2,
		AuxLB		=	3,
		Attack		=	4,
		Decay		=	5,
		SusLevel	=	6,
		SusCtrl		=	7,
		Release		=	8,
		EEGDetune	=	9,
		ShpA		=	10,
		ShpR		=	11,
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
		///Bit 24-0: Fine detuning (0 to 100 cents)
		uint			tune	=	0x30_00_00_00;
		///Input register.
		///The amount which the oscillator will be offsetted.
		int				input;
		///Feedback register. Either out_0[n-1] or out[n-1] multiplied by feedback amount.
		///The amount which the oscillator will be offsetted.
		int				feedback;
		///Output register.
		///Not affected by either level or EG
		int				output;
		///Output level (between 0.0 and 1.0)
		float			outL	=	1.0;
		///Feedback level (between 0.0 and 1.0)
		float			fbL		=	0.0;
		///ADSR shaping parameter (for the attack phase)
		float			shpA	=	0.5;
		///ADSR shaping parameter (for the decay/release phase)
		float			shpR	=	0.5;
		///Output affected by EEG and level.
		///Either used for audible output, or to modulate other operators
		int				output_0;
		///Control flags and Wavetable selector
		uint			opCtrl;
		///Defines control values
		enum OpCtrlFlags {
			WavetableSelect	=	127,		///Wavetable select flags
			FBMode			=	1 << 7,		///Feedback mode (L: After Envelop Generator, H: Before Envelop Generator)
			ALFOAssign		=	1 << 8,		///Assign Amplitude LFO to output level
			VelOLAssign		=	1 << 9,		///Assign velocity to output level
			VelFBAssign		=	1 << 10,	///Assign velocity to feedback level
			VelAtkAssign	=	1 << 11,	///Assign velocity to attack time
			VelSusAssign	=	1 << 12,	///Assign Velocity to sustain level
			VelAtkShp		=	1 << 13,	///Assign velocity to attack shape
			VelRelShp		=	1 << 14,	///Assign velocity to release shape
			VelNegative		=	1 << 15,	///Invert velocity control
			MWOLAssign		=	1 << 16,	///Assign modulation wheel to output level
			MWFBAssign		=	1 << 17,	///Assign modulation wheel to feedback level
			EEGFBAssign		=	1 << 18,	///Assign extra Envelop Generator to feedback
			EGRelAdaptive	=	1 << 19,	///Adaptive release time based on current output level
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
		///Amount of how much amplitude values must be affected by EEG
		float			eegAmpAmount;
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
			EEGVolAssign	=	1<<2,	///Assigns EEG to channel volume
			EEGBalAssign	=	1<<3,	///Assigns EEG to balance
			EEGALFOAssign	=	1<<4,	///Assigns EEG to amplitude LFO level
			EEGPLFOAssign	=	1<<5,	///Assigns EEG to pitch LFO level
			EEGAuxSendAssign=	1<<6,	///Assigns EEG to aux send levels
			ALFOVolAssign	=	1<<7,	///Assigns amplitude LFO to channel volume
			ALFOBalAssign	=	1<<8,	///Assigns amplitude LFO to balance
			ALFOAuxSendAssign=	1<<9,	///Assigns amplitude LFO to aux send levels
			VelCtrlVolAssign=	1<<10,	///Assigns velocity control to channel volume
			VelCtrlEEGDetAmA=	1<<11,	///Assigns velocity control to EEG detune amount
			VelCtrlReverse	=	1<<12,	///Reverses the velocity control value
			Algorithm		=	1<<13,	///Channel algorithm (H: Parallel, L: Series)
			MWPLFOAssign	=	1<<14,	///Modulation wheel to pitch LFO assign
			MWALFOAssign	=	1<<15,	///Modulation wheel to amplitude LFO assign
			MWAuxSendAssign	=	1<<16,	///Modulation wheel to aux send assign

		}
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
		///0: Percussive mode
		///1 - 63: Descending over time
		///64: Constant
		///65 - 127: Ascending over time
		ubyte			susCCX;
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
		///0: Percussive mode
		///1 - 63: Descending over time
		///64: Constant
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
	///Preset numbers per channels.
	protected ubyte[16]			presetNum;
	///Bank numbers per channels.
	protected ubyte[16]			bankNum;
	///Keeps the registered/unregistered parameter positions (LSB = 0).
	protected ubyte[2]			paramNum;
	///Stores LFO waveform selection.
	protected ubyte[2]			lfoWaveform;
	///Stores output filter values.
	///0: a0; 1: a1; 2: a2; 3: b0; 4: b1; 5: b2; 6: n-1; 7: n-2;
	protected __m128[8]			filterVals;
	///Mixing buffers
	///Output is directed there before filtering
	protected int[][4]			intBuffers;
	///Dummy buffer
	///Only used if one or more outputs haven't been defined
	protected float[]			dummyBuf;
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
			case 0:			//Pitch bend sensitivity
				//channels[chNum].pitchBendSens = 
				break;
			case 1:			//Channel master tuning (fine)
				break;
			case 2:			//Channel master tuning (coarse)
				break;
			default: break;
		}
	}
	/**
	Sets an unregistered parameter

	If type is not zero, then the MSB is being set, otherwise the LSB will be used
	*/
	protected void setUnregisteredParam(T)(T val, ubyte[2] paramNum, ubyte type, ubyte chNum) @nogc @safe pure nothrow {
		switch (paramNum[1]) {
			case 0:			//Channel operator 0

				break;
			case 1:			//Channel operator 1
				break;
			case 2:			//Channel common values
				break;
			case 16:		//LFO and master filter settings
				break;
			default: break;
		}
	}
	///Updates an operator for a cycle
	pragma(inline, true)
	protected final void updateOperator(ref Operator op, const float alfoIn, const float eegIn) @nogc @safe pure nothrow {
		op.output = wavetables[op.opCtrl & Operator.OpCtrlFlags.WavetableSelect][(op.pos>>20 + op.input>>4 + op.feedback>>3) 
				& 0x3_FF];
		const double egOut = op.eg.shpF(op.eg.position == ADSREnvelopGenerator.Stage.Attack ? op.shpA : op.shpR);
		const double out0 = op.output;
		const double out1 = out0 * egOut * (op.opCtrl & Operator.OpCtrlFlags.ALFOAssign ? alfoIn : 1.0);
		op.feedback = cast(int)((op.opCtrl & Operator.OpCtrlFlags.FBMode ? out0 : out1) * 
				(op.opCtrl & Operator.OpCtrlFlags.EEGFBAssign ? eegIn : 1.0));
		op.output_0 = cast(int)(out1 * op.outL);
		op.pos += op.step;

		op.eg.advance();
	}
}