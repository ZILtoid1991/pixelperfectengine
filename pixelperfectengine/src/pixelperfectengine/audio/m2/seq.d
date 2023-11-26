module pixelperfectengine.audio.m2.seq;

public import pixelperfectengine.audio.m2.types;
public import pixelperfectengine.audio.base.midiseq : Sequencer;
public import pixelperfectengine.audio.base.modulebase;
import collections.treemap;

import std.typecons : BitFlags;
import core.time : MonoTime;
import midi2.types.structs;
import midi2.types.enums;

public class SequencerM2 : Sequencer {
	enum ErrorFlags : uint {
		badOpcode		=		1<<0,
		illegalJump		=		1<<1,
		unrecognizedDevice=		1<<2,
		unrecognizedCode=		1<<3,
		outOfPatternSlots=		1<<4,
		unrecognizedPattern=	1<<5,
	}
	enum StatusFlags : uint {
		play			=		1<<0,
		pause			=		1<<1,
		endReached		=		1<<8,

		cfg_StopOnError	=		1<<16,
	}
	public BitFlags!ErrorFlags errors;
	protected BitFlags!StatusFlags status;
	public TreeMap!(uint, AudioModule) modTrgt;
	public M2Song songdata;

	public void lapseTime(Duration amount) @nogc nothrow {
		if (!status.play) return;
		foreach (ref M2PatternSlot ptrnSl ; songdata.ptrnSl) {
			if (ptrnSl.status.isRunning && !ptrnSl.status.suspend && status.play) {
				advancePattern(ptrnSl, amount);
			}
		}
	}
	/** 
	 * Advances the supplied pattern by the given `amount`, then processes commands if needed.
	 */
	private void advancePattern(ref M2PatternSlot ptrn, Duration amount) @nogc nothrow {
		///Returns the current timebase
		ulong getTimeBase() @nogc @safe pure nothrow const {
			return (((songdata.timebase * songdata.globTimeMult)>>16) * ptrn.timeMult)>>16;
		}
		if ((ptrn.timeToWait -= amount) <= hnsecs(0)) {	//If enough time has passed, then proceed to compute commands
			uint[] patternData = songdata.ptrnData[ptrn.id];
			while (patternData.length > ptrn.position && status.play) {	//Loop until end is reached or certain opcode is reached (handle that within the switch statement)
				DataReaderHelper data = DataReaderHelper(patternData[ptrn.position]);
				switch (data.bytes[0]) {		//Process commands
					case OpCode.nullcmd:		//Null command (do nothing)
						break;
					case OpCode.lnwait:			//Long wait
						const ulong tics = (((data.bytes[1]<<16) | data.hwords[1])<<24) | patternData[ptrn.position + 1];	//Get amount of tics for this wait command
						const ulong timeBase = getTimeBase();
						ptrn.timeToWait = nsecs(timeBase * tics) - ptrn.timeToWait;		//calculate new wait amount, plus add any overshoot from the previous time
						ptrn.position += 2;
						//return;
						goto exitLoop;
					case OpCode.shwait:			//Short wait
						const uint tics = (data.bytes[1]<<16) | data.hwords[1];
						const ulong timeBase = getTimeBase();
						ptrn.timeToWait = nsecs(timeBase * tics) - ptrn.timeToWait;		//calculate new wait amount, plus add any overshoot from the previous time
						ptrn.position += 1;
						//return;
						goto exitLoop;
					case OpCode.emit:			//MIDI data emit
						const device = data.hwords[1];
						const dataAm = data.bytes[1];
						emitMIDIData(patternData[ptrn.position..ptrn.position + dataAm], device);
						ptrn.position += 1 + dataAm;
						break;
					case OpCode.jmp:			//Conditional jump
						switch (data.bytes[1]) {
							case JmpCode.nc:	//Always jump
								ptrn.position += cast(int)patternData[ptrn.position + 2];
								break;
							case JmpCode.eq:	//Jump if condition code and condition register are equal
								if (ptrn.localReg[CR] == patternData[ptrn.position + 1]) {
									ptrn.position += cast(int)patternData[ptrn.position + 2];
								} else {
									ptrn.position += 3;
								}
								break;
							case JmpCode.ne:	//Jump if condition code and condition register are not equal
								if (ptrn.localReg[CR] != patternData[ptrn.position + 1]) {
									ptrn.position += cast(int)patternData[ptrn.position + 2];
								} else {
									ptrn.position += 3;
								}
								break;
							case JmpCode.sh:
								if (ptrn.localReg[CR] & patternData[ptrn.position + 1]) {
									ptrn.position += cast(int)patternData[ptrn.position + 2];
								} else {
									ptrn.position += 3;
								}
								break;
							case JmpCode.op:	//Jump if condition code bits are opposite of CR
								if (ptrn.localReg[CR] == ~patternData[ptrn.position + 1]) {
									ptrn.position += cast(int)patternData[ptrn.position + 2];
								} else {
									ptrn.position += 3;
								}
								break;
							default:
								ptrn.position += 3;
								errors.unrecognizedCode = true;
								if (status.cfg_StopOnError) {
									status.play = false;
									return;
								}
								break;
						}
						if (ptrn.position > patternData.length) {
							errors.illegalJump = true;
							ptrn.status.isRunning = false;
							ptrn.status.hasEnded = true;
							if (status.cfg_StopOnError) {
								status.play = false;
								return;
							}
						}
						break;
					case OpCode.chain_par:
						initNewPattern((data.bytes[1]<<24) | data.hwords[1], PATTERN_SLOT_INACTIVE_ID);
						ptrn.position++;
						break;
					case OpCode.chain_ser:
						initNewPattern((data.bytes[1]<<24) | data.hwords[1], ptrn.id);
						ptrn.status.suspend = true;
						ptrn.position++;
						return;
					//Math operations on registers begin
					case OpCode.add: .. case OpCode.satmuls:
						T saturate(T)(const long src) @nogc nothrow pure {
							if (src < T.min) return T.min;
							if (src > T.max) return T.max;
							return cast(T)src;
						}
						const uint ra = data.bytes[1] & 0x80 ? songdata.globalReg[data.bytes[1]&0x7F] : ptrn.localReg[data.bytes[1]];
						const uint rb = data.bytes[2] & 0x80 ? songdata.globalReg[data.bytes[2]&0x7F] : ptrn.localReg[data.bytes[2]];
						uint rd;
						switch (data.bytes[0]) {
							case OpCode.add:
								rd = ra + rb;
								break;
							case OpCode.sub:
								rd = ra - rb;
								break;
							case OpCode.mul:
								rd = ra * rb;
								break;
							case OpCode.div:
								rd = ra / rb;
								break;
							case OpCode.mod:
								rd = ra % rb;
								break;
							case OpCode.and:
								rd = ra & rb;
								break;
							case OpCode.or:
								rd = ra | rb;
								break;
							case OpCode.xor:
								rd = ra ^ rb;
								break;
							case OpCode.not:
								rd = ~ra;
								break;
							case OpCode.lshi:
								rd = ra << data.bytes[2];
								break;
							case OpCode.rshi:
								rd = ra >> data.bytes[2];
								break;
							case OpCode.rasi:
								rd = cast(int)ra >> data.bytes[2];
								break;
							case OpCode.adds:
								rd = cast(int)ra + cast(int)rb;
								break;
							case OpCode.subs:
								rd = cast(int)ra - cast(int)rb;
								break;
							case OpCode.muls:
								rd = cast(int)ra * cast(int)rb;
								break;
							case OpCode.divs:
								rd = cast(int)ra / cast(int)rb;
								break;
							case OpCode.lsh:
								rd = ra << rb;
								break;
							case OpCode.rsh:
								rd = ra << rb;
								break;
							case OpCode.ras:
								rd = cast(int)ra << cast(int)rb;
								break;
							case OpCode.mov:
								rd = ra;
								break;
							case OpCode.satadd:
								rd = saturate!uint(cast(long)ra + rb);
								break;
							case OpCode.satsub:
								rd = saturate!uint(cast(long)ra - rb);
								break;
							case OpCode.satmul:
								rd = saturate!uint(cast(long)ra * rb);
								break;
							case OpCode.satadds:
								rd = saturate!int(cast(long)(cast(int)ra) + cast(int)rb);
								break;
							case OpCode.satsubs:
								rd = saturate!int(cast(long)(cast(int)ra) - cast(int)rb);
								break;
							case OpCode.satmuls:
								rd = saturate!int(cast(long)(cast(int)ra) * cast(int)rb);
								break;
							default:
								errors.badOpcode = true;
								if (status.cfg_StopOnError) {
									status.play = false;
									return;
								}
								break;
						}
						if (data.bytes[3] & 0x80) {
							songdata.globalReg[data.bytes[3] & 0x7F] = rd;
						} else {
							ptrn.localReg[data.bytes[3]] = rd;
						}
						ptrn.position++;
						break;
					//Math operations on registers end
					case OpCode.cmp:		//compare instruction
						bool cmpRes;
						const uint ra = data.bytes[2] & 0x80 ? songdata.globalReg[data.bytes[2]&0x7F] : ptrn.localReg[data.bytes[2]];
						const uint rb = data.bytes[3] & 0x80 ? songdata.globalReg[data.bytes[3]&0x7F] : ptrn.localReg[data.bytes[3]];
						switch (data.bytes[1]) {
							case CmpCode.eq:
								cmpRes = ra == rb;
								break;
							case CmpCode.ne:
								cmpRes = ra != rb;
								break;
							case CmpCode.gt:
								cmpRes = ra > rb;
								break;
							case CmpCode.ge:
								cmpRes = ra >= rb;
								break;
							case CmpCode.lt:
								cmpRes = ra < rb;
								break;
							case CmpCode.le:
								cmpRes = ra <= rb;
								break;
							case CmpCode.ze:
								cmpRes = ra == 0;
								break;
							case CmpCode.nz:
								cmpRes = ra != 0;
								break;
							case CmpCode.ng:
								cmpRes = cast(int)ra < 0;
								break;
							case CmpCode.po:
								cmpRes = cast(int)ra > 0;
								break;
							case CmpCode.sgt:
								cmpRes = cast(int)ra > cast(int)rb;
								break;
							case CmpCode.sge:
								cmpRes = cast(int)ra >= cast(int)rb;
								break;
							case CmpCode.slt:
								cmpRes = cast(int)ra < cast(int)rb;
								break;
							case CmpCode.sle:
								cmpRes = cast(int)ra <= cast(int)rb;
								break;
							default:
								errors.unrecognizedCode = true;
								if (status.cfg_StopOnError) {
									status.play = false;
									return;
								}
								break;
						}
						ptrn.localReg[CR]<<=1;		//Shift in new bit depending on compare result;
						if (cmpRes) ptrn.localReg[CR] |= 1;
						ptrn.position++;
						break;
					case OpCode.chain:
						ptrn.status.isRunning = false;
						ptrn.status.hasEnded = true;
						initNewPattern((data.bytes[1]<<24) | data.hwords[1], PATTERN_SLOT_INACTIVE_ID);
						return;
					case OpCode.cue:
						ptrn.lastCue = (data.bytes[1]<<24) | data.hwords[1];
						break;
					default:
						errors.badOpcode = true;
						if (status.cfg_StopOnError) {
							status.play = false;
							return;
						}
						break;
				}
			}
			exitLoop:
			if (patternData.length >= ptrn.position && !hasUsefulDataLeft(patternData[ptrn.position..$])) {	//Free up pattern slot if ended or has no useful data left.
				ptrn.status.isRunning = false;
				ptrn.status.hasEnded = true;
				if (ptrn.backLink != PATTERN_SLOT_INACTIVE_ID) {
					foreach (size_t i, ref M2PatternSlot ptrnSl ; songdata.ptrnSl) {
						if (ptrnSl.id == ptrn.backLink) {
							ptrn.status.suspend = false;
						}
					}
				}
			}
		}
	}
	///Initializes new pattern with the given ID
	private void initNewPattern(uint patternID, uint backLink) @nogc nothrow {
		foreach (size_t i, ref M2PatternSlot ptrnSl ; songdata.ptrnSl) {
			if (ptrnSl.id == PATTERN_SLOT_INACTIVE_ID || ptrnSl.status.hasEnded) {	//Search for lowest unused pattern slot
				ptrnSl.reset;
				uint[] ptrnData = songdata.ptrnData[patternID];
				if (ptrnData.length) {
					ptrnSl.id = patternID;
					ptrnSl.backLink = backLink;
				} else {								//Handle errors for potential references to nonexistent patterns
					errors.unrecognizedPattern = true;
					if (status.cfg_StopOnError) {
						status.play = false;
					}
				}
				
				return;
			}
		}
		errors.outOfPatternSlots = true;
		if (status.cfg_StopOnError) {
			status.play = false;
		}
	}
	///Returns true if there's still useful for the sequencer.
	private bool hasUsefulDataLeft(uint[] patternData) @nogc nothrow pure const {
		if (patternData.length == 0) return false;
		foreach (key; patternData) {
			DataReaderHelper data = DataReaderHelper(key);
			if (data.bytes[0] != 0x00 || data.bytes[0] != 0xff) return true;    //Has at least one potential command.
		}
		return false;
	}
	/** 
	 * Emits MIDI data to the target module. Takes care of data length, transposing (TODO: implement), etc.
	 */
	private void emitMIDIData(uint[] data, uint targetID) @nogc nothrow {
		uint pos;
		while (pos < data.length) {
			UMP midiPck;
			midiPck.base = data[pos];
			const uint cmdSize = umpSizes[midiPck.msgType]>>4;
			AudioModule am = modTrgt[targetID];
			if (am is null) {
				errors.unrecognizedCode = true;
				if (status.cfg_StopOnError) {
					status.play = false;
					return;
				}
			} else {
				switch (cmdSize) {
					case 2:
						am.midiReceive(midiPck, data[pos + 1]);
						pos += 2;
						break;
					case 3:
						am.midiReceive(midiPck, data[pos + 1], data[pos + 2]);
						pos += 3;
						break;
					case 4:
						am.midiReceive(midiPck, data[pos + 1], data[pos + 2], data[pos + 3]);
						pos += 4;
						break;
					default:
						am.midiReceive(midiPck);
						pos += 1;
						break;
				}
			}
		}
	}
}