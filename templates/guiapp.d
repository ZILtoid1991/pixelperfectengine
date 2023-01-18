/*
This is a template for creating GUI apps with PixelPerfectEngine's Concrete subsystem.
Contains the skeleton, that a GUI application needs.
Feel free to rename, or even completely change things!
 */

module guiapp;

//Imports that are mandatory for a minimum viable PPE Concrete GUI app
import pixelperfectengine.graphics.outputscreen;    //Output screen import
import pixelperfectengine.graphics.layers;          //Imports mandatory layer related things, especially the SpriteLayer
import pixelperfectengine.graphics.raster;          //Imports the Raster class to handle one or more layers at once
import pixelperfectengine.concrete.window;          //Imports everything needed for windowing (the Window class, elements, etc.).
import pixelperfectengine.system.input;             //This gives us to read user inputs (mouse, keyboard, etc.)
import pixelperfectengine.system.systemutility;     //It has the INIT_CONCRETE() function, important for setting and loading standards for Concrete.
import pixelperfectengine.system.file;              //Bitmap file loading
import pixelperfectengine.system.common;            //Has the initialzeSDL() function, needed for the engine to function as of now (might be replaced with INIT_IOTA() in the future)
import pixelperfectengine.system.timer;             //Not mandatory, but a lack of timer.test() calls make certain GUI events not work.

import core.thread;                                 //Imported due to the Thread.sleep() function, only needed for reduced raster refresh operations.

/// The main function of the application.
/// Feel free to add `string[] args` if needed!
int main() {
    initialzeSDL();                     //This function call initializes the SDL subsystem. Must be the first thing to be called for most things to work (graphics, input, etc)
    INIT_CONCRETE();                    //Initializes the Concrete subsystem of the engine.
    SampleApp app = new SampleApp();    //Creates an instance of the class that contains the app instance. It is much easier to do things this way.
    app.whereTheMagicHappens();         //Calls the main loop of the app.
    return 0;                           //Everything went alright, return with value 0.
}
/// The class containing the basic application logic and classes that are needed for the app.
class SampleApp : InputListener, SystemEventListener {
    Raster				mainRaster;
	OutputScreen		outScrn;
    SpriteLayer			sprtL;
    WindowHandler		wh;
    InputHandler        ih;
    //The next two are bitflags, can be unified into a single word to save on memory.
    bool                isRunning;
    bool                flipScreen;
    /// Initializes every other things that wasn't initialized in other places.
    public this() {
        sprtL = new SpriteLayer(RenderingMode.Copy);                //Creates a sprite layer to display the windows.
		outScrn = new OutputScreen("Your app name here!",1696,960); //Creates an output window with the display size of 1696x960.
		mainRaster = new Raster(848,480,outScrn,0);                 //Creates a raster with the size of 848x480.
		mainRaster.addLayer(sprtL,0);                               //Adds the sprite layer to the raster.
        mainRaster.loadPalette(loadPaletteFromFile("../system/concreteGUIE1.tga")); //Loads the default palette from a supplied file containing icons.
        outScrn.setMainRaster(mainRaster);                          //Sets the main raster of the output screen.
        //Load additional fonts, icons, etc. here

        wh = new WindowHandler(1696,960,848,480,sprtL);             //Creates a window handler for the sizes of the windowhandler and raster.
        ih = new InputHandler();                                    //Initializes the input handler.
        ih.inputListener = this;                                    //Sets the input event output to this class.
        ih.systemEventListener = this;                              //Sets the system event output to this class.
        ih.mouseListener = wh;                                      //Sets the mouse event output to the window handler.
        WindowElement.inputHandler = ih;                            //Sets the input handler to be in charge of text input events, etc.
        //Delete the next two lines if you want refresh on every frame!
        WindowElement.onDraw = &rasterRefresh;                      //Sets the draw event output of the window elements to a function of this class.
        Window.onDrawUpdate = &rasterRefresh;                       //Sets the draw event output of the windows to a function of this class.
        isRunning = true;                                           //Set isRunning to true, so the main loop will stay running.

        //Add your initial windows to the window handler here!
    }
    /// Optional.
    /// Reduces unneeded screen updates and thus the CPU usage, which might be useful for GUI applications, especially
    /// on battery powered devices.
    /// However, this can interfere with other things, like non-GUI related screen updates, input-latency, etc.
    protected void rasterRefresh() {
        flipScreen = true;
    }
    /// Function that contains the main loop
    public void whereTheMagicHappens() {
        mainRaster.refresh();                   //Initial raster refresh, not needed if raster refresh is set to be updated on every frame
        while(isRunning) {                      //The main loop
            //Delete this if statement, if you want refresh on every frame!
            if (flipScreen) {                   //This if statement is executed only when a draw function was called or a window was moved.
                flipScreen = false;             //sets boolean flipScreen to false once it's not needed.
                mainRaster.refresh();           //Refreshes the screen by running refresh on all associated layers of the raster
            }
            //mainRaster.refresh();             //Uncomment this line, if you want refresh on every frame!
            ih.test();                          //Tests for input events, like keyboard, mouse, etc.
            timer.test();                       //Tests for expired timer events.
            
            //Put additional things here you want to do on every loop!

            Thread.sleep(dur!"msecs"(10));      //To avoid high CPU usage from frequent input checks. Remove this line if you want refresh on every frame!
        }

        //Put stuff here you want to do upon quitting your program.

    }
    /// Called when a key event have done by the user.
    /// NOTE: Arguments will be changed once the move from SDL to iota is complete.
    public void keyEvent(uint id, BindingCode code, uint timestamp, bool isPressed) {

    }
    /// Called when an axis event have done by the user.
    /// NOTE: Arguments will be changed once the move from SDL to iota is complete.
    public void axisEvent(uint id, BindingCode code, uint timestamp, float value) {

    }
    /// Called when the user exits from the application.
    public void onQuit() {
        isRunning = false;
    }
    /// Called when a controller is added to the system.
    /// NOTE: Arguments will be changed once the move from SDL to iota is complete.
    public void controllerAdded(uint id) {

    }
    /// Called when a controller is removed from the system.
    /// Note: Arguments will be changed once the move from SDL to iota is complete.
    public void controllerRemoved(uint id) {

    }
}