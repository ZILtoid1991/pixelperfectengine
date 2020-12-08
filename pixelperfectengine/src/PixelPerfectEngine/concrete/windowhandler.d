module PixelPerfectEngine.concrete.windowhandler;

public import PixelPerfectEngine.concrete.interfaces;
public import PixelPerfectEngine.concrete.window;
public import PixelPerfectEngine.concrete.types;
public import PixelPerfectEngine.concrete.popup;

public import PixelPerfectEngine.system.input.interfaces;

public import PixelPerfectEngine.graphics.layers : ISpriteLayer;

import collections.linkedlist;
import PixelPerfectEngine.system.etc : cmpObjPtr;

/**
 * Handles windows as well as PopUpElements.
 */
public class WindowHandler : InputListener, MouseListener {
	alias WindowSet = LinkedList!(Window, false, "cmpObjPtr(a, b)");
	alias PopUpSet = LinkedList!(PopUpElement, false, "cmpObjPtr(a, b)");
	protected WindowSet windows;
	protected PopUpSet popUpElements;
	private int numOfPopUpElements;
	//private int[] priorities;
	protected int screenWidth, screenHeight, rasterWidth, rasterHeight, moveX, moveY, mouseX, mouseY;
	//public Bitmap16Bit[wchar] basicFont, altFont, alarmFont;
	///Sets the default style for the windowhandler.
	///If null, the global default will be used instead.
	public StyleSheet defaultStyle;
	//public Bitmap16Bit[int] styleBrush;
	private ABitmap background;
	private ISpriteLayer spriteLayer;
	private Window windowToMove;
	private PopUpElement dragEventDestPopUp;
	//private ubyte lastMouseButton;
	/**
	 * Default CTOR.
	 * sW and sH set the screen width and height.
	 * rW and rH set the raster width and height.
	 * ISpriteLayer sets the SpriteLayer, that will display the windows and popups as sprites.
	 */
	public this(int sW, int sH, int rW, int rH,ISpriteLayer sl) {
		screenWidth = sW;
		screenHeight = sH;
		rasterWidth = rW;
		rasterHeight = rH;
		spriteLayer = sl;
	}

	public void addWindow(Window w){
		windows ~= w;
		w.addParent(this);
		w.draw();
		setWindowToTop(w);
	}

	/**
	 * Adds a DefaultDialog as a message box
	 */
	public void messageWindow(dstring title, dstring message, int width = 256){
		StyleSheet ss = getStyleSheet();
		dstring[] formattedMessage = ss.getChrFormatting("label").font.breakTextIntoMultipleLines(message, width -
				ss.drawParameters["WindowLeftPadding"] - ss.drawParameters["WindowRightPadding"]);
		int height = cast(int)(formattedMessage.length * (ss.getChrFormatting("label").font.size +
				ss.drawParameters["TextSpacingTop"] + ss.drawParameters["TextSpacingBottom"]));
		height += ss.drawParameters["WindowTopPadding"] + ss.drawParameters["WindowBottomPadding"] +
				ss.drawParameters["ComponentHeight"];
		Coordinate c = Coordinate(mouseX - width / 2, mouseY - height / 2, mouseX + width / 2, mouseY + height / 2);
		Text title0 = new Text(title, ss.getChrFormatting("windowHeader"));
		//addWindow(new DefaultDialog(c, null, title0, formattedMessage));
	}
	/**
	 * Adds a background.
	 */
	public void addBackground(ABitmap b){
		background = b;
		spriteLayer.addSprite(background, 65_536, 0, 0);
	}
	/**
	 * Returns the window priority or -1 if the window can't be found.
	 */
	private sizediff_t whichWindow(Window w) @safe nothrow {
		try
			windows.which(w);
		catch (Exception e)
			return -1;
	}
	/**
	 * Sets sender to be top priority.
	 */
	public void setWindowToTop(Window sender) @safe nothrow {
		sizediff_t pri = windows.which(sender);
		windows.setAsFirst(pri);
		updateSpriteOrder();
	}

