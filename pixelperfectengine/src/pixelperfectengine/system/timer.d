module pixelperfectengine.system.timer;
/*
 * Copyright (C) 2015-2021, by Laszlo Szeremi under the Boost license.
 *
 * Pixel Perfect Engine, system.timer module
 */
import collections.sortedlist;
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
 * Delegates take the `jitter` argument, which is the overshoot of the time.
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
	protected SortedList!Entry	timerList;		///The list of timer entries.
	protected Entry[]			timerRegs;		///Secondary timer list
	protected uint				status;			///1 if during testing, 0 otherwise
	///CTOR
	public this() @safe pure nothrow {

	}
	/**
	 * Registers an entry for the timer.
	 * Delta sets the amount of time into the future.
	 */
	public void register(TimerReceiver dg, Duration delta) @safe nothrow {
		if (!status)
			timerList.put(Entry(dg, MonoTime.currTime + delta));
		else
			timerRegs ~= Entry(dg, MonoTime.currTime + delta);
	}
	/**
	 * Tests the entries.
	 * If enough time has passed, then those entries will be called and deleted.
	 */
	public void test() {
		status = 1;
		while (timerList.length) {
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
		status = 0;
	}
}
