module test3.app;

import pixelperfectengine.graphics.outputscreen;
import pixelperfectengine.graphics.layers;
import pixelperfectengine.graphics.raster;
import pixelperfectengine.concrete.window;
import pixelperfectengine.concrete.dialogs.filedialog;
import pixelperfectengine.system.input;
import pixelperfectengine.system.systemutility;
import pixelperfectengine.system.file;
import pixelperfectengine.system.common;
import pixelperfectengine.system.timer;
import pixelperfectengine.system.lang.textparser;

import core.thread;
import std.conv;
import std.stdio;

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
    TextParser          txtParser;

    public this() {
        
        sprtL = new SpriteLayer(RenderingMode.Copy);
		outScrn = new OutputScreen("Test nr. 3",1696,960);
		mainRaster = new Raster(848,480,outScrn,0,1);
		mainRaster.addLayer(sprtL,0);
        mainRaster.loadPalette(loadPaletteFromFile(getPathToAsset("/system/ConcreteGUIE1.tga")));
        wh = new WindowHandler(1696,960,848,480,sprtL);
        ih = new InputHandler();
        ih.inputListener = this;
        ih.systemEventListener = this;
        ih.mouseListener = wh;
        WindowElement.onDraw = &rasterRefresh;
        WindowElement.inputHandler = ih;
        Window.onDrawUpdate = &rasterRefresh;
        isRunning = true;
        txtParser = new TextParser(loadTextFile(File(getPathToLocalizationFile("US","en","xml"))), 
                globalDefaultStyle.getChrFormatting("default"));
        txtParser.parse();
        wh.addWindow(new TestWindow(txtParser.output));
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
    Button              btn_fileDialog;
    Button              btn_messageDialog;
    Button              btn_addElem;
    VertScrollBar       vScrollBarTest;
    Label               singleLineLabel;
    Label               multiLineLabel;
    Text                multiLineDialog;
    public this(Text[string] lang) {
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
            new ListViewItem(16, ["First", "000000000000000000000"], [TextInputFieldType.Text,  
                    TextInputFieldType.Text]),
            new ListViewItem(16, ["Second", "000000000000000000000"]),
            new ListViewItem(16, ["Third", "000000000000000000000"], [TextInputFieldType.Text,  
                    TextInputFieldType.Text]),
            new ListViewItem(16, ["Fourth", "000000000000000000000"]),
            new ListViewItem(16, ["Last", "000000000000000000000"]),
        ], "", Box(5, 220, 105, 313));
        listViewTest.editEnable = true;
        listViewTest.multicellEditEnable = true;
        addElement(listViewTest);

        singleLineLabel = new Label(lang["singlelinelabel"], "", Box(5, 340, 150, 360));
        addElement(singleLineLabel);

        multiLineLabel = new Label(lang["multilinelabel"], "", Box(5, 360, 150, 400));
        addElement(multiLineLabel);

        vScrollBarTest = new VertScrollBar(1000, "", Box.bySize(110, 220, 16, 120));
        addElement(vScrollBarTest);

        buttonTest0 = new Button("A", "", Box(205, 20, 205 + 39, 20 + 39));
        addElement(buttonTest0);
        buttonTest0.state = ElementState.Disabled;
        btn_fileDialog = new Button("Filedialog", "", Box.bySize(300, 20, 70, 20));
        btn_fileDialog.onMouseLClick = &btn_fileDialog_onClick;
        addElement(btn_fileDialog);
        btn_messageDialog = new Button("Message", "", Box.bySize(300, 45, 70, 20));
        btn_messageDialog.onMouseLClick = &btn_messageDialog_onClick;
        addElement(btn_messageDialog);
        btn_addElem = new Button("Add Elem", "", Box.bySize(300, 70, 70, 20));
        btn_addElem.onMouseLClick = &btn_addElem_onClick;
        addElement(btn_addElem);

        multiLineDialog = lang["multilinedialog"];
    }
    private void btn_messageDialog_onClick(Event ev) {
        handler.message("Message", multiLineDialog);
    }
    private void btn_fileDialog_onClick(Event ev) {
        handler.addWindow(new FileDialog("Test filedialog", "", &fileDialogEvent, 
                [FileDialog.FileAssociationDescriptor("All files", ["*.*"])], "./"));
    }
    private void btn_addElem_onClick(Event ev) {
        listViewTest.insertAndEdit(2, new ListViewItem(16, ["Fifth", "000000000000000000000"], [TextInputFieldType.Text,  
                    TextInputFieldType.Text]));
    }
    private void fileDialogEvent(Event ev) {
        FileEvent fe = cast(FileEvent)ev;
        writeln(fe.path);
        writeln(fe.filename);
        writeln(fe.extension);
    }
}