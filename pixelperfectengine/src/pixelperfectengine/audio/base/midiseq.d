module pixelperfectengine.audio.base.midiseq;

import mididi;
import midi2.types.enums;
import midi2.types.structs;
import core.time : Duration;

import pixelperfectengine.audio.base.modulebase;

/** 
 * Implements a MIDI v1.0 sequencer.
 *
 * Since MIDI v2.0 isn't widespread (and seems like I even have to implement my own format) and v1.0 is widespread and
 * still capable enough (even if getting the most out of it needs some klunkiness), I'm creating an internal sequencer
 * for this format too.
 * By using multiple tracks, it's able to interface with multiple modules.
 */
public class SequencerM1 {
	protected MIDI				src;	///Source file deconstructed.
	protected AudioModule[]		modules;///Module list.
	protected uint[2][]			routing;///Routings for multi-track MIDI files. 0: MIDI track number, 1: Audio module.
	protected Duration[]		positionTime;///Current time position for all individual tracks.
	protected size_t[]			positionBlock;///Current event position for all individual tracks.
	public this(AudioModule[] modules, uint[2][] routing) @safe {
		this.modules = modules;
		this.routing = routing;
	}
	/** 
	 * Loads a MIDI file into the sequencer.
	 * Params:
	 *   src = the MIDI file to be loaded.
	 */
	public void openMIDI(MIDI src) @safe {
		this.src = src;
		positionTime.length = 0;
		positionTime.length = src.headerChunk.nTracks;
		positionBlock.length = 0;
		positionBlock.length = src.headerChunk.nTracks;
	}
	/**
	 * Makes the sequencer to go forward by the given amount of time, and emits MIDI commands to the associated modules
	 * if the time have reached that point.
	 * Params:
	 *   amount = the time amount that have been lapsed, ideally the buffer length in time.
	 */
	public void lapseTime(Duration amount) @nogc nothrow {

	}
	/** 
	 * Compares MIDI time with Duration.
	 * Params:
	 *   lhs = MIDI time.
	 *   rhs = Duration.
	 * Returns: 1 if lhs is greater, 0 if equal, -1 if rhs is greater.
	 */
	final protected int cmprDuration(int lhs, Duration rhs) @nogc @safe pure nothrow const {
		return 0;
	}
}