module pixelperfectengine.physics.physent;

/*
 * Copyright (C) 2015, by Laszlo Szeremi under the Boost license.
 *
 * Pixel Perfect Engine, physics.physent (physics entity) module.
 */

import pixelperfectengine.system.ecs;
import pixelperfectengine.system.memory;
public import pixelperfectengine.system.intrinsics;

import inteli.types;
import std.math;
import core.atomic;

/**
 * Default physics entity and resolver. Uses floating-point calculations.
 * It is only for simple kind of physics, does not support true rotation or chaining.
 * Does support acceleration, attraction by gravity, constant speed, etc. However, for
 * simplicity sake, constant speed must be done by setting gravity to zero.
 * Resolving and gravity groups are thread safe.
 */
public struct PhysEnt {
	//TODO: Read about how the shared keyword works with structs, or at least with array slices
	///Stores potential gravity values. The default physics resolver expects at least a single entry.
	///Index 0 should be set to no gravity, as it is needed for constant speed objects.
	///DO NOT MODIFY ENTRIES OR RESIZE IT WHILE PHYSICS RESOLVER IS RUNNING! USE THE APPROPRIATE FUNCTIONS TO ACCESS
	///IT OUTSIDE OF PHYSICS RESOLVING!
	private static shared float[] gravity;
	shared static this() {
		gravity = cast(shared float[])nogc_newArray!float(2);
		gravity[0] = 0;
		gravity[1] = 0;
	}
	shared static ~this() {
		synchronized {
			float[] wgr = cast(float[])gravity;
			nogc_free(wgr);
			gravity = cast(shared float[])wgr;
		}
	}
	/**
	 * Sets the value of the given gravity group in a thread-safe way.
	 * Params:
	 *   index = The index of the gravity group. If greater than the current one, the underlying array will be resized
	 * to fit the new parameter (maximum number is 256).
	 *   value = The value to set the gravity group to. Must not be NaN.
	 * Returns: The newly set value, or Vec2(float.nan) if value is illegal.
	 */
	static Vec2 setGravityGroup(ubyte index, Vec2 value) @trusted @nogc nothrow {
		if (isNaN(value.x) || isNaN(value.y)) return Vec2(float.nan);
		Vec2 result;
		synchronized {
			float[] wgr = cast(float[])gravity;
			if (wgr.length / 2 <= index) {
				wgr.nogc_resize((index + 1) * 2);
			}
			wgr[index * 2] = value.x;
			wgr[index * 2 + 1] = value.y;
			result.x = wgr[index * 2];
			result.y = wgr[index * 2 + 1];
			gravity = cast(shared float[])wgr;
		}
		return result;
	}
	/**
	 * Gets the value of the given gravity group in a thread-safe way.
	 * Params:
	 *   index = The index of the gravity group.
	 * Returns: The value of the gravity group, or Vec2(float.nan) if value is illegal.
	 */
	static Vec2 getGravityGroup(ubyte index) @trusted @nogc nothrow {
		Vec2 result;
		synchronized {
			float[] wgr = cast(float[])gravity;
			if (index > wgr.length / 2) return Vec2(float.nan);
			result.x = wgr[index * 2];
			result.y = wgr[index * 2 + 1];
		}
		return result;
	}
	/// Returns the number of valid gravity groups.
	static size_t getNumOfGravityGroups() @trusted @nogc nothrow {
		size_t result;
		synchronized {
			float[] wgr = cast(float[])gravity;
			result = wgr.length / 2;
		}
		return result;
	}
	DVec2 position = DVec2(0.0);		///X-Y positions
	Vec2 velocity = Vec2(0.0);			///X-Y velocity
	Vec2 acceleration = Vec2(0.0);		///X-Y acceleration, set to zero alongside with gravity to keep constant velocity.
	float weight = 0.0;					///Weight of the physics entity
	ushort restingDirI;					///0-360° on a 2D plane
	ubyte gravityGr;					///Gravity group selector, should be set to zero if deacceleration is not needed.
	ubyte bitflags;						///Bitflags used for packing binary options, use macros to access them
	mixin(ECS_MACRO);
	static enum RESTING	= 1<<0;			///Set if object is resting on one direction.
	///Set if object velocity to be affected by gravity (only acceleration is affected by default).
	///Useful for use alongside with bitflag `RESTING`.
	static enum DEACC_BY_GRAV = 1<<1;
	mixin(BITFLAG_GET_MACRO!(`resting`, `RESTING`));
	mixin(BITFLAG_SET_MACRO!(`resting`, `RESTING`));
	mixin(BITFLAG_GET_MACRO!(`deaccelerateByGravity`, `DEACC_BY_GRAV`));
	mixin(BITFLAG_SET_MACRO!(`deaccelerateByGravity`, `DEACC_BY_GRAV`));
	/**
	 * Returns the resting direction in radian clamped between 0-360 degrees.
 	 */
	double restingDir() @nogc @safe pure nothrow const {
		return restingDirI * (1.0 / ushort.max) * PI * 2;
	}
	/**
	 * Sets the resting direction in radian clamped between 0-360 degrees, then returns it.
	 */
	double restingDir(double theta) @nogc @safe pure nothrow {
		restingDirI = cast(ushort)(cast(int)((theta / (PI * 2)) * ushort.max));
		return restingDirI * (1.0 / ushort.max) * PI * 2;
	}
	/**
	 * Returns the velocity value of the entity.
	 */
	double velocityTotal() @nogc @safe pure nothrow const {
		return sqrt((velocity.x * velocity.x) + (velocity.y * velocity.y));
	}
	/**
	 * Returns the acceleration value of the entity.
	 */
	double accelTotal() @nogc @safe pure nothrow const {
		return sqrt((acceleration.x * acceleration.x) + (acceleration.y * acceleration.y));
	}
	/**
	 * Returns the kinetic energy of the entity.
	 */
	double kineticEnergy() @nogc @safe pure nothrow const {
		return weight * sqrt((velocity.x * velocity.x) + (velocity.y * velocity.y)) * 0.5;
	}
	/**
	 * Resolves physics for this entity. Does not do any other calculations or physics related things.
	 * Is thread safe.
	 * Params:
	 *   deltaTime = The lapsed time, in seconds.
	 */
	void resolvePhysics(const float deltaTime) @nogc @trusted nothrow {
		position += velocity * deltaTime;
		velocity += acceleration * deltaTime;
		Vec2 localGr = Vec2([atomicLoad(gravity[gravityGr * 2]), atomicLoad(gravity[gravityGr * 2 + 1])]);
		const double gravityEnergy = weight * sqrt((localGr.x * localGr.x) + (localGr.y * localGr.y)) * 0.5;
		const double energyRatio = gravityEnergy / (kineticEnergy + gravityEnergy);
		if (resting) localGr *= Vec2([abs(cos(restingDir)), abs(sin(restingDir))]);
		acceleration = (acceleration * (1.0 - energyRatio)) + (localGr * energyRatio);
		if (deaccelerateByGravity) velocity -= velocity * energyRatio;
	}
}
