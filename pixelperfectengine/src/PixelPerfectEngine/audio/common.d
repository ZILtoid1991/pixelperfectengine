module PixelPerfectEngine.audio.common;

import std.bitmanip;
import std.math;

/**
 * Defines basic functions for an envelope generator.
 */
public interface IEnvelopeGenerator{
	public @nogc uint updateEnvelopeState();
	public @nogc void setKeyOn();
	public @nogc void setKeyOff();
}
/**
 * Stores an MICP command on 64 bits.
 */
public struct MICPCommand{
	mixin(bitfields!(
		ushort, "command", 6,
		ushort, "channel", 10));
	ushort val0;		///
	union{
		ushort[2] vals;
		float valf;
		ubyte[4] midiCMD;
		uint val32;
	}
	/*alias note = val0;
	alias parameter = val0;
	alias velocity = val1[0];
	alias expr = val1[1];
	alias program = val1[0];
	alias bank = val1[1];
	alias valueInt = val1[0];
	alias valueFloat = val2;*/
}
/**
 * Command list for MICP
 */
public enum MICPCommandList : ushort{
	NULL	=	0,
	KeyOn	=	1,			///val0: Note, val1: Velocity, val2: Expression
	KeyOff	=	2,			///val0: Note, val1: Velocity, val2: Expression
	AfterTouch	=	3,		///val0: Note, val1: Velocity, val2: Expression
	PitchBend	=	4,		///val0: Note, val1: Corase, val2: Fine
	PitchBentFP	=	5,		///val0: Note, valf: Amount
	ProgSelect	=	6,		///val0: Prog, val1: Bank if used, val2: Unused
	ParamEdit	=	7,		///val0: Parameter ID, val1: New value, val2: Unused
	ParamEditFP	=	8,		///val0: Parameter ID, valf: New value
	ParamEdit32 =	9,		///val0: Parameter ID, val32: New value
	SysExc	=	16,
	MIDIThruMICP	=	17,	///val0 is unused
	Wait	=	24			///val0: bits 32-47 if needed, val32: bits 0-31
}

/**
 * All PPE-FX synths and effects should be inherited from this class.
 */
abstract class AbstractPPEFX{
	public abstract @nogc void render(float** inputBuffers, float** outputBuffers);
	public abstract @nogc int setRenderParams(float samplerate, size_t framelength, size_t nOfFrames);
	public abstract @nogc void receiveMICPCommand(MICPCommand cmd);
	public abstract void loadConfig(ref void[] data);
	public abstract ref void[] saveConfig();
	public abstract PPEFXInfo* getPPEFXInfo();
	/**
	 * Converts a midi note to frequency, can also take fine tuning.
	 */
	public @nogc float midiNoteToFrequency(float note, float tuning = 440.0f){
    	return tuning * pow(2.0, (note - 69.0f) / 12.0f);
	}
	public @nogc float frequencyToMidiNote(float frequency, float tuning = 440.0f){
    	return 69.0f + 12.0f * log2(frequency / tuning);
	}
}

public struct PPEFXInfo{
	public int nOfInputs;
	public int nOfOutputs;
	public string[] inputNames;
	public string[] outputNames;
	public bool isSynth;

}
