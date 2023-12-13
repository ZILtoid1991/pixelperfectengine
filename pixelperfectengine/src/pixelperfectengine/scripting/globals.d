module pixelperfectengine.scripting.globals;

//NOTE: This file is a placeholder until a new and usable scripting engine will be found.
//Due to utter difficulties with the Lua binding, which included values getting zeroed out for no reason, functions
//become uncallable from the D side for no known reasons, and even issues I've previously solved kept reappearing all
//while the fixes were not been removed.
//Please contact me with recommendations. New candidate must have integer support and must not be larger than this 
//engine.

import pixelperfectengine.graphics.raster;
import pixelperfectengine.graphics.bitmap;
import pixelperfectengine.audio.base.handler;
public import pixelperfectengine.system.timer;
public import pixelperfectengine.system.rng;

import collections.hashmap;

///Contains the main raster to be used with scripting engines.
public Raster mainRaster;
///Contains the main module manager to be used with scripting engines.
public ModuleManager modMan;
///The bitmap resource manager for scripting purposes.
///Any bitmap to be used by a scripting engine, especially if said scripting engine is an
///external entity (DLL, etc), should be stored here to keep a reference around to avoid 
///them being destroyed by the garbage collector.
public HashMap!(string, ABitmap) scrptResMan;
public RandomNumberGenerator rng;