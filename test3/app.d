module test3.app;

import pixelperfectengine.graphics.outputscreen;
import pixelperfectengine.graphics.layers;
import pixelperfectengine.graphics.raster;
import pixelperfectengine.concrete.window;
import pixelperfectengine.system.input;
import pixelperfectengine.system.systemutility;

/** 
 * Tests GUI elements by displaying them.
 */
int main() {
    INIT_CONCRETE();
    return 0;
}

public class TestElements : InputListener, SystemEventListener {
    Raster				mainRaster;
	OutputScreen		outScrn;
    SpriteLayer			sprtL;
    WindowHandler		wh;
    InputHandler        ih;
    bool                isRunning;

    public this() {
        wh = new WindowHandler(1696,960,848,480,sprtL);
		mainRaster.loadPalette(loadPaletteFromFile("../system/concreteGUIE1.tga"));
        sprtL = new SpriteLayer(RenderingMode.Copy);
		outScrn = new OutputScreen("WindowMaker for PPE/Concrete",1696,960);
		mainRaster = new Raster(848,480,outScrn,0);
		mainRaster.addLayer(sprtL,0);


        isRunning = true;
    }
    public void whereTheMagicHappens() {
        while(isRunning) {

        }
    }

    public void keyEvent(uint id, BindingCode code, uint timestamp, bool isPressed) {

    }

    public void axisEvent(uint id, BindingCode code, uint timestamp, float value) {

    }

    public void onQuit() {
        isRunning = false;
    }

    public void controllerAdded(uint id) {

    }

    public void controllerRemoved(uint id) {

    }
}

public class TestWindow : Window {
    CheckBox            modeToggle;
    Panel               panelTest;
    RadioButton[]       radioButtonTest;
    RadioButtonGroup    radioButtonTestGr;
    public this() {
        super(Box.bySize(0, 0, 848, 480), "Test");
    }

}