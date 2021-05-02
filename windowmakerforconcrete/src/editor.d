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
	Editor editor;
	public this(int width, int height, Editor e) {
		import PixelPerfectEngine.graphics.draw;
		super(Box(0, 0, width, height), ""d, [], null);
		editor = e;
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

		mb = new MenuBar("mb", Box(0, 0, width-1, 15), menuElements);
		objectList = new ListView(new ListViewHeader(16, [128, 128], ["type"d, "name"d]), [], "objectList", 
				Box(644,20,width - 5,238));
		propList = new ListView(new ListViewHeader(16, [128,256], ["Prop"d,"Val"d]), [], "propList",
				Box(644,242,width - 5,477));

		propList.editEnable = true;

		addElement(mb);
		addElement(objectList);
		addElement(propList);

		mb.onMenuEvent = &e.menuEvent;
		objectList.onItemSelect = &e.onObjectListSelect;
		propList.onTextInput = &e.onAttributeEdit;
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
				if(c.isBetween(mce.x, mce.y))
					ed.selectEvent(we);
			}
		}
	}
	public void setWidth(int val) {
		position.width = val;
		draw();
	}
	public void setHeight(int val) {
		position.height = val;
		draw();
	}
	public void setSize(int width, int height) {
		position.width = width;
		position.height = height;
		draw();
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
	string[string]		elementTypes;
	string				selection;
	ConfigurationProfile	config;
	TopLevelWindow		tlw;

	static string[ElementType] nameBases;
	public this(){
		import PixelPerfectEngine.system.systemUtility;
		import PixelPerfectEngine.system.file;
		
		sprtL = new SpriteLayer(RenderingMode.Copy);
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
		inputH.mouseListener = ewh;
		
		//ewh.setBaseWindow(new TopLevelWindow(848, 480, this));
		config = new ConfigurationProfile("config_wmfc.sdl", "../system/config_wmfc.sdl");
		{
			import PixelPerfectEngine.system.input.scancode;
			inputH.addBinding(BindingCode(ScanCode.ESCAPE, 0, Devicetype.Keyboard, 0, KeyModifier.LockKeys), InputBinding("sysesc"));
		}
		config.loadBindings(inputH);

		PopUpElement.inputhandler = inputH;
		WindowElement.inputHandler = inputH;
		
		dw = new DummyWindow(Coordinate(0,16,640,480), "New Window"d, this);
		ewh.addWindow(dw);
		tlw = new TopLevelWindow(848, 480, this);
		ewh.setBaseWindow(tlw);
		eventStack = new UndoableStack(10);
		wserializer = new WindowSerializer();
		dwtarget = dw;
		editorTarget = this;
		//ewh.objectList.onItemSelect = &onObjectListSelect;
		//ewh.propList.onTextInput = &onAttributeEdit;
		updateElementList;
	}
	static this(){
		nameBases[ElementType.Label] = "label";
		nameBases[ElementType.Button] = "button";
		nameBases[ElementType.SmallButton] = "smallButton";
		nameBases[ElementType.TextBox] = "textBox";
		nameBases[ElementType.ListView] = "listView";
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
		ListViewItem lbi = cast(ListViewItem)ev.aux;
		if(lbi[0].text.text != "Window"){
			selection = conv.to!string(lbi[1].text.text);
		}else{//Fill attribute list with data related to the window
			selection = "Window";
		}
		updatePropertyList;
	}
	public void onLoadFile(Event ev){
		FileEvent ev0 = cast(FileEvent)ev;
		wserializer = new WindowSerializer(ev0.getFullPath);
		wserializer.deserialize(dw, this);
	}
	public void onSaveFileAs(Event ev){
		FileEvent ev0 = cast(FileEvent)ev;
		wserializer.store(ev0.getFullPath);
	}
	public void onExportWindow(Event ev){
		FileEvent ev0 = cast(FileEvent)ev;
		wserializer.generateDCode(ev0.getFullPath);
	}
	public void onAttributeEdit(Event ev){
		import std.utf : toUTF8;
		CellEditEvent ev0 = cast(CellEditEvent)ev;
		dstring t = ev0.text.text;
		ListViewItem lbi = cast(ListViewItem) ev.aux;
		if(selection == "window"){
			switch(lbi[0].text.text) {
				case "name":
					eventStack.addToTop(new WindowRenameEvent(conv.to!string(t)));
					return;
				case "title":
					eventStack.addToTop(new WindowRetitleEvent(t));
					return;
				case "size:x":
					eventStack.addToTop(new WindowWidthChangeEvent(conv.to!int(t)));
					return;
				case "size:y":
					eventStack.addToTop(new WindowHeightChangeEvent(conv.to!int(t)));
					return;
				default:
					return;
			}
		}else{
			switch(lbi[0].text.text){
				case "text":
					eventStack.addToTop(new TextEditEvent(t, selection));
					return;
				case "name":
					eventStack.addToTop(new RenameEvent(selection, conv.to!string(t)));
					selection = conv.to!string(t);
					return;
				case "position":
					dstring[] src = csvParser(t, ';');
					if(src.length == 4){
						Coordinate c;
						foreach(s; src){
							if(!isInteger(s)){
								ewh.message("Format Error!", "Value is not integer!");
								return;
							}
						}
						c.left = conv.to!int(src[0]);
						c.top = conv.to!int(src[1]);
						c.right = conv.to!int(src[2]);
						c.bottom = conv.to!int(src[3]);
						eventStack.addToTop(new PositionEditEvent(c, selection));
					}else{
						ewh.message("Format Error!", "Correct format is: [int];[int];[int];[int];");
					}
					return;
				case "source":
					eventStack.addToTop(new SourceEditEvent(selection, conv.to!string(t)));
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
				string s, type;
				switch(typeSel){
					case ElementType.Label:
						s = getNextName("label");
						type = "Label";
						we = new Label(conv.to!dstring(s),s,c);
						break;
					case ElementType.Button:
						s = getNextName("button");
						type = "Button";
						we = new Button(conv.to!dstring(s),s,c);
						break;
					case ElementType.TextBox:
						s = getNextName("textBox");
						type = "TextBox";
						we = new TextBox(conv.to!dstring(s),s,c);
						break;
					case ElementType.ListView:
						s = getNextName("listView");
						type = "ListView";
						we = new ListView(new ListViewHeader(16, [40, 40], ["col0", "col1"]), [], s, c);
						break;
					case ElementType.CheckBox:
						s = getNextName("CheckBox");
						type = "CheckBox";
						we = new CheckBox(conv.to!dstring(s),s,c);
						break;
					case ElementType.RadioButton:
						s = getNextName("radioButton");
						type = "RadioButton";
						we = new RadioButton(conv.to!dstring(s),s,c);
						break;
					/+case ElementType.MenuBar:
						s = getNextName("menuBar");
						we = new MenuBar(s,c,[new PopUpMenuElement("menu0","menu0")]);+/
						//break;
					case ElementType.HSlider:
						s = getNextName("horizScrollBar");
						type = "HorizScrollBar";
						we = new HorizScrollBar(16,s,c);
						break;
					case ElementType.VSlider:
						s = getNextName("vertScrollBar");
						type = "VertScrollBar";
						we = new VertScrollBar(16,s,c);
						break;
					default:
						break;
				}
				eventStack.addToTop(new PlacementEvent(we, type, s));
				typeSel = ElementType.NULL;
				//updateElementList;
			}
		} else {
			if (state == ButtonState.Pressed) {
				if(!moveElemMode && elements.get(selection, null)) {
					if (elements[selection].getPosition.isBetween(x,y)) {
						initElemMove;
						
					} else if (elements[selection].getPosition.right <= x + 1 && elements[selection].getPosition.bottom <= y + 1) {
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
			const Box temp = elements[selection].getPosition;
			if(temp.left + relX < 0) relX -= temp.left + relX;
			if(temp.right + relX >= dw.getPosition.width) relX -= (temp.right + relX) - dw.getPosition.width;
			if(temp.top + relY < 0) relY -= temp.top + relY;
			if(temp.bottom + relY >= dw.getPosition.height) relY -= (temp.bottom + relY) - dw.getPosition.height;
			elements[selection].getPosition.relMove(relX, relY);
			dw.draw();
		} else if (resizeMode) {
			x0 = x;
			y0 = y;
			dw.drawSelection(Box(elements[selection].getPosition.left, elements[selection].getPosition.top, x0, y0));
		} else if (typeSel != ElementType.NULL) {
			dw.drawSelection(Box(x0, y0, x, y), true);
		}
	}

	public void updateElementList(){
		tlw.objectList.clear();
		tlw.objectList ~= new ListViewItem(16, ["Window"d, ""d]);
		foreach(s; elements.byKey){
			tlw.objectList ~= new ListViewItem(16, [conv.to!dstring(elementTypes[s]), conv.to!dstring(s)]);
		}
		tlw.objectList.refresh();
	}
	public void updatePropertyList(){
		import sdlang;
		import std.utf;
		tlw.propList.clear();
		if(elements.get(selection, null) !is null){
			string classname = elementTypes[selection];
			tlw.propList ~= [new ListViewItem(16, ["name"d, conv.to!dstring(selection)], [TextInputFieldType.None, TextInputFieldType.Text]),
					new ListViewItem(16, ["source"d, conv.to!dstring(wserializer.getValue(selection, "source")[0].get!string())],
					[TextInputFieldType.None, TextInputFieldType.Text])];
			if(classname == "Label" || classname == "TextBox" || classname == "Button" || classname == "CheckBox" ||
					classname == "RadioButton"){
				tlw.propList ~= new ListViewItem(16, ["text", toUTF32(wserializer.getValue(selection, "text")[0].get!string())], 
						[TextInputFieldType.None, TextInputFieldType.Text]);
			}
			Value[] pos0 = wserializer.getValue(selection, "position");
			dstring pos1 = conv.to!dstring(pos0[0].get!int) ~ ";" ~ conv.to!dstring(pos0[1].get!int) ~ ";" ~
					conv.to!dstring(pos0[2].get!int) ~ ";" ~ conv.to!dstring(pos0[3].get!int) ~ ";";
			tlw.propList ~= new ListViewItem(16, ["position", pos1], [TextInputFieldType.None, TextInputFieldType.Text]);
			switch(classname){
				case "Button", "SmallButton", "SmallCheckBox", "SmallRadioButton":
					tlw.propList ~= new ListViewItem(16, ["icon", conv.to!dstring(wserializer.getValue(selection, "icon")[0].get!string())],
							[TextInputFieldType.None, TextInputFieldType.Text]);
					break;
				case "ListView":
					tlw.propList ~= new ListViewItem(16, ["header", "[...]"]);
					break;
				case "HSlider", "VSlider":
					tlw.propList ~= [new ListViewItem(16, ["barLength",conv.to!dstring(wserializer.getValue(selection,"barLength")[0].get!int())],
							[TextInputFieldType.None, TextInputFieldType.Integer]),
							new ListViewItem(16, ["maxValue",conv.to!dstring(wserializer.getValue(selection,"maxValue")[0].get!int())],
							[TextInputFieldType.None, TextInputFieldType.Integer])];
					break;
				default:
					break;
			}
			
		}else{
			tlw.propList ~= [new ListViewItem(16, ["name", conv.to!dstring(wserializer.getWindowName)], 
					[TextInputFieldType.None, TextInputFieldType.Text]),
					new ListViewItem(16, ["title", toUTF32(wserializer.getWindowValue("title")[0].get!string())], 
					[TextInputFieldType.None, TextInputFieldType.Text]),
					new ListViewItem(16, ["size:x", conv.to!dstring(wserializer.getWindowValue("size:x")[0].get!int())], 
					[TextInputFieldType.None, TextInputFieldType.Integer]),
					new ListViewItem(16, ["size:y", conv.to!dstring(wserializer.getWindowValue("size:y")[0].get!int())], 
					[TextInputFieldType.None, TextInputFieldType.Integer])];

			
		}
		tlw.propList.refresh();
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
		import PixelPerfectEngine.concrete.dialogs.filedialog : FileDialog;
		string source = (cast(MenuEvent)ev).itemSource;
		switch(source){
			case "export":
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
			case "ListView":
				typeSel = ElementType.ListView;
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
		if(selection != "Window" && selection.length)
			eventStack.addToTop(new DeleteEvent(elements[selection], selection));
	}
	public void initElemMove() {
		if(selection != "Window" && selection.length) {
			moveElemMode = true;
			moveElemOrig = elements[selection].getPosition;
		}
	}
	public void deinitElemMove() {
		if(moveElemMode) {
			moveElemMode = false;
			elements[selection].setPosition(moveElemOrig);
			dw.draw();
		}
	}
	public void finalizeElemMove() {
		if(moveElemMode) {
			moveElemMode = false;
			//Coordinate newPos = elements[selection].getPosition;
			//elements[selection].setPosition(moveElemOrig);
			eventStack.addToTop(new MoveElemEvent(elements[selection].getPosition, moveElemOrig, selection));
		}
	}
	public void initElemResize() {
		if(selection == "Window") {
			
			
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
			if(selection == "Window") {

			} else if (selection.length) {
				if (x0 <= elements[selection].getPosition.left || y0 <= elements[selection].getPosition.top) {
					ewh.message("Resize error!", "Out of bound resizing!");
				} else {
					const Box newPos = Box(elements[selection].getPosition.left, elements[selection].getPosition.top, x0, y0);
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
					typeSel = ElementType.ListView;
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
