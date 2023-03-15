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
import std.math;

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
	shared static this () {
		import std.conv : to;
		for (uint i ; i < 8 ; i++) {
			for (uint j ; j < 8 ; j++) {
				SET_VALS ~= MValue(MValueType.Float, (i<<7) | j, "Tap" ~ i.to!string ~ "_FIR" ~ j.to!string);
			}
			for (uint j ; j < 4 ; j++) {
				SET_VALS ~= MValue(MValueType.Float, (i<<7) | (8 + j * 3 + 0), "Tap" ~ i.to!string ~ "_IIR" ~ j.to!string ~ "Freq");
				SET_VALS ~= MValue(MValueType.Float, (i<<7) | (8 + j * 3 + 1), "Tap" ~ i.to!string ~ "_IIR" ~ j.to!string ~ "Q");
				SET_VALS ~= MValue(MValueType.Int32, (i<<7) | (8 + j * 3 + 2), "Tap" ~ i.to!string ~ "_IIR" ~ j.to!string ~ "Type");
			}
			SET_VALS ~= MValue(MValueType.Float, (i<<7) | (20), "Tap" ~ i.to!string ~ "_OutputL");
			SET_VALS ~= MValue(MValueType.Float, (i<<7) | (21), "Tap" ~ i.to!string ~ "_OutputR");
			SET_VALS ~= MValue(MValueType.Float, (i<<7) | (22), "Tap" ~ i.to!string ~ "_FeedbackPri");
			SET_VALS ~= MValue(MValueType.Float, (i<<7) | (23), "Tap" ~ i.to!string ~ "_FeedbackSec");
			SET_VALS ~= MValue(MValueType.Int32, (i<<7) | (24), "Tap" ~ i.to!string ~ "_Pos");
			SET_VALS ~= MValue(MValueType.Boolean, (i<<7) | (25), "Tap" ~ i.to!string ~ "_TapEnable");
			SET_VALS ~= MValue(MValueType.Boolean, (i<<7) | (26), "Tap" ~ i.to!string ~ "_BypassDrySig");
			SET_VALS ~= MValue(MValueType.Boolean, (i<<7) | (27), "Tap" ~ i.to!string ~ "_FilterAlg");
		}
		for (uint i ; i < 4 ; i++){
			SET_VALS ~= MValue(MValueType.Int32, (8<<7) | (i<<3) | (0), "LFO" ~ i.to!string ~ "_Waveform");
			SET_VALS ~= MValue(MValueType.Float, (8<<7) | (i<<3) | (1), "LFO" ~ i.to!string ~ "_Level");
			SET_VALS ~= MValue(MValueType.Float, (8<<7) | (i<<3) | (2), "LFO" ~ i.to!string ~ "_Freq");
			SET_VALS ~= MValue(MValueType.Float, (8<<7) | (i<<3) | (3), "LFO" ~ i.to!string ~ "_PWM");
			SET_VALS ~= MValue(MValueType.Int32, (8<<7) | (i<<3) | (4), "LFO" ~ i.to!string ~ "_Target0");
			SET_VALS ~= MValue(MValueType.Int32, (8<<7) | (i<<3) | (5), "LFO" ~ i.to!string ~ "_Target1");
			SET_VALS ~= MValue(MValueType.Int32, (8<<7) | (i<<3) | (6), "LFO" ~ i.to!string ~ "_Target2");
			SET_VALS ~= MValue(MValueType.Int32, (8<<7) | (i<<3) | (7), "LFO" ~ i.to!string ~ "_Target3");
		}
		SET_VALS ~= MValue(MValueType.Float, (9<<7) | (0), "InputAtoPri");
		SET_VALS ~= MValue(MValueType.Float, (9<<7) | (1), "InputAtoSec");
		SET_VALS ~= MValue(MValueType.Float, (9<<7) | (2), "InputBtoPri");
		SET_VALS ~= MValue(MValueType.Float, (9<<7) | (3), "InputBtoSec");
		SET_VALS ~= MValue(MValueType.Float, (9<<7) | (3), "MasterL");
		SET_VALS ~= MValue(MValueType.Float, (9<<7) | (3), "MasterR");
	}
	protected static MValue[] SET_VALS;
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
		///All initial values + some precalculated ones.
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
	///Defines an LFO target
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
	///Contains recallable preset data.
	protected struct Preset {
		///Defines oscillator waveform selection data.
		///Bitfield notation:
		///  sawtooth = Enables or disables sawtooth output.
		///  triangle = Enables or disables triangle output.
		///  pulse = Enables or disables pulse output.
		///  sawpulse = Enables or disables sawpulse output.
		///  integrate = Compensates triangle/saw output for position offsetting.
		///  phaseInvert = Inverts the output phase of the oscillator.
		struct OscWaveform {
			union {
				mixin(bitfields!(
					bool, "sawtooth", 1,
					bool, "triangle", 1,
					bool, "pulse", 1,
					bool, "sawpulse", 1,
					bool, "integrate", 1,
					bool, "phaseInvert", 1,
					ubyte, "", 2,
				));
				ubyte raw;
			}
		}
		Tap[4][2]				taps;			///Defines delay line taps
		float[4]				iirFreq;		///Defines IIR frequencies
		float[4]				iirQ;			///Defines IIR Q value
		float[4]				oscLevels;		///Defines the amount of effect a given LFO has on a parameter
		float[4]				oscFrequencies;	///Defines LFO freqencies
		float[4]				oscPWM;			///Defines the PWM of the LFOs
		ubyte[4]				oscTargets;		///Sets the target of a given LFO
		OscWaveform[4]			oscWaveform;	///Sets the waveform output of the LFOs
		
	}
	protected TreeMap!(uint,Preset)	presetBank;	///Stores presets
	protected Preset			currPreset;		///Contains the copy of the current preset
	protected IIRBank[4][2]		filterBanks;	///Stores filter data for each taps
	protected __m128[4][2]		filterOuts;		///Last filter outputs
	protected float[4][2]		feedbackSends;	///Stores feedback send levels
	protected float[][2]		delayLines;		///The two delay lines of the 
	protected __m128			inLevel;		///0: A to pri, 1: A to sec, 2: B to pri, 3: B to sec
	protected float[2]			outLevel;		///Output levels
	protected float[2]			feedbackSum;	///Feedback sums to be mixed in with the inputs
	protected QuadMultitapOsc	osc;			///Oscillators to modify fix tap points
	protected __m128i[]			oscOut;			///LFO buffer
	protected size_t[2]			dLPos;			///Delay line positions
	protected size_t[2]			dLMod;			///Delay line modulo
	protected float[]			dummyBuf;		///Buffer used for unused inputs/outputs
	
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
		oscOut.length = bufferSize;
		dummyBuf.length = bufferSize;
		feedbackSum[0] = 0;
		feedbackSum[1] = 0;
		resetBuffer(oscOut);
		resetBuffer(dummyBuf);
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
		//Precalculate values, so they don't need to be done on a per-cycle basis.
		__m128[4][2] filterLevels;
		float[4][2] filterAlg0;
		float[4][2] filterAlg1;
		for (int i ; i < 2 ; i++) {
			for (int j ; j < 4 ; j++) {
				filterLevels[i][j][0] = currPreset.taps[i][j].filterAm0;
				filterLevels[i][j][1] = currPreset.taps[i][j].filterAm1;
				filterLevels[i][j][2] = currPreset.taps[i][j].filterAm2;
				filterLevels[i][j][3] = currPreset.taps[i][j].bypassDrySig ? 0.0 : 1.0;
				filterAlg0[i][j] = currPreset[i][j].filterAlg ? 0.0 : 1.0;
				filterAlg1[i][j] = currPreset[i][j].filterAlg ? 1.0 : 0.0;
			}
		}
		{	//Render LFO outs.
			for (int lfoPos ; lfoPos < bufferSize ; lfoPos++) {
				oscOut[lfoPos] = osc.output();
			}
			for (int i ; i < 4 ; i++) {
				if (currPreset.oscWaveform[i].integrate){	//integrate output if needed
					for (int lfoPos ; lfoPos < bufferSize ; lfoPos++) {
						oscOut[lfoPos][i] = cast(int)((abs(oscOut[lfoPos][i]) * cast(long)oscOut[lfoPos][i])>>32L);
					}
				}
			}
		}
		for (int outputPos ; outputPos < bufferSize ; outputPos++) {
			delayLines[0][dLPos[0] | dlMod[0]] = inBuf[0][outputPos] * inLevel[0] + inBuf[1][outputPos] * inLevel[1] + 
					feedbackSum[0];
			delayLines[1][dLPos[1] | dlMod[1]] = inBuf[0][outputPos] * inLevel[2] + inBuf[1][outputPos] * inLevel[3] + 
					feedbackSum[1];
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
						toIIR[1] = filterOuts[i][j][0] * filterAlg1[i][j] + outSum * filterAlg0[i][j];
						toIIR[2] = filterOuts[i][j][1] * filterAlg1[i][j] + outSum * filterAlg0[i][j];
						toIIR[3] = feedbackSends[i][j];
						toIIR = filterBanks[i][j].output(toIIR);
						filterOuts[i][j] = toIIR;
						toIIR[3] = outSum;
						toIIR *= filterLevels[i][j];
						feedbackSends[i][j] = toIIR[0] + toIIR[1] + toIIR[2] + toIIR[3];
						//Mix to final output
						__m128 finalOut;
						finalOut[0] = feedbackSends[i][j];
						finalOut[1] = feedbackSends[i][j];
						finalOut[2] = filterOuts[i][j][3];
						finalOut[3] = filterOuts[i][j][3];
						finalOut *= currPreset.taps[i][j].outLevels;
						outBuf[0][outputPos] += finalOut[0] * outLevel[0];
						outBuf[1][outputPos] += finalOut[1] * outLevel[1];
						feedbackSum[0] += finalOut[2];
						feedbackSum[1] += finalOut[3];
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
		Preset selPreset;
		const uint paramGr = (paramID)>>7;
		switch (paramGr) {
			case 0: .. case 7:
				const uint tapID = paramGr & 3, lineID = paramGr>>2;
				const uint subParamID = paramID & 0x3F
				switch (subParamID) {
					case 0: .. case 3:
						
						break;
					default:
						break;
				}
				break
			default:
				break;
		}
		return int.init; // TODO: implement
	}

	override public int writeParam_long(uint presetID, uint paramID, long value) nothrow {
		return int.init; // TODO: implement
	}

	override public int writeParam_double(uint presetID, uint paramID, double value) nothrow {
		Preset selPreset;
		const uint paramGr = (paramID)>>7;
		switch (paramGr) {
			case 0: .. case 7:
				const uint tapID = paramGr & 3, lineID = paramGr>>2;
				const uint subParamID = paramID & 0x3F
				switch (subParamID) {
					case 0: .. case 3:
						selPreset.taps[lineID][tapID].fir[0][subParamID] = value;
						break;
					case 4: .. case 7:
						selPreset.taps[lineID][tapID].fir[1][subParamID - 4] = value;
						break;
					case 8: .. case 19:
						const uint filterID = (subParamID - 8) / 3, filterParamID = (subParamID - 8) % 3;
						break;
					default:
						break;
				}
				break
			default:
				break;
		}
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