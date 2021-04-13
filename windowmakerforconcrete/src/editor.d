module editor;

import types;
import serializer;
import editorEvents;

import PixelPerfectEngine.concrete.window;
import PixelPerfectEngine.system.input;
import PixelPerfectEngine.system.etc : csvParser, isInteger;
import PixelPerfectEngine.graphics.layers;
import PixelPerfectEngine.graphics.raster;
import PixelPerfectEngine.graphics.outputScreen;
import PixelPerfectEngine.system.config;
import std.bitmanip : bitfields;

import conv = std.conv;
import stdio = std.stdio;

/+public class EditorWindowHandler : WindowHandler, ElementContainer{
	private WindowElement[] elements, mouseC, keyboardC, scrollC;
	public ListBox objectList, propList;
	//private ListBoxColumn[] propTL, propSL, propSLE;
	//private ListBoxColumn[] layerListE;
	public Editor ie;

	//public InputHandler ih;

	private BitmapDrawer output;
	public this(int sx, int sy, int rx, int ry, ISpriteLayer sl, Editor ie){
		super(sx,sy,rx,ry,sl);
		output = new BitmapDrawer(rx, ry);
		addBackground(output.output);

		WindowElement.popUpHandler = this;
		this.ie = ie;
	}
	public void clearArea(WindowElement sender){

	}
	public void initGUI(){
		Text pt(dstring text) {
			return new Text(text, WindowElement.styleSheet.getChrFormatting("popUpMenu"));
		}
		Text st(dstring text) {
			return new Text(text, WindowElement.styleSheet.getChrFormatting("popUpMenuSecondary"));
		}
		Text mt(dstring text) {
			return new Text(text, WindowElement.styleSheet.getChrFormatting("menuBar"));
		}
		output.drawFilledRectangle(0, rasterX, 0, rasterY, 0x0005);

		PopUpMenuElement[] menuElements;
		menuElements ~= new PopUpMenuElement("file", mt("FILE"));

		menuElements[0] ~= new PopUpMenuElement("new", pt("New window"), st("Ctrl + N"));
		menuElements[0] ~= new PopUpMenuElement("load", pt("Load window"), st("Ctrl + L"));
		menuElements[0] ~= new PopUpMenuElement("save", pt("Save window"), st("Ctrl + S"));
		menuElements[0] ~= new PopUpMenuElement("saveAs", pt("Save window as"), st("Ctrl + Shift + S"));
		menuElements[0] ~= new PopUpMenuElement("Export", pt("Export window as D code"), st("Ctrl + Shift + X"));
		menuElements[0] ~= new PopUpMenuElement("exit", pt("Exit application"), st("Alt + F4"));

		menuElements ~= new PopUpMenuElement("edit", mt("EDIT"));

		menuElements[1] ~= new PopUpMenuElement("undo", pt("Undo"), st("Ctrl + Z"));
		menuElements[1] ~= new PopUpMenuElement("redo", pt("Redo"), st("Ctrl + Shift + Z"));
		menuElements[1] ~= new PopUpMenuElement("copy", pt("Copy"), st("Ctrl + C"));
		menuElements[1] ~= new PopUpMenuElement("cut", pt("Cut"), st("Ctrl + X"));
		menuElements[1] ~= new PopUpMenuElement("paste", pt("Paste"), st("Ctrl + V"));

		menuElements ~= new PopUpMenuElement("elements", mt("ELEMENTS"));

		menuElements[2] ~= new PopUpMenuElement("Label", pt("Label"), st("Ctrl + F1"));
		menuElements[2] ~= new PopUpMenuElement("Button", pt("Button"), st("Ctrl + F2"));
		menuElements[2] ~= new PopUpMenuElement("TextBox", pt("TextBox"), st("Ctrl + F3"));
		menuElements[2] ~= new PopUpMenuElement("ListBox", pt("ListBox"), st("Ctrl + F4"));
		menuElements[2] ~= new PopUpMenuElement("CheckBox", pt("CheckBox"), st("Ctrl + F5"));
		menuElements[2] ~= new PopUpMenuElement("RadioButton", pt("RadioButton"), st("Ctrl + F6"));
		//menuElements[2] ~= new PopUpMenuElement("MenuBar", pt("MenuBar"), st("Ctrl + F7"));
		menuElements[2] ~= new PopUpMenuElement("HSlider", pt("HSlider"), st("Ctrl + F8"));
		menuElements[2] ~= new PopUpMenuElement("VSlider", pt("VSlider"), st("Ctrl + F9"));

		menuElements ~= new PopUpMenuElement("help", mt("HELP"));

		menuElements[3] ~= new PopUpMenuElement("helpFile", pt("Content"));
		menuElements[3] ~= new PopUpMenuElement("about", pt("About"));

		MenuBar mb = new MenuBar("menubar",Coordinate(0,0,rasterX - 1,16),menuElements);
		addElement(mb);

		objectList = new ListBox("objectList", Coordinate(644,20,rasterX - 5,238), [], new ListBoxHeader(["Type"d,"Name"d],[128,128]),16);
		propList = new ListBox("propList", Coordinate(644,242,rasterX - 5,477), [], new ListBoxHeader(["Prop"d,"Val"d],[128,256]),16,true);
		addElement(objectList);
		addElement(propList);

		foreach(WindowElement we; elements){
			we.draw();
		}
		mb.onMouseLClickPre = &ie.menuEvent;
	}

	public override StyleSheet getStyleSheet(){
		return defaultStyle;
	}

	public void addElement(WindowElement we){
		elements ~= we;
		we.elementContainer = this;
	}

	public override void drawUpdate(WindowElement sender){
		output.insertBitmap(sender.getPosition().left,sender.getPosition().top,sender.output.output);
	}

	override public void passMouseEvent(int x,int y,int state,ubyte button) {
		foreach(WindowElement e; elements){
			if(e.getPosition().left < x && e.getPosition().right > x && e.getPosition().top < y && e.getPosition().bottom > y){
				e.onClick(x - e.getPosition().left, y - e.getPosition().top, state, button);
				return;
			}
		}
	}
	public override void passScrollEvent(int wX, int wY, int x, int y){
		foreach(WindowElement e; elements){
			if(e.getPosition().left < wX && e.getPosition().right > wX && e.getPosition().top < wX && e.getPosition().bottom > wY){

				e.onScroll(y, x, wX, wY);

				return;
			}
		}
	}
	public Coordinate getAbsolutePosition(WindowElement sender){
		return sender.position;
	}
}+/

