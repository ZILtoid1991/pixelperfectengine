/*
 *Copyright (C) 2015, by Laszlo Szeremi under the Boost license.
 *
 *VDP Engine, windowing.window module
 */

module windowing.window;

import graphics.bitmap;
import graphics.draw;
import graphics.layers;
public import windowing.elements;
import system.etc;
import system.inputHandler;

import std.algorithm.mutation;
import std.stdio;
import std.conv;
import std.file;
import std.datetime;

public class Window : ElementContainer{
	private WindowElement[] elements, mouseC, keyboardC, scrollC;
	public wstring title;
	public IWindowHandler parent;
	public Bitmap16Bit[int] altStyleBrush;
	public BitmapDrawer output;
	public int style, closeButton, header, font, sizeX, sizeY, brushNormal;
	private int moveX, moveY;
	private bool move, fullUpdate;
	public Coordinate position;
	/*
	 * If the current window doesn't contain the special stylebrush, it gets from it's parent. 
	 */
	public Bitmap16Bit getStyleBrush(int style){
		//if(altStyleBrush.get(style, null) is null){
			return parent.getStyleBrush(style);
		//}
		//return altStyleBrush[style];
	}

	public void drawUpdate(WindowElement sender){
		/*if(!fullUpdate){ 
			this.draw();
		}*/
		output.insertBitmap(sender.getPosition().xa,sender.getPosition().ya,sender.output.output);
	}

	public Bitmap16Bit[wchar] getFontSet(int style){
		return parent.getFontSet(style);
	}

	public this(Coordinate size, wstring title){
		position = size;
		output = new BitmapDrawer(position.getXSize, position.getYSize);
		this.title = title;
		sizeX = position.getXSize;
		sizeY = position.getYSize;
		style = 0;
		closeButton = 2;
	}

	public void addElement(WindowElement we, int eventProperties){
		elements ~= we;
		we.elementContainer = this;
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

	public void draw(){

		output.drawFilledRectangle(0, position.getXSize() - 1, 0, position.getYSize() - 1, 154);
		output.insertBitmap(0,0,getStyleBrush(closeButton));
		int x1 = getStyleBrush(closeButton).getX(), y1 = getStyleBrush(closeButton).getY();
		/*output.drawRectangle(x1, sizeX - 1, 0, y1, getStyleBrush(header));
		output.drawFilledRectangle(x1 + (x1/2), sizeX - 1 - (x1/2), y1/2, y1 - (y1/2), getStyleBrush(header).readPixel(x1/2, y1/2));*/
		//drawing the header
		output.drawLine(x1, position.getXSize() - 1, 0, 0, 158);
		output.drawLine(x1, x1, 0, y1 - 1, 158);
		output.drawLine(x1, position.getXSize() - 1, y1 - 1, y1 - 1, 145);
		output.drawLine(position.getXSize() - 1, position.getXSize() - 1, 0, y1 - 1, 145);

		//drawing the border of the window
		output.drawLine(0, position.getXSize() - 1, y1, y1, 158);
		output.drawLine(0, 0, y1, position.getYSize() - 1, 158);
		output.drawLine(0, position.getXSize() - 1, position.getYSize() - 1, position.getYSize() - 1,  145);
		output.drawLine(position.getXSize() - 1, position.getXSize() - 1, y1, position.getYSize() - 1, 145);

		output.drawText(x1+1, 1, title, getFontSet(0), 1);
		fullUpdate = true;
		foreach(WindowElement we; elements){
			we.draw();
			//output.insertBitmap(we.getPosition().xa,we.getPosition().ya,we.output.output);
		}
		fullUpdate = false;
	}

	public void passMouseEvent(int x, int y, int state = 0){
		//writeln(x, ",", y);
		if(getStyleBrush(closeButton).getX() > x && getStyleBrush(closeButton).getY() > y && state == 0){
			parent.closeWindow(this);
			return;
		}else if(getStyleBrush(closeButton).getY() > y && state == 0){
			/*if(state == 0 && !move){
				move = true;
				moveY = y;
			}
			if(state == 1 && move){
				move = false;
				position.move(x - moveX, y - moveY);
				parent.moveUpdate(this);
			}*/
			parent.moveUpdate(this);
		}
		//x -= position.xa;
		//y -= position.ya;
		foreach(WindowElement e; mouseC){
			if(e.getPosition().xa < x && e.getPosition().xb > x && e.getPosition().ya < y && e.getPosition().yb > y){
				e.onClick(x - e.getPosition().xa, y - e.getPosition().ya, state);
				return;
			}
		}

	}
	public void passScrollEvent(int wX, int wY, int x, int y){
		foreach(WindowElement e; scrollC){
			if(e.getPosition().xa < wX && e.getPosition().xb > wX && e.getPosition().ya < wX && e.getPosition().yb > wY){

				e.onScroll(x, y, wX, wY);
				return;
			}
		}
	}
	public void passKeyboardEvent(wchar c, int type, int x, int y){

	}
	public void addParent(IWindowHandler wh){
		parent = wh;
	}
	public void getFocus(WindowElement sender){

	}
	public void dropFocus(WindowElement sender){

	}
}

public class DefaultDialog : Window, ActionListener{
	public ActionListener[] al;
	private string source;

