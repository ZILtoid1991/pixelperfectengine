module pixelperfectengine.audio.m2.seq;

public import pixelperfectengine.audio.m2.types;
public import pixelperfectengine.audio.base.midiseq : Sequencer;
public import pixelperfectengine.audio.base.modulebase;
public import pixelperfectengine.audio.base.handler : ModuleManager;
public import pixelperfectengine.audio.base.config;
import collections.treemap;

import std.typecons : BitFlags;
import pixelperfectengine.system.etc : max, min;
import core.time : MonoTime;
import midi2.types.structs;
import midi2.types.enums;

/** 
 * Implements an IMBC sequencer and VM with all of its capabilities.
 * Bugs: 
 * * Multi-pattern sequencing creates unwanted behavior.
 *
 * To do:
 * * Implement a way to interact with the public registers.
 */
public class SequencerM2 : Sequencer {
	///Stores device related data
	struct DeviceData {
		AudioModule		mod;	///The audio module target for emit commands.
		TransposingData	trnsp;
	}
	///Defines various error flags, many of which can be hit multiple times.
	enum ErrorFlags : uint {
		badOpcode			=	1<<0,	///Set if bad or unrecognized opcode have been reached.
		illegalJump			=	1<<1,	///Jump is outside of the bound of the pattern.
		unrecognizedDevice	=	1<<2,	///Device ID not found in list.
		unrecognizedCode	=	1<<3,	///Bad or unrecognized code.
		outOfPatternSlots	=	1<<4,	///No more preallocated slots that are free.
		unrecognizedPattern	=	1<<5,	///Pattern ID not found.
		illegalMIDICmd		=	1<<6,	///Unrecognized or illegal MIDI command.
		divisionByZero		=	1<<7,	///RB is zero in a division operand, instruction wasn't executed.
	}
	///Defines various status flags for the sequencer.
	enum StatusFlags : uint {
		play				=	1<<0,	///Sequence is playing
		pause				=	1<<1,	///Sequence is paused
		endReached			=	1<<8,	///Sequence end has been reached

		cfg_StopOnError		=	1<<16,	///Stop on any errors that are unrecoverable.
	}
	public BitFlags!ErrorFlags errors;	///Stores error flags
	protected BitFlags!StatusFlags status;///Stores status flags
	protected Duration timePos;			///Stores the time position
	public TreeMap!(uint, DeviceData) modTrgt;///Defines module targets
	public M2Song songdata;				///Stores data related to the currently played song

