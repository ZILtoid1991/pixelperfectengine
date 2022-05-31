module pixelperfectengine.audio.base.midiseq;

import mididi;
import midi2.types.enums;
import midi2.types.structs;
import core.time : Duration, usecs;

import pixelperfectengine.audio.base.modulebase;

/** 
 * Intended to synchronize any sequencer with audio playback.
 */
public interface Sequencer {
	/**
	 * Makes the sequencer to go forward by the given amount of time, and emits MIDI commands to the associated modules
	 * if the time have reached that point.
	 * Params:
	 *   amount = the time amount that have been lapsed, ideally the buffer length in time, alternatively a frame delta
	 * if one wants to tie MIDI sequencing to screen update rate (not recommended).
	 */
	public void lapseTime(Duration amount) @nogc nothrow;
}
/** 
 * Implements a MIDI v1.0 sequencer.
 *
 * Since MIDI v2.0 isn't widespread (and seems like I even have to implement my own format) and v1.0 is widespread and
 * still capable enough (even if getting the most out of it needs some klunkiness), I'm creating an internal sequencer
 * for this format too.
 * By using multiple tracks, it's able to interface with multiple modules.
 */
public class SequencerM1 : Sequencer {
	enum Status {
		IsRunning	=	1<<0,	///Set if sequencer is running	
		LoopEnable	=	1<<1,	///Set if looping is enabled
		FoundLoop	=	1<<2,	///Set if sequencer found a loop point
		Ended		=	1<<8,	///Set if the sequence ended naturally
	}
	protected uint				status;			///Stores status flags, see enum Status
	protected MIDI				src;			///Source file deconstructed.
	protected AudioModule[]		modules;		///Module list.
	public uint[]				routing;		///Routings for multi-track MIDI files.
	public ubyte[]				routGrp;		///Group routing for each module.
	protected Duration[]		positionTime;	///Current time position for all individual tracks.
	protected size_t[]			positionBlock;	///Current event position for all individual tracks.
	protected uint[]			usecPerTic;		///Precalculated microseconds per tic (per track) for less complexity.
	///States of the tracks.
	///Bit 0 : End of track marker has reached.
	protected ubyte[]			trackState;
	///Save states for looping.
	protected Duration[]		lp_positionTime;	
	protected size_t[]			lp_positionBlock;	
	protected uint[]			lp_usecPerTic;		
	protected ubyte[]			lp_trackState;
	public this(AudioModule[] modules, uint[] routing, ubyte[] routGrp) @safe pure nothrow {
		this.modules = modules;
		this.routing = routing;
		this.routGrp = routGrp;
	}
	/** 
	 * Loads a MIDI file into the sequencer, and initializes some basic data.
	 * Params:
	 *   src = the MIDI file to be loaded.
	 */
	public void openMIDI(MIDI src) @safe {
		this.src = src;
		//positionTime.length = 0;
		positionTime.length = src.headerChunk.nTracks;
		//positionBlock.length = 0;
		positionBlock.length = src.headerChunk.nTracks;
		//usecPerTic.length = 0;
		usecPerTic.length = src.headerChunk.nTracks;
		//trackState.length = 0;
		trackState.length = src.headerChunk.nTracks;
	}
	/** 
	 * Starts the sequencer.
	 */
	public void start() @nogc @safe pure nothrow {
		status |= Status.IsRunning;
	}
	/** 
	 * Stops the sequencer.
	 */
	public void stop() @nogc @safe pure nothrow {
		status &= ~Status.IsRunning;
		reset();
	}
	/** 
	 * Resets the sequencer.
	 */
	public void reset() @nogc @safe pure nothrow {
		for (ushort i ; i < usecPerTic.length ; i++) {
			setTimeDiv(500_000,i);	///Assume 120 beats per second.
			positionTime[i] = Duration.init;
			positionBlock[i] = size_t.init;
			trackState[i] = ubyte.init;
		}
	}
	/** 
	 * Pauses the sequencer.
	 * Note: Won't pause states of associated modules.
	 */
	public void pause() @nogc @safe pure nothrow {
		status &= ~Status.IsRunning;
	}
	/** 
	 * Enables looping (marked with `LOOPBEGIN` and `LOOPEND`), then repeates the MIDI data between these points until 
	 * either looping gets disabled, or the sequencer gets shut down.
	 * Params:
	 *   val = 
	 */
	public bool enableLoop(bool val) @nogc @safe pure nothrow {
		if (val)
			status |= Status.LoopEnable;
		else
			status &= ~Status.LoopEnable;
		return (status & Status.LoopEnable) != 0;
	}
	/** 
	 * Sets the time division for the given track
	 * Params:
	 *   usecPerQNote = Microseconds per quarter note, in case if a tempo change event happens.
	 *   track = The track number, in case if a tempo change event happens.
	 */
	protected final void setTimeDiv(uint usecPerQNote, size_t track = 0) @nogc @safe pure nothrow {
		if (src.headerChunk.division.getFormat == 0) {
			usecPerTic[track] = usecPerQNote / src.headerChunk.division.getTicksPerQuarterNote();
		} else {
			switch (src.headerChunk.division.getNegativeSMPTEFormat()) {
				case -29:
					usecPerTic[track] = cast(uint)(29.97 * src.headerChunk.division.getTicksPerFrame());
					break;
				default:
					usecPerTic[track] = cast(uint)(-1 * src.headerChunk.division.getNegativeSMPTEFormat() * 
							src.headerChunk.division.getTicksPerFrame());
					break;
			}
		}
	}
	/**
	 * Makes the sequencer to go forward by the given amount of time, and emits MIDI commands to the associated modules
	 * if the time have reached that point.
	 * Params:
	 *   amount = the time amount that have been lapsed, ideally the buffer length in time, alternatively a frame delta
	 * if one wants to tie MIDI sequencing to screen update rate.
	 */
	public void lapseTime(Duration amount) @nogc nothrow {
		if (!(status & Status.IsRunning)) return;
		foreach (size_t i , ref Duration d ; positionTime) {
			if (!(trackState[i] & 1) && (positionBlock[i] < src.trackChunks[i].events.length)) {
				d += amount;
				Duration toEvent = ticsToDuration(src.trackChunks[i].events[positionBlock[i]].deltaTime, i);
				if (d >= toEvent) {	//process event
					d = toEvent - d;
					//MIDIEvent currEv = src.trackChunks[i].events[positionBlock[i]];
					switch (src.trackChunks[i].events[positionBlock[i]].statusByte()) {
						case 0xF0:	///SYSEX event
							SysExEvent* ev = src.trackChunks[i].events[positionBlock[i]].asSysExEvent;
							if (ev.data.length <= 6) {
								UMP first = UMP(MessageType.Data64, routGrp[i], SysExSt.Complete, cast(ubyte)ev.data.length);
								uint second;
								if (ev.data.length > 1) 
									first.bytes[2] = ev.data[0];
								if (ev.data.length > 2) 
									first.bytes[3] = ev.data[1];
								for (int j = 2 ; i < ev.data.length ; j++) {
									second |= ev.data[j]<<(24 - (8 * (2-j)));
								}
								modules[routing[i]].midiReceive(first, second);
							} else {
								size_t pos;
								while (pos < ev.data.length) {
									const sizediff_t diff = ev.data.length - pos;
									ubyte sysExSt = SysExSt.Cont;
									if (!diff) sysExSt = SysExSt.Start;
									else if (diff < 6) sysExSt = SysExSt.End;
									UMP first = UMP(MessageType.Data64, routGrp[i], sysExSt, cast(ubyte)ev.data.length);
									uint second;
									if (diff > 1) 
										first.bytes[2] = ev.data[pos + 0];
									if (diff > 2) 
										first.bytes[3] = ev.data[pos + 1];
									for (int j = 2 ; i < diff && j < 6 ; j++) {
										second |= ev.data[pos + j]<<(24 - (8 * (2-j)));
									}
									pos += 6;
									modules[routing[i]].midiReceive(first, second);
								}
							}
							break;
						case 0xFF:	///Meta event
							MetaEvent* ev = src.trackChunks[i].events[positionBlock[i]].asMetaEvent;
							switch (ev.type) {
								case MetaEventType.setTempo:
									setTimeDiv((ev.data[0]<<16) | (ev.data[1]<<8) | ev.data[2], i);
									break;
								case MetaEventType.endOfTrack:
									trackState[i] |= 1;
									break;
								case MetaEventType.marker, MetaEventType.cuePoint:
									switch (cast(string)ev.data) {	//Process looppoint events
										case "LOOPBEGIN"://Save states
											lp_positionBlock = positionBlock;
											lp_positionTime = positionTime;
											lp_trackState = trackState;
											lp_usecPerTic = usecPerTic;
											status |= Status.FoundLoop;
											break;
										case "LOOPEND":
											if ((status & Status.LoopEnable) && (status & Status.FoundLoop)) {
												positionBlock = lp_positionBlock;
												positionTime = lp_positionTime;
												trackState = lp_trackState;
												usecPerTic = lp_usecPerTic;
											}
											break;
										default:
											break;
									}
									break;
								default:
									break;
							}
							break;
						default:	///MIDI event
							MIDIEvent* ev = src.trackChunks[i].events[positionBlock[i]].asMIDIEvent;
							modules[routing[i]].midiReceive(UMP(MessageType.MIDI1, routGrp[i], ev.statusByte>>4, ev.statusByte & 0x0F, 
									ev.data[0], ev.data[1]));
							break;
					}
					positionBlock[i]++;
				}
			}
		}
	}
	/** 
	 * Converts MIDI tics to Duration.
	 * Params:
	 *   tics = The MIDI tics.
	 *   track = The MIDI track itself.
	 * Returns: The 
	 */
	final protected Duration ticsToDuration(int tics, size_t track) @nogc @safe pure nothrow const {
		return usecs(tics * usecPerTic[track]);
	}
}