	public this(Coordinate size, string source, wstring title, wstring message, wstring[] options = ["Ok"]){
		this(size, title);
		//generate text
		//NOTE: currently only works with one line texts, later on multi-line texts will be added
		//NOTE: currently only optimized for 8 pixel wide fonts
		this.source = source;
		int x1 , x2;
		//writeln(x1,',',size.getXSize - x1);
		Label msg = new Label(message, "null", Coordinate(8, 20, size.getXSize()-8, 40));
		addElement(msg, EventProperties.MOUSE);

		//generate buttons

		x1 = size.getXSize - 10;
		Button[] buttons;
		for(int i; i < options.length; i++){
			x2 = x1 - ((options[i].length + 2) * 8);
			buttons ~= new Button(options[i], to!string(options[i]), Coordinate(x2, 40, x1, 60));
			buttons[i].al ~= this;
			addElement(buttons[i], EventProperties.MOUSE);
			x1 = x2;
		}
	}

	public this(Coordinate size, wstring title){
		super(size, title);
	}

	public void actionEvent(string source, int type, int value, wstring message){
		foreach(a; al){
			a.actionEvent(source, this.source, type, value, message);
		}
	}
	public void actionEvent(string source, string subSource, int type, int value, wstring message){}
}

public class FileDialog : Window, ActionListener{
	private ActionListener al;
	private string source;
	private string[] filetypes, pathList, driveList;
	private string directory;
	private ListBox lb;
	private TextBox tb;
	private ListBoxColumn[] columns;
	private bool save;

	public this(Coordinate size, wstring title){
		super(size, title);
	}

