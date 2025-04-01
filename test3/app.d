module test3.app;

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
import std.algorithm.searching : startsWith;

import bindbc.opengl;

int GUIScaling = 2;

/** 
 * Tests GUI elements by displaying them.
 */
int main(string[] args) {
	foreach (string arg ; args) {
		if (arg.startsWith("--ui-scaling=")) {
			try {
				GUIScaling = arg[13..$].to!int;
			} catch (Exception e) {

			}
		} else if (arg.startsWith("--shadervers=")) {
			pathSymbols["SHDRVER"] = arg[13..$];
		}
	}
	INIT_CONCRETE();
	TestElements te = new TestElements();
	te.whereTheMagicHappens();
	return 0;
}

public class TestElements : InputListener, SystemEventListener {
	Raster				mainRaster;
	OSWindow    		outScrn;
	SpriteLayer			sprtL;
	WindowHandler		wh;
	InputHandler        ih;
	bool                isRunning, flipScreen, fullScreen;
	TextParser          txtParser;

	public this() {
		outScrn = new OSWindow("Test nr. 3", "ppe_test3", -1, -1, 848 * GUIScaling, 480 * GUIScaling, WindowCfgFlags.IgnoreMenuKey);
		version (Windows) outScrn.getOpenGLHandleAttribsARB([
			OpenGLContextAtrb.MajorVersion, 3,
			OpenGLContextAtrb.MinorVersion, 3,
			OpenGLContextAtrb.ProfileMask, 1,
			OpenGLContextAtrb.Flags, OpenGLContextFlags.Debug,
			0
		]);
		else outScrn.getOpenGLHandle();
		const glStatus = loadOpenGL();
		if (glStatus < GLSupport.gl11) {
			writeln("OpenGL not found!");
		}
		sprtL = new SpriteLayer(GLShader(loadShader(`%SHADERS%/base_%SHDRVER%.vert`),
				loadShader(`%SHADERS%/base_%SHDRVER%.frag`)), GLShader(loadShader(`%SHADERS%/base_%SHDRVER%.vert`),
				loadShader(`%SHADERS%/base32bit_%SHDRVER%.frag`)));
		mainRaster = new Raster(848,480,outScrn,1);
		mainRaster.readjustViewport(840 * GUIScaling, 480 * GUIScaling, 0, 0);
		mainRaster.addLayer(sprtL,0);
		mainRaster.loadPaletteChunk(loadPaletteFromFile(getPathToAsset("/system/concreteGUIE1.tga")), 0);
		wh = new WindowHandler(848 * GUIScaling, 480 * GUIScaling, 848, 480, sprtL, outScrn);
		ih = new InputHandler();
		ih.inputListener = this;
		ih.systemEventListener = this;
		{
			import pixelperfectengine.system.input.scancode;
			import iota.controls.gamectrl : GameControllerButtons;
			ih.addBinding(BindingCode(ScanCode.F11, 0, Devicetype.Keyboard, 0, 0xff), InputBinding("fullscreen"));
		}
		ih.mouseListener = wh;
		PopUpElement.onDraw = &rasterRefresh;
		WindowElement.onDraw = &rasterRefresh;
		WindowElement.inputHandler = ih;
		PopUpElement.inputhandler = ih;
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
		mainRaster.refresh_GL();
		while(isRunning) {
			// if (flipScreen) {
				// flipScreen = false;
				mainRaster.refresh_GL();
			// }
			//mainRaster.refresh();
			ih.test();
			Thread.sleep(dur!"msecs"(10));
			timer.test();
		}
		destroy(outScrn);
	}
	/** 
	 * Called if a window was resized.
	 * Params:
	 *   window = Handle to the OSWindow class.
	 */
	public void windowResize(OSWindow window, int width, int height) {
		mainRaster.resizeRaster(cast(ushort)(width / GUIScaling), cast(ushort)(height / GUIScaling));
		wh.resizeRaster(width, height, width / GUIScaling, height / GUIScaling);
		glViewport(0, 0, width, height);
		rasterRefresh();
	}
	public void keyEvent(uint id, BindingCode code, Timestamp timestamp, bool isPressed) {
		switch (id) {
		case hashCalc("fullscreen"):
			if (isPressed) {
				fullScreen = !fullScreen;
				outScrn.setScreenMode(-1, fullScreen ? DisplayMode.FullscreenDesktop : DisplayMode.Windowed);
			}
			break;
		default:
			break;
		}
	}

