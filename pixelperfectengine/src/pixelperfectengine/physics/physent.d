module pixelperfectengine.physics.physent;

/*
 * Copyright (C) 2015-2020, 2025, by Laszlo Szeremi under the Boost license.
 *
 * Pixel Perfect Engine, physics.physent (physics entity) module.
 */

import pixelperfectengine.system.ecs;
import pixelperfectengine.system.memory;
public import pixelperfectengine.system.intrinsics;

import inteli.types;
import std.math;

/**
 * Default physics entity and resolver. Uses floating-point calculations
 */
public struct PhysEnt {
	//TODO: Read about how the shared keyword works with structs, or at least with array slices
	///Stores potential gravity values. The default physics resolver expects at least a single entry.
	///Index 0 should be set to no gravity.
	///DO NOT MODIFY ENTRIES OR RESIZE IT WHILE PHYSICS RESOLVER IS RUNNING! USE THE APPROPRIATE FUNCTIONS TO ACCESS
	///IT OUTSIDE OF PHYSICS RESOLVING!
	private static DynArray!(Vec2)* gravity;
	shared static this() {
		gravity = nogc_allocate!(DynArray!(Vec2))();
		*gravity ~= Vec2(0.0);
	}
	shared static ~this() {
		gravity.free();
		gravity.nogc_free();
	}
	static Vec2 setGravityGroup(ubyte index, Vec2 value) @trusted @nogc nothrow {
		Vec2 result;
		synchronized {
			if (gravity.length > index) (*gravity)[index] = value;
			else *gravity ~= value;
		}
		return result;
	}
	DVec2 position = DVec2(0.0);		///X-Y positions
	Vec2 velocity = Vec2(0.0);			///X-Y velocity
	Vec2 acceleration = Vec2(0.0);		///X-Y acceleration, set to zero alongside with gravity to keep constant velocity.
	float weight = 0.0;					///Weight of the physics entity
	uint bitflags;
	ushort restingDirI;					///0-360° on a 2D plane
	ubyte gravityGr;					///Gravity group selector, should be set to zero if deacceleration is not needed.
	mixin(ECS_MACRO);
	static enum RESTING	= 1<<0;			///Set if object is resting on one direction.
	///Set if object velocity to be affected by gravity (only acceleration is affected by default).
	///Useful for use alongside with bitflag `RESTING`.
	static enum DEACC_BY_GRAV = 1<<1;
	mixin(BITFLAG_GET_MACRO!(`resting`, `RESTING`));
	mixin(BITFLAG_SET_MACRO!(`resting`, `RESTING`));
	mixin(BITFLAG_GET_MACRO!(`deaccelerateByGravity`, `DEACC_BY_GRAV`));
	mixin(BITFLAG_SET_MACRO!(`deaccelerateByGravity`, `DEACC_BY_GRAV`));
	double restingDir() @nogc @safe pure nothrow const {
		return restingDirI * (1.0 / ushort.max) * PI * 2;
	}
	double restingDir(double theta) @nogc @safe pure nothrow {
		restingDirI = cast(ushort)(cast(int)((theta / (PI * 2)) * ushort.max));
		return restingDirI * (1.0 / ushort.max) * PI * 2;
	}
	double velocityTotal() @nogc @safe pure nothrow const {
		return sqrt((velocity.x * velocity.x) + (velocity.y * velocity.y));
	}
	double accelTotal() @nogc @safe pure nothrow const {
		return sqrt((acceleration.x * acceleration.x) + (acceleration.y * acceleration.y));
	}
	double kineticEnergy() @nogc @safe pure nothrow const {
		return weight * sqrt((velocity.x * velocity.x) + (velocity.y * velocity.y)) * 0.5;
	}
	/**
	 * Resolves physics for this entity. Does not do any other calculations or physics related things.
	 * Params:
	 *   deltaTime = The lapsed time, in seconds.
	 */
	void resolvePhysics(const float deltaTime) @nogc @trusted nothrow {
		position += velocity * deltaTime;
		velocity += acceleration * deltaTime;
		Vec2 localGr = (*cast(DynArray!(Vec2)*)(gravity))[gravityGr];
		const double gravityEnergy = weight * sqrt((localGr.x * localGr.x) + (localGr.y * localGr.y)) * 0.5;
		const double energyRatio = gravityEnergy / (kineticEnergy + gravityEnergy);
		if (resting) localGr *= Vec2([abs(cos(restingDir)), abs(sin(restingDir))]);
		acceleration = (acceleration * (1.0 - energyRatio)) + (localGr * energyRatio);
		if (deaccelerateByGravity) velocity -= velocity * energyRatio;
	}
}
