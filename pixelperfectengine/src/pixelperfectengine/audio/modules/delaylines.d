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

import collections.treemap;

import std.bitmanip : bitfields;

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
		//uint		pos;		///Median position of the tap
		union {
			///used for preset save
			uint flags;
			mixin(bitfields!(
				bool, "tapEnable", 1,		///Enables the tap, otherwise just skips it to save CPU time
				bool, "bypassDrySig", 1,	///Bypasses unfiltered signal
				bool, "filterAlg", 1,		///Toggles filter algorithm (serial/parallel)
				uint, "pos", 29				///Median position of the tap
			));
		}
		float		filterAm0 = 0.0;	///IIR0 mix amount
		float		filterAm1 = 0.0;	///IIR1 mix amount
		float		filterAm2 = 0.0;	///IIR2 mix amount
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
	protected enum OscTarget : ubyte {
		init,
		TapA0Out,
		TapA0Pos,
		TapA0Feedback,
		TapA1Out,
		TapA1Pos,
		TapA1Feedback,
		TapA2Out,
		TapA2Pos,
		TapA2Feedback,
		TapA3Out,
		TapA3Pos,
		TapA3Feedback,
		TapB0Out,
		TapB0Pos,
		TapB0Feedback,
		TapB1Out,
		TapB1Pos,
		TapB1Feedback,
		TapB2Out,
		TapB2Pos,
		TapB2Feedback,
		TapB3Out,
		TapB3Pos,
		TapB3Feedback,
	}
	protected struct Preset {
		struct OscWaveform {
			mixin(bitfields!(
				bool, "sawtooth", 1,
				bool, "triangle", 1,
				bool, "pulse", 1,
				bool, "sawpulse", 1,
				bool, "integrate", 1,
				bool, "phaseInvert", 1,
				ubyte, "", 2,
			));
		}
		Tap[4][2]				taps;
		float[4]				iirFreq;
		float[4]				iirQ;
		float[4]				oscLevels;
		float[4]				oscFrequencies;
		float[4]				oscPWM;
		ubyte[4]				oscTargets;
		OscWaveform[4]			oscWaveform;
		
	}
	protected Preset			currPreset;
	protected IIRBank[4][2]		filterBanks;
	protected __m128[4][2]		filterOuts;
	protected float[4][2]		feedbackSends;
	protected float[][2]		delayLines;		///The two delay lines of the 
	protected __m128			inLevel;		///0: A to pri, 1: A to sec, 2: B to pri, 3: B to sec
	protected float[2]			outLevel;
	protected float[2]			feedbackSum;
	protected QuadMultitapOsc	osc;			///Oscillators to modify fix tap points
	protected __m128i[]			oscOut;
	protected size_t[2]			dLPos;			///Delay line positions
	protected size_t[2]			dLMod;			///Delay line modulo
	protected float[]			dummyBuf;
	
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
		this.handler = handler;
		
	}

	override public void midiReceive(UMP data0, uint data1 = 0, uint data2 = 0, uint data3 = 0) @nogc nothrow {
		
	}

	override public void renderFrame(float*[] input, float*[] output) @nogc nothrow {
		//function to read from the delay line
		__m128[2] readDL(int lineNum, uint pos) @nogc @safe pure nothrow {
			__m128[2] result;
			for (int i ; i < 2 ; i++) {
				for (int j ; j < 4 ; j++) {
					result[i][j] = delayLines[lineNum][dLMod[lineNum] & (dLPos[lineNum] - pos - j - (i<<2))];
				}
			}
			return result;
		}
		float*[2] inBuf, outBuf;			//Set up input and output buffers
		for (ubyte i, j, k ; i < 2 ; i++) {
			if (enabledInputs.has(i)) {
				inBuf[i] = output[j];
				j++;
			} else {
				inBuf[i] = dummyBuf.ptr;
			}
			if (enabledOutputs.has(i)) {
				outBuf[i] = output[k];
				k++;
			} else {
				outBuf[i] = dummyBuf.ptr;
			}
		}
		__m128[4][2] filterLevels;
		for (int i ; i < 2 ; i++) {
			for (int j ; j < 4 ; j++) {
				filterLevels[i][j][0] = taps[i][j].filterAm0;
				filterLevels[i][j][1] = taps[i][j].filterAm1;
				filterLevels[i][j][2] = taps[i][j].filterAm2;
				filterLevels[i][j][3] = taps[i][j].bypassDrySig ? 0.0 : 1.0;
			}
		}
		
		for (int outputPos ; outputPos < bufferSize ; outputPos++) {
			delayLines[0] = inbuf[0] + feedbackSum[0];
			delayLines[1] = inbuf[1] + feedbackSum[1];
			feedbackSum[0] = 0.0;
			feedbackSum[1] = 0.0;
			for (int i ; i < 2 ; i++) {
				for (int j ; j < 4 ; j++) {
					if (currPreset.taps[i][j].tapEnable) {
						const __m128[2] firTarget = readDL(i, currPreset.taps[i][j].pos);
						const __m128 partialOut = firTarget[0] * currPreset.taps[i][j].fir[0] + 
								firTarget[1] * currPreset.taps[i][j].fir[1];//Apply FIR
						//Apply IIRs
						const float outSum = partialOut[0] + partialOut[1] + partialOut[2] + partialOut[3];
						__m128 toIIR;
						toIIR[0] = outSum;
						toIIR[3] = feedbackSends[i][j];
						if(taps[i][j].filterAlg) {
							toIIR[1] = filterOuts[i][j][0];
							toIIR[2] = filterOuts[i][j][1];
						} else {
							toIIR[1] = outSum;
							toIIR[2] = outSum;
						}
						//toIIR *= filterLevels;
						toIIR = IIRBank.output(toIIR);
						filterOuts[i][j] = toIIR;
						toIIR[3] = outSum;
						toIIR *= filterLevels[i][j];
						feedbackSends[i][j] = toIIR[0] + toIIR[1] + toIIR[2] + toIIR[3];
						__m128 finalOut;
						finalOut[0] = feedbackSends[i][j];
						finalOut[1] = feedbackSends[i][j];
						finalOut[2] = filterOuts[i][j][3];
						finalOut[3] = filterOuts[i][j][3];
						finalOut *= taps[i][j].outLevels;
						outBuf[0][outputPos] += finalOut[0] * outLevel[0];
						outBuf[1][outputPos] += finalOut[1] * outLevel[1];
						feedbackSum[0] = finalOut[2];
						feedbackSum[1] = finalOut[3];
					}
				}
			}
			dLPos[0]++;
			dLPos[1]++;
		}
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