public class TopLevelWindow : Window {
	public ListView objectList, propList;
	MenuBar mb;
	public this (int x, int y) {
		import PixelPerfectEngine.graphics.draw;
		output = new BitmapDrawer(x, y);
		position = Box(0, 0, x - 1, y - 1);

		PopUpMenuElement[] menuElements;

		menuElements ~= new PopUpMenuElement("file", "File");

		menuElements[0] ~= new PopUpMenuElement("new", "New window");
		menuElements[0] ~= new PopUpMenuElement("load", "Load window");
		menuElements[0] ~= new PopUpMenuElement("save", "Save window");
		menuElements[0] ~= new PopUpMenuElement("saveAs", "Save window as");
		menuElements[0] ~= new PopUpMenuElement("export", "Export window as D code" );
		menuElements[0] ~= new PopUpMenuElement("exit", "Exit application", "Alt + F4");

		menuElements ~= new PopUpMenuElement("edit", "Edit");

		menuElements[1] ~= new PopUpMenuElement("undo", "Undo");
		menuElements[1] ~= new PopUpMenuElement("redo", "Redo");
		menuElements[1] ~= new PopUpMenuElement("copy", "Copy");
		menuElements[1] ~= new PopUpMenuElement("cut", "Cut");
		menuElements[1] ~= new PopUpMenuElement("paste", "Paste");

		menuElements ~= new PopUpMenuElement("elements", "Elements");

		menuElements[2] ~= new PopUpMenuElement("Label", "Label");
		menuElements[2] ~= new PopUpMenuElement("Button", "Button");
		menuElements[2] ~= new PopUpMenuElement("TextBox", "TextBox");
		menuElements[2] ~= new PopUpMenuElement("ListView", "ListView");
		menuElements[2] ~= new PopUpMenuElement("CheckBox", "CheckBox");
		menuElements[2] ~= new PopUpMenuElement("RadioButton", "RadioButton");
		//menuElements[2] ~= new PopUpMenuElement("MenuBar", pt("MenuBar"), st("Ctrl + F7"));
		menuElements[2] ~= new PopUpMenuElement("HSlider", "HSlider");
		menuElements[2] ~= new PopUpMenuElement("VSlider", "VSlider");

		menuElements ~= new PopUpMenuElement("help", "Help");

		menuElements[3] ~= new PopUpMenuElement("helpFile", "Content");
		menuElements[3] ~= new PopUpMenuElement("about", "About");

		mb = new MenuBar("mb", Box(0, 0, x-1, 15), menuElements);
	}
	public override void draw(bool drawHeaderOnly = false) {
		if(output.output.width != position.width || output.output.height != position.height)
			output = new BitmapDrawer(position.width(), position.height());
		
		StyleSheet ss = getStyleSheet();
		const Box bodyarea = Box(0, 0, position.width - 1, position.height - 1);
		drawFilledBox(bodyarea, ss.getColor("window"));

		foreach (WindowElement we; elements) {
			we.draw();
		}
		
	}
}