	public void axisEvent(uint id, BindingCode code, Timestamp timestamp, float value) {

	}

	public void onQuit() {
		isRunning = false;
	}

	public void inputDeviceAdded(InputDevice id) {

	}
	public void inputDeviceRemoved(InputDevice id) {

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
	Button              btn_subMenu;
	Button              btn_resizeTest;
	Button				btn_popupTextinput;
	TextBox				textBox_test;
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
		listViewTest.onItemAdd = &listView_onItemAdd;

		singleLineLabel = new Label(lang["singlelinelabel"], "", Box(5, 340, 160, 360));
		addElement(singleLineLabel);

		multiLineLabel = new Label(lang["multilinelabel"], "", Box(5, 360, 160, 400));
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
		btn_subMenu = new Button("Submenu test", "", Box.bySize(300, 95, 70, 20));
		btn_subMenu.onMouseLClick = &btn_subMenu_onClick;
		addElement(btn_subMenu);
		btn_resizeTest = new Button("Window resize", "", Box.bySize(300, 120, 70, 20));
		btn_resizeTest.onMouseLClick = &btn_resizeTest_onClick;
		addElement(btn_resizeTest);
		btn_popupTextinput = new Button("PopUpTextInput", "", Box.bySize(300, 145, 70, 20));
		btn_popupTextinput.onMouseLClick = &btn_popupTextinput_onClick;
		addElement(btn_popupTextinput);
		textBox_test = new TextBox("0123456789", "", Box.bySize(300, 170, 70, 20));
		addElement(textBox_test);

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
	private void btn_subMenu_onClick(Event ev) {
		PopUpMenuElement[] menutree;
		menutree ~= new PopUpMenuElement("\\submenu\\", "Rootmenu 1");
		menutree[0] ~= new PopUpMenuElement("", "Submenu 1/1");
		menutree[0] ~= new PopUpMenuElement("", "Submenu 1/2");
		menutree[0] ~= new PopUpMenuElement("", "Submenu 1/3");
		menutree ~= new PopUpMenuElement("\\submenu\\", "Rootmenu 2");
		menutree[1] ~= new PopUpMenuElement("", "Submenu 2/1");
		menutree[1] ~= new PopUpMenuElement("", "Submenu 2/2");
		menutree[1] ~= new PopUpMenuElement("", "Submenu 2/3");
		menutree ~= new PopUpMenuElement("\\submenu\\", "Rootmenu 3");
		menutree[2] ~= new PopUpMenuElement("", "Submenu 3/1");
		menutree[2] ~= new PopUpMenuElement("", "Submenu 3/2");
		menutree[2] ~= new PopUpMenuElement("", "Submenu 3/3");
		handler.addPopUpElement(new PopUpMenu(menutree, "", null));
	}
	private void btn_resizeTest_onClick(Event ev) {
		handler.addWindow(new ResizableWindow());
	}
	private void btn_popupTextinput_onClick(Event ev) {
		handler.addPopUpElement(new PopUpTextInput("", new Text("1234567890", globalDefaultStyle.getChrFormatting("default")), 
				Box.bySize(1,1, 256, 24)));
	}
	private void fileDialogEvent(Event ev) {
		FileEvent fe = cast(FileEvent)ev;
		writeln(fe.path);
		writeln(fe.filename);
		writeln(fe.extension);
	}
	private void listView_onItemAdd(Event ev) {
		writeln(ev);
	}
}

public class ResizableWindow : Window {
	public this() {
		resizableH = true;
		resizableV = true;
		super(Box.bySize(0, 0, 200, 200), "Resizing test");
	}
}
