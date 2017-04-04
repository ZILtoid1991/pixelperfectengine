<<<<<<< HEAD
﻿# Pixel Perfect Engine ver 0.9.2-rc1
=======
# Pixel Perfect Engine ver 0.9.1
>>>>>>> origin/master
2D graphics engine written in D by László Szerémi (laszloszeremi@outlook.com)

Required libaries:
Derelict SDL2		https://github.com/DerelictOrg/DerelictSDL2
Derelict FI     https://github.com/DerelictOrg/DerelictFI

See Wiki for further info and version history!


# Usage with dub:
Sample dependencies section:
```
"dependencies": {
                "derelict-sdl2": "~>2.1.0",
		"derelict-fi": "~>2.0.3",
		"pixelperfectengine:pixelperfectengine": "*"
	},
```

# Usage with most IDEs:
1: Download and build the source. You will need both the engine and editor by default, as the engine uses its own custom bitmap format XMP due to its more advanced palette handling. Other advantages of the format is that it can store multiple bitmaps in a single file with no regard of their sizes.

2: Add /source/ to the include path.

3: Add the compiled library file in the /lib/ folder to your project.

4: Do not try to sell a subpar game written with this or any other engine on any storefront, especially if that barely has any original assets. :) 


# Known issues:
* If you add the dependency as "pixelperfectengine" or build using the command "dub build pixelperfectengine" it will fail. Probably dub related issue.
* The engine doesn't clear the framebuffer to spare some CPU time, this results some trippy effects if a part of the screen is not being overwritten.
* There's also some speed issues from it, as SDL2 writes the framebuffer back to the main memory. This will probably end up in the slow replacement of SDL2's graphical side with something faster.