public class DummyWindow : Window {
	Editor ed;
	public this(Box coordinates, dstring name, Editor ed) {
		super(coordinates, name);
		this.ed = ed;
	}
	///Passes mouse click event
	override public void passMCE(MouseEventCommons mec, MouseClickEvent mce) {
		//super.passMouseEvent(x,y,state,button);
		mce.x -= position.left;
		mce.y -= position.top;
		if(mce.button == MouseButton.Left){
			ed.clickEvent(mce.x, mce.y, mce.state);
		}else if(mce.button == MouseButton.Right){
			foreach(we; elements){
				const Box c = we.getPosition;
				if(mce.x > c.left && mce.x < c.right && mce.y > c.top && mce.y < c.bottom)
					ed.selectEvent(we);
			}
		}
	}
	override public void close() {
	//super.close;
	}
	/+override public void passMouseMotionEvent(int x, int y, int relX, int relY, ubyte button) {

	}+/
	override public void passMME(MouseEventCommons mec, MouseMotionEvent mme) {
		if (mme.buttonState) {
			mme.x -= position.left;
			mme.y -= position.top;
			ed.dragEvent(mme.x, mme.y, mme.relX, mme.relY, mme.buttonState);
		}
	}
	public void drawSelection(Box box, bool crossHair = false) {
		draw();
		//stdio.writeln(box);
		drawBox(box, 17);
		if (crossHair) {
			const int width = position.width - 1, height = position.height - 1;
			
			drawLine(Point(0, box.top), box.cornerUL, 18);
			drawLine(Point(box.left, 0), box.cornerUL, 18);

			drawLine(Point(width, box.top), box.cornerUR, 18);
			drawLine(Point(box.right, 0), box.cornerUR, 18);

			drawLine(Point(0, box.bottom), box.cornerLL, 18);
			drawLine(Point(box.left, height), box.cornerLL, 18);

			drawLine(Point(width, box.bottom), box.cornerLR, 18);
			drawLine(Point(box.right, height), box.cornerLR, 18);
		}
	}
}

public class Editor : SystemEventListener, InputListener{
	WindowHandler		ewh;
	DummyWindow 		dw;
	SpriteLayer			sprtL;
	Raster				mainRaster;
	OutputScreen		outScrn;
	InputHandler		inputH;
	EditMode			mode;
	mixin(bitfields!(
		bool, "onExit", 1,
		bool, "undoPressed", 1,
		bool, "redoPressed", 1,
		bool, "delPressed", 1,
		bool, "moveElemMode", 1,
		bool, "resizeMode", 1,
		ubyte, "", 2,
	));
	Box					moveElemOrig;
	int					x0, y0;
	ElementType			typeSel;
	UndoableStack		eventStack;
	WindowElement[string] elements;
	string				selection;
	ConfigurationProfile	config;

