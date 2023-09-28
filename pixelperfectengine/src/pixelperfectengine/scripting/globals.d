module pixelperfectengine.scripting.globals;

import pixelperfectengine.graphics.raster;
import pixelperfectengine.graphics.bitmap;
import pixelperfectengine.audio.base.handler;

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