/*
This is a template for creating GUI apps with PixelPerfectEngine's Concrete subsystem.
Contains the skeleton, that a GUI application needs.
Feel free to rename, or even completely change things!
 */

module guiapp;

//Imports that are mandatory for a minimum viable PPE Concrete GUI app
import pixelperfectengine.graphics.outputscreen;	//Output screen import
import pixelperfectengine.graphics.layers;			//Imports mandatory layer related things, especially the SpriteLayer
import pixelperfectengine.graphics.raster;			//Imports the Raster class to handle one or more layers at once
import pixelperfectengine.concrete.window;			//Imports everything needed for windowing (the Window class, elements, etc.).
import pixelperfectengine.system.input;				//This gives us to read user inputs (mouse, keyboard, etc.)
import pixelperfectengine.system.systemutility;		//It has the INIT_CONCRETE() function, important for setting and loading standards for Concrete.
import pixelperfectengine.system.file;				//Bitmap file loading
import pixelperfectengine.system.timer;				//Not mandatory, but a lack of timer.test() calls make certain GUI events not work.
import std.typecons : BitFlags;
import std.algorithm.searching : startsWith;
import bindbc.opengl;								//Import OpenGL for initialization and

import core.thread;                                 //Imported due to the Thread.sleep() function, only needed for reduced raster refresh operations.