	static string[ElementType] nameBases;
	public this(){
		import PixelPerfectEngine.system.systemUtility;
		import PixelPerfectEngine.system.file;
		sprtL = new SpriteLayer(LayerRenderingMode.COPY);
		outScrn = new OutputScreen("WindowMaker for PPE/Concrete",1696,960);
		mainRaster = new Raster(848,480,outScrn,0);
		mainRaster.addLayer(sprtL,0);
		typeSel = ElementType.NULL;

		ewh = new WindowHandler(1696,960,848,480,sprtL);
		mainRaster.loadPalette(loadPaletteFromFile("../system/concreteGUIE1.tga"));
		INIT_CONCRETE(ewh);
		inputH = new InputHandler();
		inputH.systemEventListener = this;
		inputH.inputListener = this;
		
		/+inputH.kb ~= KeyBinding(KeyModifier.Ctrl, ScanCode.Z, 0, "undo", Devicetype.KEYBOARD, KeyModifier.LockKeys);
		inputH.kb ~= KeyBinding(KeyModifier.Ctrl | KeyModifier.Shift, ScanCode.Z, 0, "redo", Devicetype.KEYBOARD, 
				KeyModifier.LockKeys);
		inputH.kb ~= KeyBinding(0, ScanCode.DELETE, 0, "del", Devicetype.KEYBOARD, KeyModifier.LockKeys);
		inputH.kb ~= KeyBinding(0, ScanCode.ESCAPE, 0, "sysesc", Devicetype.KEYBOARD, KeyModifier.LockKeys);
		inputH.kb ~= KeyBinding(KeyModifier.Ctrl, ScanCode.F1, 0, "Label", Devicetype.KEYBOARD, KeyModifier.LockKeys);
		inputH.kb ~= KeyBinding(KeyModifier.Ctrl, ScanCode.F2, 0, "Button", Devicetype.KEYBOARD, KeyModifier.LockKeys);
		inputH.kb ~= KeyBinding(KeyModifier.Ctrl, ScanCode.F3, 0, "TextBox", Devicetype.KEYBOARD, KeyModifier.LockKeys);
		inputH.kb ~= KeyBinding(KeyModifier.Ctrl, ScanCode.F4, 0, "ListBox", Devicetype.KEYBOARD, KeyModifier.LockKeys);
		inputH.kb ~= KeyBinding(KeyModifier.Ctrl, ScanCode.F5, 0, "CheckBox", Devicetype.KEYBOARD, KeyModifier.LockKeys);
		inputH.kb ~= KeyBinding(KeyModifier.Ctrl, ScanCode.F6, 0, "RadioButton", Devicetype.KEYBOARD, KeyModifier.LockKeys);
		inputH.kb ~= KeyBinding(KeyModifier.Ctrl, ScanCode.F8, 0, "HSlider", Devicetype.KEYBOARD, KeyModifier.LockKeys);
		inputH.kb ~= KeyBinding(KeyModifier.Ctrl, ScanCode.F9, 0, "VSlider", Devicetype.KEYBOARD, KeyModifier.LockKeys);+/
		ewh.setBaseWindow(new TopLevelWindow(848, 480));
		config = new ConfigurationProfile("config_wmfc.sdl", "../system/config_wmfc.sdl");
		{
			import PixelPerfectEngine.system.input.scancode;
			inputH.addBinding(BindingCode(ScanCode.ESCAPE, 0, Devicetype.Keyboard, 0, KeyModifier.LockKeys), InputBinding("sysesc"));
		}
		config.loadBindings(inputH);

		PopUpElement.inputhandler = inputH;
		WindowElement.inputHandler = inputH;
		
		ewh.initGUI();
		dw = new DummyWindow(Coordinate(0,16,640,480), "New Window"d, this);
		ewh.addWindow(dw);
		eventStack = new UndoableStack(10);
		wserializer = new WindowSerializer();
		dwtarget = dw;
		editorTarget = this;
		ewh.objectList.onItemSelect = &onObjectListSelect;
		ewh.propList.onTextInput = &onAttributeEdit;
		updateElementList;
	}
	static this(){
		nameBases[ElementType.Label] = "label";
		nameBases[ElementType.Button] = "button";
		nameBases[ElementType.SmallButton] = "smallButton";
		nameBases[ElementType.TextBox] = "textBox";
		nameBases[ElementType.ListBox] = "listBox";
		nameBases[ElementType.RadioButton] = "radioButton";
		nameBases[ElementType.CheckBox] = "checkBox";
		nameBases[ElementType.HSlider] = "hSlider";
		nameBases[ElementType.VSlider] = "vSlider";
		nameBases[ElementType.MenuBar] = "menuBar";
	}
	public string getNextName(string input){
		for(int i ; true ; i++){
			if(elements.get(input ~ conv.to!string(i), null) is null)
				return input ~ conv.to!string(i);
		}
	}
	public void onObjectListSelect(Event ev){
		deinitElemMove;
		ListBoxItem lbi = cast(ListBoxItem)ev.aux;
		if(lbi.getText(0) != "window"){
			selection = conv.to!string(lbi.getText(1));
		}else{//Fill attribute list with data related to the window
			selection = "window";
		}
		updatePropertyList;
	}
	public void onLoadFile(Event ev){
		wserializer = new WindowSerializer(ev.getFullPath);
		wserializer.deserialize(dw, this);
	}
	public void onSaveFileAs(Event ev){
		wserializer.store(ev.getFullPath);
	}
	public void onExportWindow(Event ev){
		wserializer.generateDCode(ev.getFullPath);
	}
	public void onAttributeEdit(Event ev){
		import std.utf : toUTF8;
		ListBoxItem lbi = cast(ListBoxItem)ev.aux;
		if(selection == "window"){
			switch(lbi.getText(0)){
				case "name":
					eventStack.addToTop(new WindowRenameEvent(conv.to!string(ev.text.text)));
					return;
				case "title":
					eventStack.addToTop(new WindowRetitleEvent(ev.text.text));
					return;
				case "size:x":
					eventStack.addToTop(new WindowWidthChangeEvent(conv.to!int(ev.text.text)));
					return;
				case "size:y":
					eventStack.addToTop(new WindowHeightChangeEvent(conv.to!int(ev.text.text)));
					return;
				default:
					return;
			}
		}else{
			switch(lbi.getText(0)){
				case "text":
					eventStack.addToTop(new TextEditEvent(ev.text.text, selection));
					return;
				case "name":
					eventStack.addToTop(new RenameEvent(selection, conv.to!string(ev.text.text)));
					selection = conv.to!string(ev.text);
					return;
				case "position":
					dstring[] src = csvParser(ev.text.text, ';');
					if(src.length == 4){
						Coordinate c;
						foreach(s; src){
							if(!isInteger(s)){
								ewh.messageWindow("Format Error!", "Value is not integer!");
								return;
							}
						}
						c.left = conv.to!int(src[0]);
						c.top = conv.to!int(src[1]);
						c.right = conv.to!int(src[2]);
						c.bottom = conv.to!int(src[3]);
						eventStack.addToTop(new PositionEditEvent(c, selection));
					}else{
						ewh.messageWindow("Format Error!", "Correct format is: [int];[int];[int];[int];");
					}
					return;
				case "source":
					eventStack.addToTop(new SourceEditEvent(selection, conv.to!string(ev.text.text)));
					return;
				default:
					return;
			}
		}
	}
	public void clickEvent(int x, int y, bool state){
		if(typeSel != ElementType.NULL) {
			if(state) {
				x0 = x;
				y0 = y;
			}else{
				Box c;
				if(x > x0){
					c.left = x0;
					c.right = x;
				}else{
					c.left = x;
					c.right = x0;
				}
				if(y > y0){
					c.top = y0;
					c.bottom = y;
				}else{
					c.top = y;
					c.bottom = y0;
				}
				WindowElement we;
				string s;
				switch(typeSel){
					case ElementType.Label:
						s = getNextName("label");
						we = new Label(conv.to!dstring(s),s,c);
						break;
					case ElementType.Button:
						s = getNextName("button");
						we = new Button(conv.to!dstring(s),s,c);
						break;
					case ElementType.TextBox:
						s = getNextName("textBox");
						we = new TextBox(conv.to!dstring(s),s,c);
						break;
					case ElementType.ListBox:
						s = getNextName("listBox");
						we = new ListBox(s,c,[], new ListBoxHeader(["col0", "col1"],[40,40]), 16);
						break;
					case ElementType.CheckBox:
						s = getNextName("CheckBox");
						we = new CheckBox(conv.to!dstring(s),s,c);
						break;
					case ElementType.RadioButton:
						s = getNextName("radioButton");
						we = new RadioButton(conv.to!dstring(s),s,c);
						break;
					/+case ElementType.MenuBar:
						s = getNextName("menuBar");
						we = new MenuBar(s,c,[new PopUpMenuElement("menu0","menu0")]);+/
						//break;
					case ElementType.HSlider:
						s = getNextName("hSlider");
						we = new HSlider(16,1,s,c);
						break;
					case ElementType.VSlider:
						s = getNextName("vSlider");
						we = new HSlider(16,1,s,c);
						break;
					default:
						break;
				}
				eventStack.addToTop(new PlacementEvent(we, typeSel, s));
				typeSel = ElementType.NULL;
				//updateElementList;
			}
		} else {
			if (state == ButtonState.PRESSED) {
				if(!moveElemMode && elements.get(selection, null)) {
					if (elements[selection].position.isBetween(x,y)) {
						initElemMove;
						
					} else if (elements[selection].position.right <= x + 1 && elements[selection].position.bottom <= y + 1) {
						initElemResize;
						
					}
				}
			} else {
				finalizeElemMove;
				finalizeElemResize;
			}
		}
	}
	public void dragEvent(int x, int y, int relX, int relY, uint button) {
		if (moveElemMode) {
			const Coordinate temp = elements[selection].position;
			if(temp.left + relX < 0) relX -= temp.left + relX;
			if(temp.right + relX >= dw.position.width) relX -= (temp.right + relX) - dw.position.width;
			if(temp.top + relY < 0) relY -= temp.top + relY;
			if(temp.bottom + relY >= dw.position.height) relY -= (temp.bottom + relY) - dw.position.height;
			elements[selection].position.relMove(relX, relY);
			dw.draw();
		} else if (resizeMode) {
			x0 = x;
			y0 = y;
			dw.drawSelection(Coordinate(elements[selection].position.left, elements[selection].position.top, x0, y0));
		} else if (typeSel != ElementType.NULL) {
			dw.drawSelection(Coordinate(x0, y0, x, y));
		}
	}