	public this(wstring title, string source, ActionListener a, string[] filetypes, string startDir, TextInputHandler tih, bool save = false, string filename = ""){
		this(Coordinate(20,20,240,198), title);
		this.source = source;
		this.filetypes = filetypes;
		this.save = save;
		al = a;
		directory = startDir;
		//generate buttons
		Button[] buttons;
		buttons ~= new Button("Up","up",Coordinate(4, 154, 54, 174));
		buttons ~= new Button("Drive","drv",Coordinate(58, 154, 108, 174));
		if(save)
			buttons ~= new Button("Save","ok",Coordinate(112, 154, 162, 174));
		else
			buttons ~= new Button("Load","ok",Coordinate(112, 154, 162, 174));
		buttons ~= new Button("Close","close",Coordinate(166, 154, 216, 174));
		for(int i; i < buttons.length; i++){
			buttons[i].al ~= this;
			addElement(buttons[i], EventProperties.MOUSE);
		}
		//generate textbox
		tb = new TextBox(to!wstring(filename), "filename", Coordinate(4, 130, 162, 150));
		tb.addTextInputHandler(tih);
		tb.al ~= this;
		addElement(tb, EventProperties.MOUSE);
		//generate listbox

		//test parameters

		//writeln(dirEntries(startDir, SpanMode.shallow));


		columns ~= ListBoxColumn("Name", ["aaa","aaa","aaa","aaa","aaa","aaa","aaa"]);
		columns ~= ListBoxColumn("Type", ["bbb","bbb","bbb","bbb","aaa","aaa","aaa"]);
		//Date format: yyyy-mm-dd hh:mm:ss
		columns ~= ListBoxColumn("Date", ["yyyy-mm-dd hh:mm:ss","yyyy-mm-dd hh:mm:ss","yyyy-mm-dd hh:mm:ss","yyyy-mm-dd hh:mm:ss","yyyy-mm-dd hh:mm:ss","yyyy-mm-dd hh:mm:ss","yyyy-mm-dd hh:mm:ss"]);
		spanDir();

		//writeln(pathList);

		//VSlider vsl = new VSlider(20,5,"sld",Coordinate(200,20,216,124));
		//addElement(vsl, EventProperties.MOUSE);
		//HSlider hsl = new HSlider(200,48,"vsld",Coordinate(4, 108, 200, 124));
		//addElement(hsl, EventProperties.MOUSE);
		lb = new ListBox("lb", Coordinate(4, 20, 216, 126),columns ,[160, 40, 176] ,15);
		addElement(lb, EventProperties.MOUSE | EventProperties.SCROLL);
		//scrollC ~= lb;
		lb.al ~= this;
		detectDrive();
	}

	private void spanDir(){
		pathList.length = 0;
		columns[0].elements.length = 0;
		columns[1].elements.length = 0;
		columns[2].elements.length = 0;
		foreach(DirEntry de; dirEntries(directory, SpanMode.shallow)){
			if(de.isDir){
				pathList ~= de.name;
				columns[0].elements ~= to!wstring(getFilenameFromPath(de.name));
				columns[1].elements ~= "<DIR>";
				columns[2].elements ~= formatDate(de.timeLastModified);
			}
		}
		foreach(string ft; filetypes){
			foreach(DirEntry de; dirEntries(directory, ft, SpanMode.shallow)){
				if(de.isFile){
					pathList ~= de.name;
					columns[0].elements ~= to!wstring(getFilenameFromPath(de.name, true));
					columns[1].elements ~= to!wstring(ft);
					columns[2].elements ~= formatDate(de.timeLastModified);
				}
			}
		}

	}

	private wstring formatDate(SysTime time){
		wstring s;
		s ~= to!wstring(time.year());
		s ~= "-";
		s ~= to!wstring(time.month());
		s ~= "-";
		s ~= to!wstring(time.day());
		s ~= " ";
		s ~= to!wstring(time.hour());
		s ~= ":";
		s ~= to!wstring(time.minute());
		s ~= ":";
		s ~= to!wstring(time.second());
		//writeln(s);
		return s;
	}

	private void detectDrive(){
		driveList.length = 0;
		for(char c = 'A'; c <='Z'; c++){
			string s;
			s ~= c;
			s ~= ":\x5c";
			if(exists(s)){
				driveList ~= (s);
			}
		}
		//writeln(driveList);
	}

	private string getFilenameFromPath(string p, bool b = false){
		int n, m = p.length;
		string s;
		for(int i ; i < p.length ; i++){
			if(p[i] == '\x5c'){
				n = i;
			}
		}
		//n++;
		if(b){
			for(int i ; i < p.length ; i++){
				if(p[i] == '.'){
					m = i;
				}
			}
		}
		for( ; n < m ; n++){
			if(p[n] < 128 && p[n] > 31)
				s ~= p[n];
		}
		return s;
	}

