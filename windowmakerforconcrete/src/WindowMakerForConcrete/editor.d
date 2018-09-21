module editor;

import PixelPerfectEngine.concrete.window;
import PixelPerfectEngine.system.inputHandler;
import PixelPerfectEngine.graphics.layers;
import PixelPerfectEngine.graphics.raster;
import PixelPerfectEngine.graphics.outputScreen;

public class EditorWindowHandler : WindowHandler, ElementContainer{
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
		propTLW = [40, 320];
		propSLW = [160, 320, 48, 64];
		propSLEW = [160, 320, 40, 56];
		WindowElement.popUpHandler = this;
		this.ie = ie;
	}

	public void initGUI(){
		output.drawFilledRectangle(0, rasterX, 0, rasterY, 0x0005);
		
		PopUpMenuElement[] menuElements;
		menuElements ~= new PopUpMenuElement("file", "FILE");

		menuElements[0] ~= new PopUpMenuElement("new", "New window", "Ctrl + N");
		menuElements[0] ~= new PopUpMenuElement("load", "Load window", "Ctrl + L");
		menuElements[0] ~= new PopUpMenuElement("save", "Save window", "Ctrl + S");
		menuElements[0] ~= new PopUpMenuElement("saveAs", "Save window as", "Ctrl + Shift + S");
		menuElements[0] ~= new PopUpMenuElement("saveTemp", "Export window as D code", "Ctrl + Shift + I");
		menuElements[0] ~= new PopUpMenuElement("exit", "Exit application", "Alt + F4");

		menuElements ~= new PopUpMenuElement("edit", "EDIT");
		
		menuElements[1] ~= new PopUpMenuElement("undo", "Undo", "Ctrl + Z");
		menuElements[1] ~= new PopUpMenuElement("redo", "Redo", "Ctrl + Shift + Z");
		menuElements[1] ~= new PopUpMenuElement("copy", "Copy", "Ctrl + C");

		menuElements ~= new PopUpMenuElement("elements", "ELEMENTS");
		
		menuElements[2] ~= new PopUpMenuElement("Label", "Label", "Ctrl + F1");
		menuElements[2] ~= new PopUpMenuElement("Button", "Button", "Ctrl + F2");
		menuElements[2] ~= new PopUpMenuElement("TextBox", "TextBox", "Ctrl + F3");
		menuElements[2] ~= new PopUpMenuElement("ListBox", "TextBox", "Ctrl + F4");
		menuElements[2] ~= new PopUpMenuElement("CheckBox", "CheckBox", "Ctrl + F5");
		menuElements[2] ~= new PopUpMenuElement("RadioButtonGroup", "RadioButtonGroup", "Ctrl + F6");
		menuElements[2] ~= new PopUpMenuElement("Menubar", "Menubar", "Ctrl + F7");
		menuElements[2] ~= new PopUpMenuElement("HSlider", "HSlider", "Ctrl + F3");
		menuElements[2] ~= new PopUpMenuElement("VSlider", "VSlider", "Ctrl + F3");
		
		menuElements ~= new PopUpMenuElement("help", "HELP");

		menuElements[3] ~= new PopUpMenuElement("helpFile", "Content", "F1");
		menuElements[3] ~= new PopUpMenuElement("about", "About");
		
		MenuBar mb = new MenuBar("menubar",Coordinate(0,0,rasterX - 1,16),menuElements);
		addElement(mb, EventProperties.MOUSE);
		
		objectList = new ListBox("objectList", Coordinate(644,20,rasterX - 5,238), [], new ListBoxHeader(["Name"w,"Type"w],[128,128]),16);
		propList = new ListBox("propList", Coordinate(644,242,rasterX - 5,477), [], new ListBoxHeader(["Prop"w,"Val"w],[128,128]),16,true);
		addElement(objectList, EventProperties.MOUSE | EventProperties.SCROLL);
		addElement(propList, EventProperties.MOUSE | EventProperties.SCROLL);

		foreach(WindowElement we; labels){
			addElement(we, 0);
		}
		foreach(WindowElement we; elements){
			we.draw();
		}
		mb.onMouseLClickPre = &ie.menuEvent;
	}

	public override StyleSheet getStyleSheet(){
		return defaultStyle;
	}

	public void addElement(WindowElement we, int eventProperties){
		elements ~= we;
		we.elementContainer = this;
		//we.al ~= this;
		if((eventProperties & EventProperties.KEYBOARD) == EventProperties.KEYBOARD){
			keyboardC ~= we;
		}
		if((eventProperties & EventProperties.MOUSE) == EventProperties.MOUSE){
			mouseC ~= we;
		}
		if((eventProperties & EventProperties.SCROLL) == EventProperties.SCROLL){
			scrollC ~= we;
		}
	}

	public override void drawUpdate(WindowElement sender){
		output.insertBitmap(sender.getPosition().left,sender.getPosition().top,sender.output.output);
	}
	
	override public void passMouseEvent(int x,int y,int state,ubyte button) {
		foreach(WindowElement e; mouseC){
			if(e.getPosition().left < x && e.getPosition().right > x && e.getPosition().top < y && e.getPosition().bottom > y){
				e.onClick(x - e.getPosition().left, y - e.getPosition().top, state, button);
				return;
			}
		}
	}
	public override void passScrollEvent(int wX, int wY, int x, int y){
		foreach(WindowElement e; scrollC){
			if(e.getPosition().left < wX && e.getPosition().right > wX && e.getPosition().top < wX && e.getPosition().bottom > wY){
				
				e.onScroll(y, x, wX, wY);

				return;
			}
		}
	}
	public Coordinate getAbsolutePosition(WindowElement sender){
		return sender.position;
	}
}