	public void updateElementList(){
		ewh.objectList.clearData;
		ListBoxItem[] list = [new ListBoxItem(["window", ""])];
		foreach(s; elements.byKey){
			list ~= new ListBoxItem([conv.to!dstring(elements[s].classinfo.name[37..$]), conv.to!dstring(s)]);
		}
		ewh.objectList.updateColumns(list);
	}
	public void updatePropertyList(){
		import sdlang;
		import std.utf;
		ewh.propList.clearData;
		if(elements.get(selection, null) !is null){
			string classname = elements[selection].classinfo.name[37..$];
			ListBoxItem[] list = [new ListBoxItem(["name", conv.to!dstring(selection)], [TextInputType.NULL, TextInputType.TEXT]),
					new ListBoxItem(["source", conv.to!dstring(wserializer.getValue(selection, "source")[0].get!string())],
					[TextInputType.NULL, TextInputType.TEXT])];
			if(classname == "Label" || classname == "TextBox" || classname == "Button" || classname == "CheckBox" ||
					classname == "RadioButtonGroup"){
				list ~= new ListBoxItem(["text", toUTF32(wserializer.getValue(selection, "text")[0].get!string())], [
						TextInputType.NULL, TextInputType.TEXT]);
			}
			Value[] pos0 = wserializer.getValue(selection, "position");
			dstring pos1 = conv.to!dstring(pos0[0].get!int) ~ ";" ~ conv.to!dstring(pos0[1].get!int) ~ ";" ~
					conv.to!dstring(pos0[2].get!int) ~ ";" ~ conv.to!dstring(pos0[3].get!int) ~ ";";
			list ~= new ListBoxItem(["position", pos1], [TextInputType.NULL, TextInputType.TEXT]);
			switch(classname){
				case "Button", "SmallButton":
					list ~= new ListBoxItem(["icon", conv.to!dstring(wserializer.getValue(selection, "icon")[0].get!string())],
							[TextInputType.NULL, TextInputType.TEXT] );
					break;
				case "ListBox":
					list ~= new ListBoxItem(["header", "[...]"], [TextInputType.NULL, TextInputType.NULL]);
					break;
				case "RadioButtonGroup":
					dstring optionName;
					Value[] optionNameValues = wserializer.getValue(selection, "options");
					foreach(v ; optionNameValues){
						optionName ~= toUTF32(v.get!string()) ~ ';';
					}
					list ~= [new ListBoxItem(["rowHeight",conv.to!dstring(wserializer.getValue(selection,"rowHeight")[0].get!int())],
							[TextInputType.NULL, TextInputType.DECIMAL]), new ListBoxItem(["options", optionName], [TextInputType.NULL,
							TextInputType.TEXT])];
					break;
				case "HSlider", "VSlider":
					list ~= [new ListBoxItem(["barLength",conv.to!dstring(wserializer.getValue(selection,"barLength")[0].get!int())],
							[TextInputType.NULL, TextInputType.DECIMAL]),
							new ListBoxItem(["maxValue",conv.to!dstring(wserializer.getValue(selection,"maxValue")[0].get!int())],
							[TextInputType.NULL, TextInputType.DECIMAL])];
					break;
				default:
					break;
			}
			ewh.propList.updateColumns(list);
		}else{
			ListBoxItem[] list = [new ListBoxItem(["name", conv.to!dstring(wserializer.getWindowName)], [TextInputType.NULL,
					TextInputType.TEXT]),
					new ListBoxItem(["title", toUTF32(wserializer.getWindowValue("title")[0].get!string())], [TextInputType.NULL,
					TextInputType.TEXT]),
					new ListBoxItem(["size:x", conv.to!dstring(wserializer.getWindowValue("size:x")[0].get!int())], [TextInputType.NULL,
					TextInputType.TEXT]),
					new ListBoxItem(["size:y", conv.to!dstring(wserializer.getWindowValue("size:y")[0].get!int())], [TextInputType.NULL,
					TextInputType.TEXT])];

			ewh.propList.updateColumns(list);
		}
	}

