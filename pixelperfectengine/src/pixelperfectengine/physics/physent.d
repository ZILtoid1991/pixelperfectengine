module pixelperfectengine.physics.physent;

/*
 * Copyright (C) 2015-2020, 2025, by Laszlo Szeremi under the Boost license.
 *
 * Pixel Perfect Engine, physics.physent (physics entity) module.
 */

import pixelperfectengine.system.ecs;
import pixelperfectengine.system.memory;

import inteli.types;

public struct PhysEnt {
	///Stores potential gravity values. The default physics resolver expects at least a single entry.
	///DO NOT MODIFY ENTRIES OR RESIZE IT WHILE PHYSICS RESOLVER IS RUNNING!
	shared DynArray!(float[2]) gravity;
	__m128d position = __m128d(0.0);	///X-Y positions
	float[2] velocity = [0.0, 0.0];		///X-Y velocity
	float[2] acceleration = [0.0, 0.0];	///X-Y acceleration
	float weight = 0.0;					///Weight of the physics entity
	uint bitflags;
	ubyte gravityGr;					///Gravity group selector
	mixin(ECS_MACRO);
}