public class DummyWindow : Window{
	Editor ed;
	public this(Coordinate coordinates, wstring name, Editor ed){
		super(coordinates, name);
		this.ed = ed;
	}
	override public void passMouseEvent(int x,int y,int state,ubyte button) {
		//super.passMouseEvent(x,y,state,button);
		if(button == MouseButton.LEFT){
			ed.placementEvent(x,y,state);
		}else if(button == MouseButton.RIGHT){
			foreach(we; elements){
				Coordinate c = we.position;
				if(x > c.left && x < c.right){
					if(y > c.top && y < c.bottom){
						ed.selectEvent(we);
					}
				}
			}
		}
	}
	override public void close() {
	//super.close;
	}
	
}

public class Editor : SystemEventListener{
	EditorWindowHandler ewh;
	DummyWindow dw;
	SpriteLayer sprtL;
	Raster mainRaster;
	OutputScreen outScrn;
	InputHandler inputH;
	bool onExit;
	
	public this(){
		import PixelPerfectEngine.system.systemUtility;
		sprtL = new SpriteLayer(LayerRenderingMode.COPY);
		outScrn = new OutputScreen("WindowMaker for PPE/Concrete",1696,960);
		mainRaster = new Raster(848,480,outScrn);
		mainRaster.addLayer(sprtL,0);

		ewh = new EditorWindowHandler(1696,960,848,480,sprtL, this);
		mainRaster.palette = [Color(0x00,0x00,0x00,0x00),Color(0xFF,0xFF,0xFF,0xFF),Color(0xFF,0x34,0x9e,0xff),Color(0xff,0xa2,0xd7,0xff),	
		Color(0xff,0x00,0x2c,0x59),Color(0xff,0x00,0x75,0xe7),Color(0xff,0xff,0x00,0x00),Color(0xFF,0x7F,0x00,0x00),
		Color(0xFF,0x00,0xFF,0x00),Color(0xFF,0x00,0x7F,0x00),Color(0xFF,0x00,0x00,0xFF),Color(0xFF,0x00,0x00,0x7F),
		Color(0xFF,0xFF,0xFF,0x00),Color(0xFF,0xFF,0x7F,0x00),Color(0xFF,0x7F,0x7F,0x7F),Color(0xFF,0x00,0x00,0x00)];
		INIT_CONCRETE(ewh);
		inputH = new InputHandler();
		inputH.sel ~= this;
		inputH.ml ~= ewh;
		ewh.initGUI();
		dw = new DummyWindow(Coordinate(0,16,640,480), "New Window"w, this);
		ewh.addWindow(dw);
	}

	public void placementEvent(int x, int y, int state){
		
	}

	public void selectEvent(WindowElement we){
		
	}

	public void menuEvent(Event ev){
		switch(ev.source){
			case "exit":
				onQuit;
				break;
			default:
				break;
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
}