module pixelperfectengine.system.timer;
/*
 * Copyright (C) 2015-2021, by Laszlo Szeremi under the Boost license.
 *
 * Pixel Perfect Engine, system.timer module
 */
import collections.sortedlist;
import std.typecons : BitFlags;
public import core.time;

static CoarseTimer timer;

static this() {
	timer = new CoarseTimer();
}
/**
 * Implements a coarse timer, that checks the time periodically (e.g. on VSYNC), then calls the delegate if the time
 * assigned to it has been lapsed.
 * Is fast and can effectively test for multiple elements, but is inaccurate which can even fluctuate if tests are done
 * on VSYNC intervals. This will make the duration longer in every case (up to 16.7ms on 60Hz displays), but this
 * still should be accurate enough for many cases.
 * In theory, calls for test can be done separate from VSYNC intervals by running it in its own thread, but that can 
 * cause potential race issues.
 * Delegates take the `jitter` argument, which is the overshoot of the time.
 * Can be suspended for game pausing, etc., while keeping time deltas mostly accurate. Multiple instances of this class
 * can be used to create various effects from suspending the timer.
 */
public class CoarseTimer {
	alias TimerReceiver = void delegate(Duration jitter);
	/**
	 * A timer entry.
	 */
	protected struct Entry {
		TimerReceiver	onLapse;	///The delegate to be called.
		MonoTime		when;		///When the delegate must be called, in system time.
		int opCmp(const Entry other) const @nogc @trusted pure nothrow {
			return when.opCmp(other.when);
		}
		bool opEquals(const Entry other) const @nogc @trusted pure nothrow {
			return when == other.when;
		}
		size_t toHash() const @nogc @safe pure nothrow {
			return cast(size_t)when.ticks;
		}
	}
	protected enum StatusFlags {
		isTesting	=	1<<0,
		isPaused	=	1<<1,
	}
	protected SortedList!Entry	timerList;		///The list of timer entries.
	protected Entry[]			timerRegs;		///Secondary timer list.
	protected BitFlags!StatusFlags status;		///Contains various status flags.
	protected MonoTime			timeSuspend;	///Time when suspension happened.
	///CTOR (empty)
	public this() @safe pure nothrow {

	}
	/**
	 * Registers an entry for the timer.
	 * Params:
	 *    dg = the delegate to be called when the event is lapsed.
	 *    delta = sets the amount of time into the future.
	 */
	public void register(TimerReceiver dg, Duration delta) @safe nothrow {
		if (!status.isTesting)
			timerList.put(Entry(dg, MonoTime.currTime + delta));
		else
			timerRegs ~= Entry(dg, MonoTime.currTime + delta);
	}
	/**
	 * Tests the entries.
	 * If enough time has passed, then those entries will be called and deleted.
	 */
	public void test() {
		status.isTesting = true;
		while (timerList.length && !status.isPaused) {
			if (MonoTime.currTime >= timerList[0].when) {
				timerList[0].onLapse(MonoTime.currTime - timerList[0].when);
 				timerList.remove(0);
			} else {
				break;
			}
		}
		foreach (e ; timerRegs)
			timerList.put(e);
		timerRegs.length = 0;
		status.isTesting = true;
	}
	/** 
	 * Suspends the timer and saves the current timestamp to calculate timeshift caused by suspension.
	 */
	public void suspendTimer() {
		if(!status.isPaused) {
			status.isPaused = true;
			timeSuspend = MonoTime.currTime;
		}
	}
	alias suspend = suspendTimer;
	/** 
	 * Resumes timer and shifts all entries by given time delta.
	 */
	public void resumeTimer() {
		if(status.isPaused) {
			status.isPaused = false;
			const MonoTime timeResume = MonoTime.currTime;
			const Duration timeShift = timeResume - timeSuspend;
			//in theory, every entry should keep their position, so no list rebuilding is needed
			foreach (ref Entry key; timerList) {
				key.when += timeShift;
			}
		}
	}
	alias resume = resumeTimer;
}
