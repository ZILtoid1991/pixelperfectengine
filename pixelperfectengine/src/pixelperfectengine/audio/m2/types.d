module pixelperfectengine.audio.m2.types;

public import core.time : Duration, hnsecs;
import std.typecons : BitFlags;
import collections.treemap;

/** 
 * Contains opcodes for M2 operations.
 */
public enum OpCode : ubyte {
	nullcmd		=   0x00,		///Null command
	shwait		=   0x01,		///Short wait (24 bits)
	lnwait		=   0x02,		///Long wait (48 bits)
	emit		=   0x03,		///Emit command list to device
	jmp			=   0x04,		///Conditional jump
	chain_par	=   0x05,		///Chain in pattern in parallel
	chain_ser	=   0x06,		///Chain in pattern in serial
	//Math operations on registers begin
	add			=   0x07,		///Add two registers, store in third
	sub			=   0x08,		///Subtract two registers, store in third
	mul			=   0x09,		///Multiply two registers, store in third
	div			=   0x0a,		///Divide two registers, store in third
	mod			=   0x0b,		///Modulo two registers, store in third
	and			=   0x0c,		///Binary and two registers, store in third
	or			=   0x0d,		///Binary or two registers, store in third
	xor			=   0x0e,		///Binary xor two registers, store in third
	not			=   0x0f,		///Binary invert RA, store in RD
	lshi		=   0x10,		///Logically shift left RA by RB immediate value, store in RD
	rshi		=   0x11,		///Logically shift right RA by RB immediate value, store in RD
	rasi		=   0x12,		///Arithmetically shift right RA by RB immediate value, store in RD
	adds		=   0x13,		///Add two registers, store in third
	subs		=   0x14,		///Subtract two registers, store in third
	muls		=   0x15,		///Multiply two registers, store in third
	divs		=   0x16,		///Divide two registers, store in third
	lsh         =   0x17,		///Logically shift left RA by RB, store in RD
	rsh         =   0x18,		///Logically shift right RA by RB, store in RD
	ras         =   0x19,		///Arithmetically shift right RA by RB, store in RD
	mov         =   0x1a,		///Move register content of RA to RD
	//Math operations on registers end
	cmp			=	0x1b,		///Compare two register values
	chain		=	0x1c,		///Abandon current pattern to next one
	emit_r0		=	0x1d,		///Emit command with value from register
	emit_0r		=	0x1e,		///Emit command to group/channel from register
	emit_rr		=	0x1f,		///Emit command to group/channel from register with value from register
	cue			=	0x20,		///Set cue point/marker
	trnsps		=	0x21,		///Transpose
	display		=	0xff,		///Display command
}
/** 
 * Contains compare codes for M2 cmp operations.
 */
public enum CmpCode : ubyte {
	init,
	eq,							///Equal
	ne,							///Not equal
	gt,							///Greater than
	ge,							///Greater or equal
	lt,							///Less than
	le,							///Less or equal
	ze,							///RA is zero
	nz,							///RA is not zero
	ng,							///RA is negative
	po,							///RA is positive
	sgt,						///Signed greater than
	sge,						///Signed greater or equal
	slt,						///Signed less than
	sle,						///Signed less or equal
}
/** 
 * Contains jump condition coded for M2 jmp operations.
 */
public enum JmpCode : ubyte {
	nc,							///Always jump
	eq,							///Jump if condition code is equal to condition register
	ne,							///Jump if condition code is not equal to condition register
	sh,							///Jump if at least some of the same bits are high in both the condition code and the condition register
	op,							///Jump is all the bits are opposite in the condition code from the condition register
}
///Compare register number.
public enum CR = 127;
public enum PATTERN_SLOT_INACTIVE_ID = uint.max;

public struct M2PatternSlot {
	public enum StatusFlags : uint {
		isRunning		=	1<<0,
		hasEnded		=	1<<1,
		suspend			=	1<<2,
		error_badOpCode =	1<<16,
		error_selfRef	=	1<<17,
		error_illegalJmp=	1<<18,
	}
	public uint[128] localReg;
	public uint[16] patternSt;
	public BitFlags!StatusFlags status;
	public uint lastCue;
	public uint id;
	public uint position;
	public double timeMult = 1.0;
	public Duration timeToWait;
	
}

public struct M2Song {
	public enum StatusFlags : uint {
		isRunning		=	1<<0,
		hasEnded		=	1<<1,
		haltOnError		=	1<<8,
	}
	public uint[128] globalReg;
	public M2PatternSlot[] ptrnSl;
	public uint[] activePtrnNums;
	public double globTimeMult = 1.0;
	public ulong timebase;
	public TreeMap!(uint, uint[]) ptrnData;
	this (uint parPtrnNum, TreeMap!(uint, uint[]) ptrnData, ulong timebase) @safe nothrow {
		ptrnSl.length = parPtrnNum;
		activePtrnNums.length = parPtrnNum;
		foreach (ref i; activePtrnNums)
			i = PATTERN_SLOT_INACTIVE_ID;
		this.ptrnData = ptrnData;
	}
}

package struct DataReaderHelper {
	union {
		uint word;
		ushort[2] hwords;
		ubyte[4] bytes;
	}
	this (uint base) @nogc @safe pure nothrow {
		word = base;
	}
}