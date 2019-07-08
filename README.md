# Pixel Perfect Engine ver 0.9.4-beta

2D retro graphics engine written in D by László Szerémi (laszloszeremi@outlook.com, https://twitter.com/ziltoid1991, https://www.patreon.com/ShapeshiftingLizard, https://ko-fi.com/D1D45NEN).

See Wiki for further info and version history!


# Usage with dub:
Sample dependencies section:
```
"dependencies": {
		"pixelperfectengine": "*"
	},
```

```
dependency "pixelperfectengine" version="*"
```

# Common usage:

* Make sure you copy the /system/ folder from the assets/_system folder, you might also want to make some changes to the configuration file here. Failing to do these will result in your program crashing due to missing files.
* I personally like to put binary files (executables and libraries) into a separate /bin/ folder, this will make it easy to port, since all you need to do is just replace this folder for different releases.
* The engine previously used various propiretary image formats. The last one used a hybrid XML/binary format, but was very prone to bugs, so instead TGA or PNG should be used (will be expanded later), with various extension options. (See extensions.md for more info)

# Known issues:

* The engine doesn't clear the framebuffer to spare some CPU time, this results some trippy effects if a part of the screen is not being overwritten.
* There's also some speed issues as SDL2 writes the framebuffer back to the main memory. This will probably end up in the slow replacement of SDL2's graphical side with something faster.
* WindowMakerForConcrete and PixelPerfectEditor are currently unfinished. The former will be soon working fully with extra features (such as undo/redo, snapping to grid and components), then the latter can be developed without an issue.
* Error handling isn't fully realized, so a lot of errors might happen. You can help me by reporting errors, testing on various systems (I only have access for an old Athlon64 X2 at the moment with relatively high-cost of upgrade).
* Upscaled sprites have a rather jerky, odd behavior when they're being partly obscured. This will be fixed, do not plan with it on the long run for a wacky effect.
* Upscaled sprites wider than 2048 pixels will cause some serious memory leakage issues.

# Future plans:

* Hardware acceleration, possibly through OpenCL since GLSL lacks the ability of reading textures as integers in older versions.
* Adding support for scripting languages (QScript, Lua, Python).