	private void up(){
		int n;
		for(int i ; i < directory.length ; i++){
			if(directory[i] == '\x5c'){
				n = i;
			}
		}
		string newdir;
		for(int i ; i < n ; i++){
			newdir ~= directory[i];
		}
		directory = newdir;
		spanDir();
		lb.updateColumns(columns);
		lb.draw();
	}

	private void changeDrive(){
		pathList.length = 0;
		columns[0].elements.length = 0;
		columns[1].elements.length = 0;
		columns[2].elements.length = 0;
		foreach(string drive; driveList){
			pathList ~= drive;
			columns[0].elements ~= to!wstring(drive);
			columns[1].elements ~= "<DRV>";
			columns[2].elements ~= "N/A";
		}
		lb.updateColumns(columns);
		lb.draw();
	}

	private void fileEvent(){
		wstring s = to!wstring(directory);
		s ~= tb.getText();
		al.actionEvent("file", EventType.FILEDIALOGEVENT, 0, s);
		parent.closeWindow(this);
	}

	public void actionEvent(string source, int type, int value, wstring message){
		if(source == "lb"){
			//writeln(value);
			try{
				if(isDir(pathList[value])){
					directory = pathList[value];
					spanDir();
					lb.updateColumns(columns);
					lb.draw();
				}
			}catch(FileException e){
				writeln(e.msg);
			}
		}else if(source == "up"){
			up();
		}else if(source == "drv"){
			changeDrive();
		}else if(source == "ok"){
			fileEvent();
		}else if(source == "close"){
			parent.closeWindow(this);
		}
	}
	public void actionEvent(string source, string subSource, int type, int value, wstring message){}
}

public class WindowHandler : InputListener, MouseListener, IWindowHandler{
	private Window[] windows;
	private int[] priorities;
	public int screenX, screenY, rasterX, rasterY, moveX, moveY;
	public Bitmap16Bit[wchar] basicFont, altFont, alarmFont;
	public Bitmap16Bit[int] styleBrush;
	private Bitmap16Bit background;
	private ISpriteLayer16Bit spriteLayer;
	private bool moveState, dragEventState;
	private Window windowToMove, dragEventDest;

	public this(int sx, int sy, int rx, int ry,ISpriteLayer16Bit sl){
		screenX = sx;
		screenY = sy;
		rasterX = rx;
		rasterY = ry;
		spriteLayer = sl;
	}

	public void addWindow(Window w){
		windows ~= w;
		w.addParent(this);
		//priorities ~= 666;
		w.draw();
		setWindowToTop(w);

		/*for(int i ; i < windows.length ; i++){
			spriteLayer.addSprite(windows[i].output.output, i, windows[i].position);
		}*/
	}

	public void addBackground(Bitmap16Bit b){
		background = b;
		spriteLayer.addSprite(background, 65536, 0, 0);
	}

	private int whichWindow(Window w){
		for(int i ; i < windows.length ; i++){
			if(windows[i] == w){
				return i;
			}
		}
		return -1;
	}

	public void setWindowToTop(Window sender){
		int s;
		foreach(Window w; windows){
			if(w == sender){
				Window ww = windows[s];
				windows[s] = windows[0];
				windows[0] = ww;
				updateSpriteOrder();
				break;
			}else{
				s++;
			}
		}

	}

	private void updateSpriteOrder(){
		for(int i ; i < windows.length ; i++){
			spriteLayer.removeSprite(i);
			spriteLayer.addSprite(windows[i].output.output, i, windows[i].position);

		}
	}

	public Bitmap16Bit[wchar] getFontSet(int style){
		switch(style){
			case 0: return basicFont;
			case 1: return altFont;
			case 3: return alarmFont;
			default: break;
		}
		return basicFont;

	}
	public Bitmap16Bit getStyleBrush(int style){
		return styleBrush[style];
	}
	public void closeWindow(Window sender){
		int p = whichWindow(sender);
		for(int i ; i < windows.length ; i++)
			spriteLayer.removeSprite(i);
		//spriteLayer.removeSprite(p);
		windows = remove(windows, p);

		updateSpriteOrder();
	}

