module pixelperfectengine.audio.modules.delaylines;

import pixelperfectengine.audio.base.modulebase;
import pixelperfectengine.audio.base.types;
import pixelperfectengine.audio.base.envgen;
import pixelperfectengine.audio.base.func;
import pixelperfectengine.audio.base.envgen;
import pixelperfectengine.audio.base.osc;
import pixelperfectengine.system.etc : isPowerOf2;

import inteli.emmintrin;

import midi2.types.structs;
import midi2.types.enums;

/**
 * Implements a configurable delay line device, that can be used to create various time-based effects.
 * It contains:
 * * two delay lines
 * * four taps per delay line
 * * a short 8 element FIR per tap
 * * 4 filters per tap (3 with mix amount + 1 for feedback)
 * * 4 LFO globally
 * The module is controllable via MIDI CC commands.
 */
public class DelayLines : AudioModule {
	/** 
	 * Defines a delay line tap.
	 */
	protected struct Tap {
		uint		pos;		///Median position of the tap
		float		filterAm0;	///IIR0 mix amount
		float		filterAm1;	///IIR1 mix amount
		float		filterAm2;	///IIR2 mix amount
		__m128		outLevels	= __m128(0.0);///Output levels (0: Left; 1: Right, 2: Primary feedback, 3: Secondary feedback)
		__m128[2]	fir = [__m128(0.0),__m128(0.0)];///Short finite impulse response after tap
	}
	/**
	 * Defines an infinite response filter bank for various uses.
	 */
	protected struct IIRBank {
		///All initial values
		__m128		x1, x2, y1, y2, b0a0, b1a0, b2a0, a1a0, a2a0;
		///Calculates the output of the filter, then stores the input and output values.
		pragma (inline, true)
		__m128 output(__m128 x0) @nogc @safe pure nothrow {
			const __m128 y0 = b0a0 * x0 + b1a0 * x1 + b2a0 * x2 + a1a0 * y1 + a2a0 * y2;
			x2 = x1;
			x1 = x0;
			y2 = y1;
			y1 = y0;
			return y0;
		}
	}
	protected Tap[4][2]			taps;
	protected IIRBank[4][2]		filterBanks;
	protected float[][2]		delayLines;		///The two delay lines of the 
	protected MultiTapOsc[4]	osc;			///Oscillators to modify fix tap points
	protected size_t[2]			dLPos;			///Delay line positions
	protected size_t[2]			dLMod;			///Delay line modulo
	
	/**
	 * Creates an instance of this module using the supplied parameters.
	 * Params:
	 *   priLen = Primary buffer length. Must be power of two.
	 *   secLen = Secondary buffer length. Must be power of two.
	 */
	public this(size_t priLen, size_t secLen) {
		assert(isPowerOf2(priLen));
		assert(isPowerOf2(secLen) || !secLen);
		info.nOfAudioInput = 2;
		info.nOfAudioOutput = 2;
		info.inputChNames = ["inputA", "inputB"];
		info.outputChNames = ["mainL", "mainR"];
		info.hasMidiIn = true;
		delayLines[0].length = priLen;
		delayLines[1].length = secLen;
		dLMod[0] = priLen - 1;
		dLMod[1] = secLen - 1;
		resetBuffer(delayLines[0]);
		resetBuffer(delayLines[1]);
	}

	override public void midiReceive(UMP data0, uint data1 = 0, uint data2 = 0, uint data3 = 0) @nogc nothrow {
		
	}

	override public void renderFrame(float*[] input, float*[] output) @nogc nothrow {
		//function to read from the delay line
		__m128[2] readDL(int lineNum, uint pos) @nogc safe pure nothrow {
			__m128[2] result;
			for (int i ; i < 2 ; i++) {
				for (int j ; j < 4 ; j++) {
					result[i][j] = delayLines[lineNum][dLMod[lineNum] & (dLPos[lineNum] - pos - j - (i<<2))];
				}
			}
			return result;
		}
		dLPos[0]++;
		dLPos[1]++;
	}

	override public int waveformDataReceive(uint id, ubyte[] rawData, WaveFormat format) nothrow {
		return int.init; // TODO: implement
	}

	override public int writeParam_int(uint presetID, uint paramID, int value) nothrow {
		return int.init; // TODO: implement
	}

	override public int writeParam_long(uint presetID, uint paramID, long value) nothrow {
		return int.init; // TODO: implement
	}

	override public int writeParam_double(uint presetID, uint paramID, double value) nothrow {
		return int.init; // TODO: implement
	}

	override public int writeParam_string(uint presetID, uint paramID, string value) nothrow {
		return int.init; // TODO: implement
	}

	override public MValue[] getParameters() nothrow {
		return null; // TODO: implement
	}

	override public int readParam_int(uint presetID, uint paramID) nothrow {
		return int.init; // TODO: implement
	}

	override public long readParam_long(uint presetID, uint paramID) nothrow {
		return long.init; // TODO: implement
	}

	override public double readParam_double(uint presetID, uint paramID) nothrow {
		return double.init; // TODO: implement
	}

	override public string readParam_string(uint presetID, uint paramID) nothrow {
		return string.init; // TODO: implement
	}
}