	public void selectEvent(WindowElement we){
		foreach(s; elements.byKey){
			if(elements[s] == we){
				selection = s;
				updatePropertyList;
				return;
			}
		}
	}

	public void menuEvent(Event ev){
		switch(ev.source){
			case "Export":
				ewh.addWindow(new FileDialog("Export Window"d, "export", &onExportWindow,
						[FileDialog.FileAssociationDescriptor("D file"d, ["*.d"])], "./", true));
				break;
			case "saveAs":
				ewh.addWindow(new FileDialog("Save Window as"d, "windowsaver", &onSaveFileAs,
						[FileDialog.FileAssociationDescriptor("SDL file"d, ["*.sdl"])], "./", true));
				break;
			case "save":
				if(wserializer.getFilename){
					wserializer.store;
				}else{
					ewh.addWindow(new FileDialog("Save Window as"d, "windowsaver", &onSaveFileAs,
							[FileDialog.FileAssociationDescriptor("SDL file"d, ["*.sdl"])], "./", true));
				}
				break;
			case "load":
				//stdio.writeln(&onLoadFile);
				ewh.addWindow(new FileDialog("Load Window"d, "windowloader", &onLoadFile,
						[FileDialog.FileAssociationDescriptor("SDL file"d, ["*.sdl"])], "./"));
				break;
			case "undo":
				eventStack.undo;
				break;
			case "redo":
				eventStack.redo;
				break;
			case "exit":
				onQuit;
				break;
			case "Label":
				typeSel = ElementType.Label;
				break;
			case "Button":
				typeSel = ElementType.Button;
				break;
			case "TextBox":
				typeSel = ElementType.TextBox;
				break;
			case "ListBox":
				typeSel = ElementType.ListBox;
				break;
			case "CheckBox":
				typeSel = ElementType.CheckBox;
				break;
			case "RadioButton":
				typeSel = ElementType.RadioButton;
				break;
			case "MenuBar":
				typeSel = ElementType.MenuBar;
				break;
			case "HSlider":
				typeSel = ElementType.HSlider;
				break;
			case "VSlider":
				typeSel = ElementType.VSlider;
				break;
			default:
				break;
		}
	}
	public void delElement() {
		if(selection != "window" && selection.length)
			eventStack.addToTop(new DeleteEvent(elements[selection], selection));
	}
	public void initElemMove() {
		if(selection != "window" && selection.length) {
			moveElemMode = true;
			moveElemOrig = elements[selection].position;
		}
	}
	public void deinitElemMove() {
		if(moveElemMode) {
			moveElemMode = false;
			elements[selection].position = moveElemOrig;
			dw.draw();
		}
	}
	public void finalizeElemMove() {
		if(moveElemMode) {
			moveElemMode = false;
			Coordinate newPos = elements[selection].position;
			elements[selection].position = moveElemOrig;
			eventStack.addToTop(new MoveElemEvent(newPos, selection));
		}
	}
	public void initElemResize() {
		if(selection == "window") {
			
			
		} else if(selection.length) {
			resizeMode = true;
		}
	}
	public void deinitElemResize() {
		if(resizeMode) {
			resizeMode = false;
		}
	}
	public void finalizeElemResize() {
		if(resizeMode) {
			resizeMode = false;
			if(selection == "window") {

			} else if (selection.length) {
				if (x0 <= elements[selection].position.left || y0 <= elements[selection].position.top) {
					ewh.messageWindow("Resize error!", "Out of bound resizing!");
				} else {
					const Coordinate newPos = Coordinate(elements[selection].position.left, elements[selection].position.top, x0, y0);
					eventStack.addToTop(new MoveElemEvent(newPos, selection));
				}
			}
		}
	}
	public void whereTheMagicHappens(){
		while(!onExit){
			mainRaster.refresh();
			inputH.test();
		}
	}
	public void onQuit(){
		onExit = true;
	}
	public void controllerRemoved(uint ID){}
	public void controllerAdded(uint ID){}
	//public void keyPressed(string ID, uint timestamp, uint devicenumber, uint devicetype) {
	public void axisEvent(uint id, BindingCode code, uint timestamp, float value) {

	}
	public void keyEvent(uint id, BindingCode code, uint timestamp, bool isPressed) {
		import PixelPerfectEngine.system.etc : hashCalc;
		if (isPressed) {
			switch(id){
				case hashCalc("undo"):
					eventStack.undo;
					break;
				case hashCalc("redo"):
					eventStack.redo;
					break;
				case hashCalc("del"):
					const string prevSelection = selection;
					selection = "window";
					eventStack.addToTop(new DeleteEvent(elements[prevSelection], prevSelection));
					break;
				case hashCalc("sysesc"):
					deinitElemMove;
					deinitElemResize;
					typeSel = ElementType.NULL;
					break;
				case hashCalc("Label"):
					typeSel = ElementType.Label;
					break;
				case hashCalc("Button"):
					typeSel = ElementType.Button;
					break;
				case hashCalc("TextBox"):
					typeSel = ElementType.TextBox;
					break;
				case hashCalc("ListView"):
					typeSel = ElementType.ListBox;
					break;
				case hashCalc("CheckBox"):
					typeSel = ElementType.CheckBox;
					break;
				case hashCalc("RadioButton"):
					typeSel = ElementType.RadioButton;
					break;
				case hashCalc("MenuBar"):
					typeSel = ElementType.MenuBar;
					break;
				case hashCalc("HSlider"):
					typeSel = ElementType.HSlider;
					break;
				case hashCalc("VSlider"):
					typeSel = ElementType.VSlider;
					break;
				default:
					break;
			}
		}
	}
	
}
