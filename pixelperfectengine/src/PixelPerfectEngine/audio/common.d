module PixelPerfectEngine.audio.common;

import std.bitmanip;

/**
 * Defines basic functions for an envelope generator.
 */
public interface IEnvelopeGenerator{
	public @nogc uint updateEnvelopeState();
	public @nogc void setKeyOn();
	public @nogc void setKeyOff();
}
/**
 *
 */
public struct MICPCommand{
	mixin(bitfields!(
		ushort, "command", 6,
		ushort, "channel", 10));
	ushort val0;
	union{
		ushort[2] val1;
		float val2;
		uint[4] midiCMD;
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
 *
 */
public enum MICPCommandList : ushort{
	NULL,
	KeyOn,
	KeyOff,
	AfterTouch,
	PitchBend,
	PitchBentFP,
	ProgSelect,
	ParamEdit,
	ParamEditFP,
	SysExc,
	MIDIThruMICP,
}