	public void moveUpdate(Window sender){
		moveState = true;
		windowToMove = sender;
		//writeln(moveState);
	}
	public void keyPressed(string ID, Uint32 timestamp, Uint32 devicenumber, Uint32 devicetype){

	}
	public void keyReleased(string ID, Uint32 timestamp, Uint32 devicenumber, Uint32 devicetype){

	}
	public void mouseButtonEvent(Uint32 which, Uint32 timestamp, Uint32 windowID, Uint8 button, Uint8 state, Uint8 clicks, Sint32 x, Sint32 y){

		//converting the dimensions
		double xR = to!double(rasterX) / to!double(screenX) , yR = to!double(rasterY) / to!double(screenY);
		x = to!int(x * xR);
		y = to!int(y * yR);


		if(state == SDL_RELEASED && moveState){
			/*windowToMove.position.relMove(x - moveX, y - moveY);
			spriteLayer.relMoveSprite(whichWindow(windowToMove), x - moveX, y - moveY);*/
			//writeln(x - moveX, y - moveY);
			moveState = false;
		}else if(state == SDL_RELEASED && moveState){
			dragEventState = false;
		}
		else if(state == SDL_PRESSED){
			moveX = x; 
			moveY = y;

			for(int i ; i < windows.length ; i++){
				//writeln(i);
				if(x >= windows[i].position.xa && x <= windows[i].position.xb && y >= windows[i].position.ya && y <= windows[i].position.yb){
					if(i == 0){
						windows[0].passMouseEvent(x - windows[0].position.xa, y - windows[0].position.ya, 0);
						if(windows.length !=0){
							dragEventState = true;
							dragEventDest = windows[0];
						}
						return;
					}
					else{
						setWindowToTop(windows[i]);
						return;
					}
				}
			}
			passMouseEvent(x,y);
		}

	}
	public void passMouseEvent(int x, int y, int state = 0){

	}
	public void mouseWheelEvent(uint type, uint timestamp, uint windowID, uint which, int x, int y, int wX, int wY){
		double xR = to!double(rasterX) / to!double(screenX) , yR = to!double(rasterY) / to!double(screenY);
		wX = to!int(wX * xR);
		wY = to!int(wY * yR);
		if(windows.length != 0)
			windows[0].passScrollEvent(wX - windows[0].position.xa, wY - windows[0].position.ya, y, x);
		passScrollEvent(wX,wY,x,y);
	}
	public void passScrollEvent(int wX, int wY, int x, int y){

	}
	public void mouseMotionEvent(uint timestamp, uint windowID, uint which, uint state, int x, int y, int relX, int relY){
		double xR = to!double(rasterX) / to!double(screenX) , yR = to!double(rasterY) / to!double(screenY);
		x = to!int(x * xR);
		y = to!int(y * yR);
		relX = to!int(relX * xR);
		relY = to!int(relY * yR);
		if(state == SDL_PRESSED && moveState){
			windowToMove.position.relMove(relX, relY);
			spriteLayer.relMoveSprite(whichWindow(windowToMove), relX, relY);
		}else if(state == SDL_PRESSED && dragEventState){
			dragEventDest.passMouseEvent(x - dragEventDest.position.xa,y - dragEventDest.position.ya,-1);
		}
	}
}

public interface IWindowHandler{
	public Bitmap16Bit[wchar] getFontSet(int style);
	public Bitmap16Bit getStyleBrush(int style);
	public void closeWindow(Window sender);
	public void moveUpdate(Window sender);
	public void setWindowToTop(Window sender);
}

public enum EventProperties : uint{
	KEYBOARD		=	1,
	MOUSE			=	2,
	SCROLL			=	4
}