enum SCREEN_WIDTH = 848;	///Initial screen width, in pixels
enum SCREEN_HEIGHT = 480;	///Initial screen height, in pixels
int guiScaling = 2;		///Initial screen scaling
/// The main function of the application.
/// Feel free to add `string[] args` if needed!
int main(string[] args) {
	foreach (string arg ; args) {	//Accessibility option: since not everyone will have a big enough screen, add option for setting the GUI scaling from command line
		if (arg.startsWith("--ui-scaling=")) {
			try {
				guiScaling = arg[13..$].to!int;
			} catch (Exception e) {

			}
		}
	}
	INIT_CONCRETE();					//Initializes the Concrete subsystem of the engine.
	SampleApp app = new SampleApp();	//Creates an instance of the class that contains the app instance. It is much easier to do things this way.
	app.whereTheMagicHappens();			//Calls the main loop of the app.
	return 0;							//Everything went alright, return with value 0.
}
/// The class containing the basic application logic and classes that are needed for the app.
class SampleApp : InputListener, SystemEventListener {
	Raster				mainRaster;		///To manage our layers and palette
	OSWindow			outScrn;		///An output window with OpenGL to display the framebuffer
	SpriteLayer			sprtL;			///To display the sprites for the windows
	WindowHandler		wh;				///To manage the the windows
	InputHandler		ih;				///To accept inputs from the user
	ConfigurationProfile	cfg;		///To manage configuration profiles
	//Bitflags block
	enum StateFlags {
		isRunning		=	1<<0,
		fullScreen		=	1<<1,
		flipScreen		=	1<<2,
	}
	BitFlags!StateFlags	stateFlags;
	/// Initializes every other things that wasn't initialized in other places.
	public this() {
		outScrn = new OSWindow("Your app name here!", -1, -1, SCREEN_WIDTH * guiScaling, SCREEN_HEIGHT * guiScaling,
				WindowCfgFlags.IgnoreMenuKey);//Creates an output window with the display size of 1696x960.
		outScrn.getOpenGLHandle();		//Initialize OpenGL
		const glStatus = loadOpenGL();	//Load the OpenGL symbols
		assert (glStatus >= GLSupport.gl11, "OpenGL not found!");	//Error out if openGL does not work
		mainRaster = new Raster(848,480,outScrn,0);					//Creates a raster with the size of 848x480.
		mainRaster.addLayer(sprtL,0);								//Adds the sprite layer to the raster.
		mainRaster.loadPalette(loadPaletteFromFile("../system/concreteGUIE1.tga")); //Loads the default palette from a supplied file containing icons.
		//Load additional fonts, icons, etc. here

		wh = new WindowHandler(SCREEN_WIDTH * guiScaling, SCREEN_HEIGHT * guiScaling,SCREEN_WIDTH, SCREEN_HEIGHT,
				sprtL,outScrn);		//Creates a window handler for the sizes of the windowhandler and raster.
		ih = new InputHandler();									//Initializes the input handler.
		ih.inputListener = this;									//Sets the input event output to this class.
		ih.systemEventListener = this;								//Sets the system event output to this class.
		ih.mouseListener = wh;										//Sets the mouse event output to the window handler.
		WindowElement.inputHandler = ih;							//Sets the input handler to be in charge of text input events, etc.
		//Delete the next two lines if you want refresh on every frame!
		WindowElement.onDraw = &rasterRefresh;						//Sets the draw event output of the window elements to a function of this class.
		Window.onDrawUpdate = &rasterRefresh;						//Sets the draw event output of the windows to a function of this class.
		stateFlags.isRunning = true;								//Set isRunning to true, so the main loop will stay running.
		//These two lines create a solid black background. Replace the bitmap with any other type and a loaded image to use a custom background instead
		Bitmap4Bit background = new Bitmap4Bit(848, 480);
		wh.addBackground(background);
		{	//Add keybinding for fullscreen support (remove it if you're using config files)
			import pixelperfectengine.system.input.scancode;
			ih.addBinding(BindingCode(ScanCode.F11, 0, Devicetype.Keyboard, 0, IGNORE_LOCKLIGHTS), InputBinding("fullscreen"));
		}
		//Add your initial windows to the window handler here!
	}
	/// Optional.
	/// Reduces unneeded screen updates and thus the CPU usage, which might be useful for GUI applications, especially
	/// on battery powered devices.
	/// However, this can interfere with other things, like non-GUI related screen updates, input-latency, etc.
	protected void rasterRefresh() {
		stateFlags.flipScreen = true;
	}
	/// Function that contains the main loop
	public void whereTheMagicHappens() {
		mainRaster.refresh();					//Initial raster refresh, not needed if raster refresh is set to be updated on every frame
		while(stateFlags.isRunning) {			//The main loop
			//Delete this if statement, if you want refresh on every frame!
			if (stateFlags.flipScreen) {					//This if statement is executed only when a draw function was called or a window was moved.
				stateFlags.flipScreen = false;				//sets boolean flipScreen to false once it's not needed.
				mainRaster.refresh();			//Refreshes the screen by running refresh on all associated layers of the raster
			}
			//mainRaster.refresh();				//Uncomment this line, if you want refresh on every frame!
			ih.test();							//Tests for input events, like keyboard, mouse, etc.
			timer.test();						//Tests for expired timer events.

			//Put additional things here you want to do on every loop!

			Thread.sleep(dur!"msecs"(10));		//To avoid high CPU usage from frequent input checks. Remove this line if you want refresh on every frame!
		}
		destroy(outputScreen);	//Make sure the destructors of our output screen run as intended.
		//Put stuff here you want to do upon quitting your program.

	}
	/// Called when a key event have done by the user.
	public void keyEvent(uint id, BindingCode code, Timestamp timestamp, bool isPressed) {
		switch (id) {
		case hashCalc("fullscreen"):
			if (isPressed) {
				stateFlags.fullScreen = !stateFlags.fullScreen;
				outScrn.setScreenMode(-1, stateFlags.fullScreen ? DisplayMode.FullscreenDesktop : DisplayMode.Windowed);
			}
			break;
		default:
			break;
		}
	}
	/// Called when an axis event have done by the user.
	public void axisEvent(uint id, BindingCode code, Timestamp timestamp, float value) {

	}
	/// Called when the user exits from the application.
	public void onQuit() {
		isRunning = false;
	}
	/**
	 * Called if a window was resized.
	 * Params:
	 *   window = Handle to the OSWindow class.
	 *   width = active area width.
	 *   height = active area height.
	 */
	public void windowResize(OSWindow window, int width, int height) {
		//This code will automatically resize the raster
		mainRaster.resizeRaster(cast(ushort)(width / guiScaling), cast(ushort)(height / guiScaling));
		wh.resizeRaster(width, height, width / guiScaling, height / guiScaling);
		glViewport(0, 0, width, height);
		rasterRefresh();
	}
	public void inputDeviceAdded(InputDevice id) {

	}
	public void inputDeviceRemoved(InputDevice id) {

	}
}