	public this() {
		status.cfg_StopOnError = true;
	}
	/**
	 * Loads a song into the sequencer.
	 * Params:
	 *   file = the preprocessed file (loaded from either text or binary).
	 *   mcfg = module configuration.
	 */
	public void loadSong(M2File file, ModuleConfig mcfg) {
		songdata = file.songdata;
		if (mcfg !is null) {
			foreach (uint id, string name; file.devicelist) {
				modTrgt[id] = DeviceData(mcfg.getModule(name), TransposingData.init);
			}
		}
		reset();
	}
	///Starts the sequencer.
	public void start() @nogc @safe pure nothrow {
		status.play = true;
		status.pause = false;
	}
	///Stops the sequencer and resets its internal states.
	public void stop() @nogc @safe pure nothrow {
		status.play = false;
		reset();
	}
	///Resets the sequencer to its initial state.
	public void reset() @nogc @safe pure nothrow {
		timePos = Duration.init;
		songdata.globTimeMult = 0x1_00_00;
		foreach (ref M2PatternSlot ptrn ; songdata.ptrnSl) {
			ptrn.reset();
		}
		foreach (ref DeviceData dd ; modTrgt) {
			dd.trnsp = TransposingData.init;
		}
		errors = BitFlags!(ErrorFlags).init;
		//Enter main pattern
		initNewPattern(0, PATTERN_SLOT_INACTIVE_ID);
	}
	///Pauses the sequencer.
	public void pause() @nogc @safe pure nothrow {
		status.play = false;
		status.pause = true;
	}
	/**
	 *
	 */
	public void lapseTime(Duration amount) @nogc nothrow {
		if (!status.play) return;
		timePos += amount;
		foreach (ref M2PatternSlot ptrnSl ; songdata.ptrnSl) {
			if (ptrnSl.status.isRunning && !ptrnSl.status.suspend && status.play) {
				advancePattern(ptrnSl, amount);
			}
		}
	}
	/** 
	 * Advances the supplied pattern by the given `amount`, then processes commands if needed.
	 * Params:
	 *   ptrn = the current pattern.
	 *   amount = the amount of which the pattern needs to be advanced.
	 */
	private void advancePattern(ref M2PatternSlot ptrn, Duration amount) @nogc nothrow {
		///Returns the current timebase
		ulong getTimeBase() @nogc @safe pure nothrow const {
			return (((songdata.timebase * songdata.globTimeMult)>>16) * ptrn.timeMult)>>16;
		}
		ptrn.timeToWait -= amount;
		if (ptrn.timeToWait <= nsecs(0)) {	//If enough time has passed, then proceed to compute commands
			uint[] patternData = songdata.ptrnData[ptrn.id];
			while (ptrn.position < patternData.length && status.play) {	//Loop until end is reached or certain opcode is reached (handle that within the switch statement)
				M2Command data = M2Command(patternData[ptrn.position]);
				ptrn.position++;//Move data position forward by one (always needed for each reads)
				switch (data.bytes[0]) {		//Process commands
					case OpCode.nullcmd:		//Null command (do nothing)
						debug assert(!data.word, "Malformed IMBC instruction!");//This means a malformed command, bail out if debugging is enabled.
						break;
					case OpCode.lnwait:			//Long wait
						const ulong tics = data.read24BitField | patternData[ptrn.position];	//Get amount of tics for this wait command
						const ulong timeBase = getTimeBase();
						ptrn.timeToWait += hnsecs(timeBase * tics);		//calculate new wait amount, plus amount for any inaccuracy from sequencer steping.
						ptrn.position++;
						if (!ptrn.timeToWait.isNegative) goto exitLoop;	//hazard case: even after wait time is l
						break;
					case OpCode.shwait:			//Short wait
						const uint tics = data.read24BitField;
						const ulong timeBase = getTimeBase();
						ptrn.timeToWait += hnsecs(timeBase * tics);
						if (!ptrn.timeToWait.isNegative) goto exitLoop;
						break;
					case OpCode.emit:			//MIDI data emit
						const device = data.hwords[1];
						const dataAm = data.bytes[1];
						emitMIDIData(patternData[ptrn.position..ptrn.position + dataAm], device);
						ptrn.position += dataAm;
						break;
					case OpCode.emit_r:			//MIDI data emit with register data
						const regDataSrc = data.bytes[1] & 0x80 ? songdata.globalReg[data.bytes[1]&0x7F] : ptrn.localReg[data.bytes[1]];
						const device = data.hwords[1];		
						M2Command data1 = M2Command(patternData[ptrn.position]);//Read second word
						ptrn.position++;
						const regNoteSrc = data1.bytes[0] & 0x80 ? songdata.globalReg[data1.bytes[0]&0x7F] : ptrn.localReg[data1.bytes[0]];
						const regChSrc = data1.bytes[1] & 0x80 ? songdata.globalReg[data1.bytes[1]&0x7F] : ptrn.localReg[data1.bytes[1]];
						const regAuxSrc = data1.bytes[2] & 0x80 ? songdata.globalReg[data1.bytes[2]&0x7F] : ptrn.localReg[data1.bytes[2]];
						UMP data2 = UMP(patternData[ptrn.position]);//Read MIDI command chunk
						ptrn.position++;
						uint data3 = patternData[ptrn.position];//Read MIDI command chunk
						ptrn.position++;
						if (data1.bytes[3] & 0x08) {
							if (data2.status == MIDI2_0Cmd.NoteOn || data2.status == MIDI2_0Cmd.NoteOff) {
								data3 = regDataSrc & 0xFFFF_0000;
								if (data1.bytes[3] & 0x01) {
									data3 |= regAuxSrc>>16;
								}
							} else {
								data3 = regDataSrc;
							}
						}
						if (data1.bytes[3] & 0x04) {
							if (data2.status == MIDI2_0Cmd.CtrlCh || data2.status == MIDI2_0Cmd.CtrlChOld 
									|| data2.status == MIDI2_0Cmd.CtrlChR || data2.status == MIDI2_0Cmd.RelCtrlCh 
									|| data2.status == MIDI2_0Cmd.RelCtrlChR) {
								data2.note = cast(ubyte)(regNoteSrc>>7);
								data2.value = cast(ubyte)(regNoteSrc);
							} else {
								data2.note = cast(ubyte)(regNoteSrc);
							}
						}
						if (data1.bytes[3] & 0x02) {
							data2.channel = cast(ubyte)regChSrc;
							data2.group = cast(ubyte)(regChSrc>>4);
						}
						uint[2] dataToBeEmited;
						dataToBeEmited[0] = data2.base;
						dataToBeEmited[1] = data3;
						emitMIDIData(dataToBeEmited, device);
						break;
					case OpCode.jmp:			//Conditional jump
						const uint conditionMask = patternData[ptrn.position];
						ptrn.position++;
						const int jumpAm = patternData[ptrn.position];
						ptrn.position++;
						switch (data.bytes[1]) {
							case JmpCode.nc:	//Always jump
								ptrn.position += jumpAm - 3;
								break;
							case JmpCode.eq:	//Jump if condition code and condition register are equal
								if (ptrn.localReg[CR] == conditionMask) ptrn.position += jumpAm - 3;
								break;
							case JmpCode.ne:	//Jump if condition code and condition register are not equal
								if (ptrn.localReg[CR] != conditionMask) ptrn.position += jumpAm - 3;
								break;
							case JmpCode.sh:	//Jump if at least some bits of the condition code is also high in the condition register
								if (ptrn.localReg[CR] & conditionMask) ptrn.position += jumpAm - 3;
								break;
							case JmpCode.op:	//Jump if condition code bits are opposite of CR
								if (ptrn.localReg[CR] == ~conditionMask) ptrn.position += jumpAm - 3;
								break;
							default:
								errors.unrecognizedCode = true;
								if (status.cfg_StopOnError) {
									status.play = false;
									return;
								}
								break;
						}
						if (ptrn.position > patternData.length || ptrn.position < 0) {
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
						initNewPattern(data.read24BitField, PATTERN_SLOT_INACTIVE_ID);
						break;
					case OpCode.chain_ser:
						initNewPattern(data.read24BitField, ptrn.id);
						ptrn.status.suspend = true;
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
								if (rb == 0) errors.divisionByZero = true;
								else rd = ra / rb;
								break;
							case OpCode.mod:
								if (rb == 0) errors.divisionByZero = true;
								else rd = ra % rb;
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
								if (rb == 0) errors.divisionByZero = true;
								else rd = cast(int)ra / cast(int)rb;
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
						break;
					case OpCode.array:
						const uint arrayID = patternData[ptrn.position];
						ptrn.position++;
						switch (data.bytes[1]) {
							case ArrayOpCode.read:
								const size_t arrayPos = 
										(data.bytes[3] & 0x80 ? songdata.globalReg[data.bytes[3]&0x7F] : ptrn.localReg[data.bytes[3]]) %
										songdata.arrays[arrayID].length;
								const uint val = songdata.arrays[arrayID][arrayPos];
								if (data.bytes[2] & 0x80) songdata.globalReg[data.bytes[2]&0x7F] = val;
								else ptrn.localReg[data.bytes[2]] = val;
								break;
							case ArrayOpCode.readsat:
								const size_t arrayPos = min
										((data.bytes[3] & 0x80 ? songdata.globalReg[data.bytes[3]&0x7F] : ptrn.localReg[data.bytes[3]]), 
										songdata.arrays[arrayID].length - 1);
								const uint val = songdata.arrays[arrayID][arrayPos];
								if (data.bytes[2] & 0x80) songdata.globalReg[data.bytes[2]&0x7F] = val;
								else ptrn.localReg[data.bytes[2]] = val;
								break;
							case ArrayOpCode.write:
								const size_t arrayPos = 
										(data.bytes[3] & 0x80 ? songdata.globalReg[data.bytes[3]&0x7F] : ptrn.localReg[data.bytes[3]]) %
										songdata.arrays[arrayID].length;
								if (data.bytes[2] & 0x80) songdata.arrays[arrayID][arrayPos] = songdata.globalReg[data.bytes[2]&0x7F];
								else songdata.arrays[arrayID][arrayPos] = ptrn.localReg[data.bytes[2]];
								break;
							case ArrayOpCode.writesat:
								const size_t arrayPos = min
										((data.bytes[3] & 0x80 ? songdata.globalReg[data.bytes[3]&0x7F] : ptrn.localReg[data.bytes[3]]), 
										songdata.arrays[arrayID].length - 1);
								if (data.bytes[2] & 0x80) songdata.arrays[arrayID][arrayPos] = songdata.globalReg[data.bytes[2]&0x7F];
								else songdata.arrays[arrayID][arrayPos] = ptrn.localReg[data.bytes[2]];
								break;
							case ArrayOpCode.length:
								if (data.bytes[2] & 0x80) songdata.globalReg[data.bytes[2]&0x7F] = cast(uint)songdata.arrays[arrayID].length;
								else ptrn.localReg[data.bytes[2]] = cast(uint)songdata.arrays[arrayID].length;
								break;
							default:
								errors.unrecognizedCode = true;
								if (status.cfg_StopOnError) {
									status.play = false;
									return;
								}
								break;
						}
						break;
					case OpCode.chain:
						ptrn.status.isRunning = false;
						ptrn.status.hasEnded = true;
						initNewPattern(data.read24BitField, PATTERN_SLOT_INACTIVE_ID);
						return;
					case OpCode.cue:
						ptrn.lastCue = data.read24BitField;
						break;
					case OpCode.trnsps:
						DeviceData* dd = modTrgt.ptrOf(data.hwords[1]);
						if (dd is null) {
							errors.unrecognizedDevice = true;
							if (status.cfg_StopOnError) {
								status.play = false;
								return;
							}
						}
						M2Command data0 = M2Command(patternData[ptrn.position]);
						dd.trnsp.mode = data0.bytes[0];
						if (!data0.bitField(15)) {
							if (data0.bitField(16)) {
								dd.trnsp.amount = cast(byte)(data0.bytes[1] & 0x80 ? 
										songdata.globalReg[data0.bytes[1] & 0x7F] : ptrn.localReg[data0.bytes[1]]);
							} else dd.trnsp.amount = data0.bytes[1];
							if (data0.bitField(14)) {
								dd.trnsp.exclCh = data.bytes[1];
								if (data0.bitField(13)) {
									if (data0.bitField(12)) dd.trnsp.exclType = 3;
									else dd.trnsp.exclType = 2;
								} else dd.trnsp.exclType = 1;
							} else {
								dd.trnsp.exclCh = 0x00;
								dd.trnsp.exclType = 0x00;
							}
						} else {
							dd.trnsp.amount = 0x00;
						}

						ptrn.position += 1;
						break;
					case OpCode.ctrl:				//Control commands
						switch (data.bytes[1]) {
							case CtrlCmdCode.setRegister:
								const newVal = patternData[ptrn.position];
								if (data.bytes[2] & 0x80) songdata.globalReg[data.bytes[2] & 0x7F] = newVal;
								else ptrn.localReg[data.bytes[2]] = newVal;
								ptrn.position += 1;
								break;
							case CtrlCmdCode.setEnvVal:
								switch (data.hwords[1]) {
									case SetEnvValCode.setTimeMultGlobal:
										songdata.globTimeMult = patternData[ptrn.position];
										break;
									case SetEnvValCode.setTimeMultLocal:
										ptrn.timeMult = patternData[ptrn.position];
										break;
									default:
										break;
								}
								ptrn.position += 1;
								break;
							default:
								errors.unrecognizedCode = true;
								if (status.cfg_StopOnError) {
									status.play = false;
									return;
								}
								break;
						}

						break;
					case OpCode.display:			//Display command (ignored by the sequencer)
						switch (data.bytes[1]) {
							case DisplayCmdCode.setVal:
								ptrn.position += 1;
								break;
							case DisplayCmdCode.setVal64:
								ptrn.position += 2;
								break;
							case 0xF0: .. case 0xFF:
								ptrn.position += data.hwords[1]>>2 + (data.hwords[1] & 3 ? 1 : 0);
								break;
							default:
								errors.unrecognizedCode = true;
								if (status.cfg_StopOnError) {
									status.play = false;
									return;
								}
								break;
						}
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
			if (patternData.length < ptrn.position || ptrn.position < 0) {	//Free up pattern slot if ended or has no useful data left.
				/* && !hasUsefulDataLeft(patternData[ptrn.position..$]) */
				ptrn.status.isRunning = false;
				ptrn.status.hasEnded = true;
				if (ptrn.backLink != PATTERN_SLOT_INACTIVE_ID) {
					foreach (size_t i, ref M2PatternSlot ptrnSl ; songdata.ptrnSl) {
						if (ptrnSl.id == ptrn.backLink) {
							ptrn.status.suspend = false;
						}
					}
				}
				ptrn.id = PATTERN_SLOT_INACTIVE_ID;
			}
		}
	}
	///Initializes new pattern with the given ID
	private void initNewPattern(uint patternID, uint backLink) @nogc @safe pure nothrow {
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
				ptrnSl.status.isRunning = true;
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
			M2Command data = M2Command(key);
			if (data.bytes[0] != 0x00 || data.bytes[0] != 0xff) return true;    //Has at least one potential command.
		}
		return false;
	}
	private UMP trnsps(UMP u, TransposingData td) @nogc nothrow {
		if (td.mode == TransposeMode.chromatic) {
			u.note = cast(ubyte)(u.note + td.amount);
		}//TODO: Implement non-chromatic transposing
		return u;
	}
	private void emitMIDIData_intrnl(bool transpose = false)(uint[] data, DeviceData dd, AudioModule am) @nogc nothrow {
		uint pos;
		while (pos < data.length) {
			UMP midiPck;
			midiPck.base = data[pos];
			const uint cmdSize = umpSizes[midiPck.msgType]>>5;
			if (cmdSize + pos > data.length) {
				errors.illegalMIDICmd = true;
				if (status.cfg_StopOnError) status.play = false;
				return;
			} else {
				switch (cmdSize) {
					case 2:
						static if (transpose) {
							switch (midiPck.status) {
								case MIDI2_0Cmd.NoteOn, MIDI2_0Cmd.NoteOff, MIDI2_0Cmd.PolyAftrTch, MIDI2_0Cmd.PolyPitchBend, 
										MIDI2_0Cmd.PolyCtrlCh, MIDI2_0Cmd.PolyCtrlChR:
									midiPck = trnsps(midiPck, dd.trnsp);
								break;
								default: break;
							}
						}
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
						static if (transpose) {
							switch (midiPck.status) {
								case MIDI1_0Cmd.NoteOn, MIDI1_0Cmd.NoteOff, MIDI1_0Cmd.PolyAftrTch:
									midiPck = trnsps(midiPck, dd.trnsp);
								break;
								default: break;
							}
						} 
						am.midiReceive(midiPck);
						pos += 1;
						break;
				}
			}
		}
	}
	/** 
	 * Emits MIDI data to the target module. Takes care of data length, transposing (TODO: implement), etc.
	 */
	private void emitMIDIData(uint[] data, uint targetID) @nogc nothrow {
		DeviceData dd = modTrgt[targetID];
		AudioModule am = dd.mod;
		if (am is null) {
			errors.unrecognizedCode = true;
			if (status.cfg_StopOnError) status.play = false;
			return;
		}
		if (dd.trnsp.amount) {
			emitMIDIData_intrnl!(true)(data, dd, am);
		} else {
			emitMIDIData_intrnl!(false)(data, dd, am);
		}
	}
}