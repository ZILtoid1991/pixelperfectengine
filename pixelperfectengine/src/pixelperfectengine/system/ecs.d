module pixelperfectengine.system.ecs;

/*
 * Copyright (C) 2015-2025, by Laszlo Szeremi under the Boost license.
 *
 * PixelPerfectEngine, entity component system module
 */


/**
 * Macro created to add structs and/or classes to the engine's own entity component system.
 * Use `mixin(ECS_MACRO);` inside a struct to use it.
 */
static immutable string ECS_MACRO = q"{
	int ecsID;
	int opCmp(const ref int rhs) @nogc @safe pure nothrow const {
		return (ecsID > rhs) - (ecsID < rhs);
	}
	bool opEquals(const ref int rhs) @nogc @safe pure nothrow const {
		return ecsID == rhs;
	}
	int opCmp(OT)(const ref OT rhs) @nogc @safe pure nothrow const {
		return (ecsID > rhs.ecsID) - (ecsID < rhs.ecsID);
	}
	bool opEquals(OT)(const ref OT rhs) @nogc @safe pure nothrow const {
		return ecsID == rhs.ecsID;
	}
	size_t toHash() @nogc @safe pure nothrow const {
		return ecsID;
	}
}";