	private void updateSpriteOrder(){
		for(int i ; i < windows.length ; i++){
			spriteLayer.removeSprite(i);
			spriteLayer.addSprite(windows[i].getOutput, i, windows[i].position);

		}
	}

	/*public Bitmap16Bit[wchar] getFontSet(int style){
		switch(style){
			case 0: return basicFont;
			case 1: return altFont;
			case 3: return alarmFont;
			default: break;
		}
		return basicFont;

	}*/
	public StyleSheet getStyleSheet(){
		return defaultStyle;
	}
	public void closeWindow(Window sender){
		//writeln(sender);
		dragEventState = false;
		dragEventDest = null;
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
	}
	/+public void keyPressed(string ID, uint timestamp, uint devicenumber, uint devicetype){

	}
	public void keyReleased(string ID, uint timestamp, uint devicenumber, uint devicetype){

	}+/
	/+public void mouseButtonEvent(uint which, uint timestamp, uint windowID, ubyte button, ubyte state, ubyte clicks, int x, int y){

		//converting the dimensions
		double xR = to!double(rasterWidth) / to!double(screenWidth) , yR = to!double(rasterHeight) / to!double(screenHeight);
		x = to!int(x * xR);
		y = to!int(y * yR);
		mouseX = x;
		mouseY = y;
		//if(button == MouseButton.LEFT){
		if(state == ButtonState.PRESSED){
			if(numOfPopUpElements < 0){
				foreach(p ; popUpElements){
				if(y >= p.position.top && y <= p.position.bottom && x >= p.position.left && x <= p.position.right){
					p.onClick(x - p.position.left, y - p.position.top);
					return;
				}
			}
			//removeAllPopUps();
			removeTopPopUp();
			} else {
				moveX = x;
				moveY = y;
				for(int i ; i < windows.length ; i++){
					if(x >= windows[i].position.left && x <= windows[i].position.right && y >= windows[i].position.top && y <= windows[i].position.bottom){
						//if(i == 0){
						dragEventState = true;
						windows[i].passMouseEvent(x - windows[i].position.left, y - windows[i].position.top, state, button);
						if(dragEventState)
							dragEventDest = windows[i];
					/*if(windows.length !=0){
						dragEventState = true;
						dragEventDest = windows[0];
					}*/
				//return;
					//}else{
						if(i != 0){
							setWindowToTop(windows[i]);

						}
						lastMouseButton = button;
						return;
					}
				}
				passMouseEvent(x,y,state,button);

			}
		}else{
			if(moveState){
				moveState = false;
			}else if(dragEventDest){
				dragEventDest.passMouseEvent(x - dragEventDest.position.left, y - dragEventDest.position.top, state, button);
				dragEventDest = null;
			}else{
				passMouseEvent(x,y,state,button);
			}
		}
	}+/
	/+public void passMouseEvent(int x, int y, int state, ubyte button){

	}
	public void passMouseDragEvent(int x, int y, int relX, int relY, ubyte button){
	}
	public void passMouseMotionEvent(int x, int y, int relX, int relY, ubyte button){
	}
	public void mouseWheelEvent(uint type, uint timestamp, uint windowID, uint which, int x, int y, int wX, int wY){
		double xR = to!double(rasterWidth) / to!double(screenWidth) , yR = to!double(rasterHeight) / to!double(screenHeight);
		wX = to!int(wX * xR);
		wY = to!int(wY * yR);
		if(windows.length != 0)
			windows[0].passScrollEvent(wX - windows[0].position.left, wY - windows[0].position.top, y, x);
		passScrollEvent(wX,wY,x,y);
	}
	public void passScrollEvent(int wX, int wY, int x, int y){

	}
	public void mouseMotionEvent(uint timestamp, uint windowID, uint which, uint state, int x, int y, int relX, int relY){
		import std.math : ceil;
		//coordinate conversion
		double xR = to!double(rasterWidth) / to!double(screenWidth) , yR = to!double(rasterHeight) / to!double(screenHeight);
		x = to!int(x * xR);
		y = to!int(y * yR);
		relX = to!int(ceil(relX * xR));
		relY = to!int(ceil(relY * yR));
		//passing mouseMovementEvent onto PopUps
		if(numOfPopUpElements < 0){
			PopUpElement p = popUpElements[popUpElements.length - 1];
			if(p.position.top < y && p.position.bottom > y && p.position.left < x && p.position.right > x){
				p.onMouseMovement(x - p.position.left, y - p.position.top);
				return;
			}else{
				p.onMouseMovement(-1,-1);
			}

		}
		if(state == ButtonState.PRESSED && moveState){
			windowToMove.relMove(relX, relY);
		}else if(state == ButtonState.PRESSED && dragEventDest){
			dragEventDest.passMouseDragEvent(x, y, relX, relY, lastMouseButton);
		}else{
			if(windows.length){
				windows[0].passMouseMotionEvent(x, y, relX, relY, lastMouseButton);
			}
		}
	}+/
	public void moveWindow(int x, int y, Window w){
		spriteLayer.relMoveSprite(whichWindow(w), x, y);

	}
	public void refreshWindow(Window w){
		int n = whichWindow(w);
		spriteLayer.replaceSprite(windows[n].output.output, n, windows[n].position);
	}
	public void relMoveWindow(int x, int y, Window w){
		spriteLayer.relMoveSprite(whichWindow(w), x, y);
	}
	public void addPopUpElement(PopUpElement p){
		popUpElements ~= p;
		p.addParent(this);
		p.draw;
		mouseX -= (p.position.width/2);
		mouseY -= (p.position.height/2);
		p.position.move(mouseX,mouseY);
		numOfPopUpElements--;
		spriteLayer.addSprite(p.output.output,numOfPopUpElements,mouseX,mouseY);

	}
	public void addPopUpElement(PopUpElement p, int x, int y){
		popUpElements ~= p;
		p.addParent(this);
		p.draw;
		p.position.move(x, y);
		numOfPopUpElements--;
		spriteLayer.addSprite(p.output.output,numOfPopUpElements, x, y);
	}
	private void removeAllPopUps(){
		for( ; numOfPopUpElements < 0 ; numOfPopUpElements++){
			spriteLayer.removeSprite(numOfPopUpElements);
		}
		popUpElements.length = 0;
	}
	private void removeTopPopUp(){

		spriteLayer.removeSprite(numOfPopUpElements++);

		popUpElements.length--;
	}
	public StyleSheet getDefaultStyleSheet(){
		return defaultStyle;
	}
	public void endPopUpSession(){
		removeAllPopUps();
	}
	public void closePopUp(PopUpElement p){

	}
	public void drawUpdate(WindowElement sender){}
	public void getFocus(WindowElement sender){}
	public void dropFocus(WindowElement sender){}
	public void drawUpdate(Window sender){
		/*int p = whichWindow(sender);
		spriteLayer.removeSprite(p);
		spriteLayer.addSprite(sender.output.output,p,sender.position);*/
	}
	/*public Coordinate getAbsolutePosition(PopUpElement sender){
		for(int i ; i < popUpElements.length ; i++){
			if(popUpElements[i] = sender){

			}
		}
		return Coordinate();
	}*/
}

/+public interface IWindowHandler : PopUpHandler {
	//public Bitmap16Bit[wchar] getFontSet(int style);
	public StyleSheet getStyleSheet();
	public void closeWindow(Window sender);
	public void moveUpdate(Window sender);
	public void setWindowToTop(Window sender);
	public void addWindow(Window w);
	public void refreshWindow(Window w);
	public void moveWindow(int x, int y, Window w);
	public void relMoveWindow(int x, int y, Window w);
	public void drawUpdate(Window sender);
	public void messageWindow(dstring title, dstring message, int width = 256);
}+/
