module test3.app;

import pixelperfectengine.graphics.outputscreen;
import pixelperfectengine.graphics.layers;
import pixelperfectengine.graphics.raster;
import pixelperfectengine.concrete.window;
import pixelperfectengine.system.input;
import pixelperfectengine.system.systemutility;
import pixelperfectengine.system.file;
import pixelperfectengine.system.common;
import pixelperfectengine.system.timer;

import core.thread;
import std.conv;

/** 
 * Tests GUI elements by displaying them.
 */
int main() {
    initialzeSDL();
    INIT_CONCRETE();
    TestElements te = new TestElements();
    te.whereTheMagicHappens();
    return 0;
}

public class TestElements : InputListener, SystemEventListener {
    Raster				mainRaster;
	OutputScreen		outScrn;
    SpriteLayer			sprtL;
    WindowHandler		wh;
    InputHandler        ih;
    bool                isRunning, flipScreen;

    public this() {
        sprtL = new SpriteLayer(RenderingMode.Copy);
		outScrn = new OutputScreen("Test nr. 3",1696,960);
		mainRaster = new Raster(848,480,outScrn,0,1);
		mainRaster.addLayer(sprtL,0);
        mainRaster.loadPalette(loadPaletteFromFile("../system/concreteGUIE1.tga"));
        wh = new WindowHandler(1696,960,848,480,sprtL);
        ih = new InputHandler();
        ih.inputListener = this;
        ih.systemEventListener = this;
        ih.mouseListener = wh;
        WindowElement.onDraw = &rasterRefresh;
        Window.onDrawUpdate = &rasterRefresh;
        isRunning = true;
        wh.addWindow(new TestWindow());
    }
    protected void rasterRefresh() {
        flipScreen = true;
    }
    public void whereTheMagicHappens() {
        mainRaster.refresh();
        while(isRunning) {
            if (flipScreen) {
                flipScreen = false;
                mainRaster.refresh();
            }
            //mainRaster.refresh();
            ih.test();
            Thread.sleep(dur!"msecs"(10));
            timer.test();
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
    ListView            listViewTest;
    Button              buttonTest0, buttonTest1;
    VertScrollBar       vScrollBarTest;
    public this() {
        super(Box.bySize(0, 0, 848, 480), "Test");
        panelTest = new Panel("Selections", "", Box(5, 20, 200, 200));
        addElement(panelTest);
        for (int i ; i < 7 ; i++) {
            RadioButton rb = new RadioButton
                    ("Option "d ~ i.to!dstring(), "", Box(10, 40 + i * 20, 195, 40 + i * 20 + 16));
            panelTest.addElement(rb);
            radioButtonTest ~= rb;
        }
        radioButtonTestGr = new RadioButtonGroup(radioButtonTest);

        listViewTest = new ListView(new ListViewHeader(16, [50, 50], ["Column 1", "Column 2"]), [
            new ListViewItem(16, ["First", "000000000000000000000"]),
            new ListViewItem(16, ["Second", "000000000000000000000"]),
            new ListViewItem(16, ["Third", "000000000000000000000"]),
            new ListViewItem(16, ["Fourth", "000000000000000000000"]),
            new ListViewItem(16, ["Last", "000000000000000000000"]),
        ], "", Box(5, 220, 105, 313));
        addElement(listViewTest);

        vScrollBarTest = new VertScrollBar(1000, "", Box.bySize(110, 220, 16, 120));
        addElement(vScrollBarTest);

        buttonTest0 = new Button("A", "", Box(205, 20, 205 + 39, 20 + 39));
        addElement(buttonTest0);
        buttonTest0.state = ElementState.Disabled;
        
    }

}