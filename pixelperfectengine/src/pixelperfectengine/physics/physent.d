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


public struct PhysEnt {
	///Stores potential gravity values. The default physics resolver expects at least a single entry.
	///Index 0 should be set to no gravity.
	///DO NOT MODIFY ENTRIES OR RESIZE IT WHILE PHYSICS RESOLVER IS RUNNING! USE THE APPROPRIATE FUNCTIONS TO ACCESS
	///IT OUTSIDE OF PHYSICS RESOLVING!
	__gshared DynArray!(Vec2)* gravity;
	shared static this() {
		gravity = nogc_allocate!(DynArray!(Vec2))();
		gravity ~= Vec2(0.0);
	}
	shared static ~this() {
		gravity.free();
		gravity.nogc_free();
	}
	static Vec2 setGravityGroup(ubyte index, Vec2 value) @trusted @nogc nothrow {
		Vec2 result;
		synchronized {
			if (gravity.length > index) gravity[index] = value;
			else gravity ~= value;
		}
		return result;
	}
	DVec2 position = DVec2(0.0);		///X-Y positions
	Vec2 velocity = Vec2(0.0);			///X-Y velocity
	Vec2 acceleration = Vec2(0.0);		///X-Y acceleration
	float weight = 0.0;					///Weight of the physics entity
	uint bitflags;
	ushort restingDirI;					///0-360° on a 2D plane
	ubyte gravityGr;					///Gravity group selector
	mixin(ECS_MACRO);
	static enum RESTING	=	1<<0;		///Set if object is resting on one direction.
	mixin(BITFLAG_GET_MACRO!(`resting`, `RESTING`));
	mixin(BITFLAG_SET_MACRO!(`resting`, `RESTING`));
	double restingDir() @nogc @safe pure nothrow const {
		return restingDirI * (1.0 / usnort.max) * PI * 2;
	}
	double restingDir(double theta) @nogc @safe pure nothrow {
		restingDirI = cast(ushort)(cast(int)((theta / (PI * 2)) * ushort.max));
		return restingDirI * (1.0 / usnort.max) * PI * 2;
	}
	double velocityTotal() @nogc @safe pure nothrow const {
		return sqrt((velocity.x * velocity.x) + (velocity.y * velocity.y));
	}
	double accelTotal() @nogc @safe pure nothrow const {
		return sqrt((acceleration.x * acceleration.x) + (acceleration.y * acceleration.y));
	}
	double kineticEnergy() @nogc @safe pure nothrow const {
		return weight * ((velocity.x * velocity.x) + (velocity.y * velocity.y)) * 0.5;
	}
	void resolvePhysics(const float deltaTime) @nogc @safe pure nothrow {
		position += velocity * deltaTime;
		Vec2 localGr = gravity[gravityGr];
		if (resting) {
			Vec2 restingVec = Vec2([cos(restingDir), -sin(restingDir)]);
			Vec2 normAcc = acceleration / accelTotal;
			localGr += Vec2([abs(abs(normAcc.x) - abs(restingVec.x)), abs(abs(normAcc.y) - abs(restingVec.y))]);
		} else {
			velocity += acceleration * deltaTime;
			acceleration += ((acceleration + localGr) / (1 + kineticEnergy)) * deltaTime;
		}
	}
}
