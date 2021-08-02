module pixelperfectengine.audio.modules.qm816;

import pixelperfectengine.audio.base.modulebase;
import pixelperfectengine.audio.base.envgen;

/**
QM816 - implements a Quadrature-Amplitude synthesizer. This technique was used in early 
digital fM synths, since it allowed allowed a cheap implementation of the same thing as
long as the modulator was a sinusoidal waveform.

It has 16 2 operator channels that can be individually paired-up for 4 operator channels,
for more complex sounds. Also all operators have the option for feedback, including 
carriers. 2 operator channels have 2, 4 operator channels have 3*4 algorithms.

Before use, the synth needs to be supplied with a wavetable file, in 16 bit wav format,
with values between 0 and 4095.
*/
public class QM816 : ModuleBase {
	/**
	Implements a single operator.
	
	Contains an oscillator, an ADSR envelop generator, and locals.
	*/
	public struct Operator {
		///The envelop generator of the operator.
		ADSREnvGen		eg;
		///The current position of the oscillator, including fractions.
		uint			pos;	
		///The amount the oscillator must be stepped forward each cycle, including fractions.
		uint			step;
		///Operator tuning
		///Bit 31-25: Coarse detuning (-24 to +103 seminotes)
		///Bit 24-0: Fine detuning (0 to 100 cents)
		uint			tune;
		///Input register.
		///The amount which the oscillator will be offsetted.
		uint			input;
		///Feedback register. Either out_0[n-1] or out[n-1] multiplied by feedback amount.
		///The amount which the oscillator will be offsetted.
		uint			feedback;
		///Output register.
		///Not affected by either level or EG
		uint			output;
		///Output level (between 0.0 and 1.0)
		double			outL;
		///Feedback level (between 0.0 and 1.0)
		double			fbL;
		///ADSR shaping parameter (for the attack phase)
		double			shpA;
		///ADSR shaping parameter (for the decay/release phase)
		double			shpR;
		///Output affected by EEG and level.
		///Either used for audible output, or to modulate other operators
		uint			output_0;
		///Wavetable selector. Valid between 0 and 127.
		ubyte			wtSel;
		///Operator control flags
		ubyte			opCtrlFlags;
		///Controls feedback mode.
		///If set, the feedback is taken before it's affected by the EG.
		///If not, then it's taken after the EG.
		static immutable enum FB_MODE = 1 << 0;
		///If set, the amplitude LFO will control the output level.
		static immutable enum ALFO_EN = 1 << 1;
		///If set, the velocity will affect the output level.
		static immutable enum VEL_OL_EN = 1 << 2;
		///If set, the velocity will affect the feedback level.
		static immutable enum VEL_FBL_EN = 1 << 3;
	}
	/**
	Defines channel common parameters.
	*/
	public struct Channel {
		///Extra envelop generator that can be assigned for multiple purpose.
		ADSREnvGen		eeg;
	}
	///Contains the wavetables for the operators and LFOs.
	///Value mus be between 0 and 4095.
	protected ushort[1024][128]		wavetables;
}