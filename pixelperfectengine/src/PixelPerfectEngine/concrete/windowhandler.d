module PixelPerfectEngine.concrete.windowhandler;

public import PixelPerfectEngine.concrete.interfaces;
public import PixelPerfectEngine.concrete.window;
public import PixelPerfectEngine.concrete.types;
public import PixelPerfectEngine.concrete.popup;
public import PixelPerfectEngine.concrete.dialogs;

public import PixelPerfectEngine.system.input.interfaces;

public import PixelPerfectEngine.graphics.layers : ISpriteLayer;

import collections.linkedlist;
import PixelPerfectEngine.system.etc : cmpObjPtr;

import bindbc.sdl.bind.sdlmouse;

/**
 * Handles windows as well as PopUpElements.
 */
public class WindowHandler : InputListener, MouseListener, PopUpHandler {
	alias WindowSet = LinkedList!(Window, false, "a is b");
	alias PopUpSet = LinkedList!(PopUpElement, false, "a is b");
	protected WindowSet windows;
	protected PopUpSet popUpElements;
	private int numOfPopUpElements;
	//private int[] priorities;
	protected int screenWidth, screenHeight, rasterWidth, rasterHeight, moveX, moveY, mouseX, mouseY;
	protected double mouseConvX, mouseConvY;
	//public Bitmap16Bit[wchar] basicFont, altFont, alarmFont;
	///Sets the default style for the windowhandler.
	///If null, the global default will be used instead.
	public StyleSheet defaultStyle;
	//public Bitmap16Bit[int] styleBrush;
	protected ABitmap background;
	///A window that is used for top-level stuff, like elements in the background, or an integrated window.
	protected Window baseWindow;
	///The type of the current cursor
	protected CursorType cursor;
	///SDL cursor pointer to operate it
	protected SDL_Cursor* sdlCursor;
	private ISpriteLayer spriteLayer;
	//private Window windowToMove;
	protected MouseEventReceptor dragEventSrc;
	private PopUpElement dragEventDestPopUp;
	//private ubyte lastMouseButton;
	/**
	 * Default CTOR.
	 * sW and sH set the screen width and height.
	 * rW and rH set the raster width and height.
	 * ISpriteLayer sets the SpriteLayer, that will display the windows and popups as sprites.
	 */
	public this(int sW, int sH, int rW, int rH, ISpriteLayer sl) {
		screenWidth = sW;
		screenHeight = sH;
		rasterWidth = rW;
		rasterHeight = rH;
		spriteLayer = sl;
		mouseConvX = cast(double)screenWidth / rasterWidth;
		mouseConvY = cast(double)screenHeight / rasterHeight;
	}
	/**
	 * Sets the cursor to the given type.
	 */
	public CursorType setCursor(CursorType type) {
		cursor = type;
		sdlCursor = SDL_CreateSystemCursor(cast(SDL_SystemCursor)cursor);
		SDL_SetCursor(sdlCursor);
		return cursor;
	}
	/**
	 * Returns the current cursor type.
	 */
	public CursorType getCursor() @nogc @safe pure nothrow {
		return cursor;
	}
	/**
	 * Adds a window to the handler.
	 */
	public void addWindow(Window w) @trusted {
		windows.put(w);
		w.addHandler(this);
		w.draw();
		setWindowToTop(w);
	}

	/**
	 * Adds a DefaultDialog as a message box
	 */
	public void message(dstring title, dstring message, int width = 256) {
		import PixelPerfectEngine.concrete.dialogs.defaultdialog;
		StyleSheet ss = getStyleSheet();
		dstring[] formattedMessage = ss.getChrFormatting("label").font.breakTextIntoMultipleLines(message, width -
				ss.drawParameters["WindowLeftPadding"] - ss.drawParameters["WindowRightPadding"]);
		int height = cast(int)(formattedMessage.length * (ss.getChrFormatting("label").font.size +
				ss.drawParameters["TextSpacingTop"] + ss.drawParameters["TextSpacingBottom"]));
		height += ss.drawParameters["WindowTopPadding"] + ss.drawParameters["WindowBottomPadding"] +
				ss.drawParameters["ComponentHeight"];
		Coordinate c = Coordinate(mouseX - width / 2, mouseY - height / 2, mouseX + width / 2, mouseY + height / 2);
		//Text title0 = new Text(title, ss.getChrFormatting("windowHeader"));
		addWindow(new DefaultDialog(c, null, title, formattedMessage));
	}
	/**
	 * Adds a background.
	 */
	public void addBackground(ABitmap b) {
		background = b;
		spriteLayer.addSprite(background, 65_536, 0, 0);
	}
	/**
	 * Returns the window priority or -1 if the window can't be found.
	 */
	private int whichWindow(Window w) @safe pure nothrow {
		try
			return cast(int)windows.which(w);
		catch (Exception e)
			return -1;
	}
	/**
	 * Sets sender to be top priority.
	 */
	public void setWindowToTop(Window w) {
		windows[0].focusTaken();
		sizediff_t pri = whichWindow(w);
		windows.setAsFirst(pri);
		updateSpriteOrder();
		windows[0].focusGiven();
	}
	/**
	 * Updates the sprite order by removing everything, then putting them back again.
	 */
	protected void updateSpriteOrder() {
		spriteLayer.clear();
		for (int i ; i < windows.length ; i++)
			spriteLayer.addSprite(windows[i].getOutput, i, windows[i].getPosition);
		if (background) spriteLayer.addSprite(background, 65_536, 0, 0);
		if (baseWindow) spriteLayer.addSprite(baseWindow.getOutput, 65_535, 0, 0);
	}
	/**
	 * Returns the default stylesheet.
	 */
	public StyleSheet getStyleSheet() {
		if (defaultStyle)
			return defaultStyle;
		else
			return globalDefaultStyle;
	}
	/**
	 * Closes the given window.
	 *
	 * NOTE: The closed window should be dereferenced in other places in order to be deallocated by the GC. If not,
	 * then it can be used to restore the window without creating a new one, potentially saving it's states.
	 */
	public void closeWindow(Window sender) {
		const int p = whichWindow(sender);
		windows.remove(p);

		updateSpriteOrder();
	}
	
	/**
	 * Initializes drag event.
	 * Used to avoid issues from stray mouse release, etc.
	 */
	public void initDragEvent(MouseEventReceptor dragEventSrc) @safe nothrow {
		this.dragEventSrc = dragEventSrc;
	}
	/**
	 * Updates the sender's coordinates.
	 */
	public void updateWindowCoord(Window sender) @safe nothrow {
		const int n = whichWindow(sender);
		spriteLayer.replaceSprite(sender.getOutput(), n, sender.getPosition());
	}
	//implementation of the MouseListener interface starts here
	/**
	 * Called on mouse click events.
	 */
	public void mouseClickEvent(MouseEventCommons mec, MouseClickEvent mce) {
		mce.x = cast(int)(mce.x / mouseConvX);
		mce.y = cast(int)(mce.y / mouseConvY);
		if (!mce.state && dragEventSrc) {
			dragEventSrc.passMCE(mec, mce);
			dragEventSrc = null;
		}
		if (numOfPopUpElements < 0) {
			foreach (PopUpElement pe ; popUpElements) {
				if (pe.getPosition().isBetween(mce.x, mce. y)) {
					pe.passMCE(mec, mce);
					return;
				}
			}
			if (mce.state) {
				removeAllPopUps();
				return;
			}
		} else if (mce.state) {
			foreach (Window w ; windows) {
				const Box pos = w.getPosition();
				if (pos.isBetween(mce.x, mce.y)) {
					if (!w.active && mce.state) { //If window is not active, then the window order must be reset
						//windows[0].focusTaken();
						setWindowToTop(w);
					}
					w.passMCE(mec, mce);
					dragEventSrc = w;
					return;
				}
			}
		}
		if (baseWindow) baseWindow.passMCE(mec, mce);
	}
	/**
	 * Called on mouse wheel events.
	 */
	public void mouseWheelEvent(MouseEventCommons mec, MouseWheelEvent mwe) {
		if (numOfPopUpElements < 0) popUpElements[$ - 1].passMWE(mec, mwe);
		else if (windows.length) windows[0].passMWE(mec, mwe);
		else if (baseWindow) baseWindow.passMWE(mec, mwe);
	}
	/**
	 * Called on mouse motion events.
	 */
	public void mouseMotionEvent(MouseEventCommons mec, MouseMotionEvent mme) {
		mme.relX = cast(int)(mme.relX / mouseConvX);
		mme.relY = cast(int)(mme.relY / mouseConvY);
		mme.x = cast(int)(mme.x / mouseConvX);
		mme.y = cast(int)(mme.y / mouseConvY);
		mouseX = mme.x;
		mouseY = mme.y;
		if (dragEventSrc) {
			dragEventSrc.passMME(mec, mme);
			return;
		}
		if (numOfPopUpElements < 0) {
			popUpElements[$ - 1].passMME(mec, mme);
			return;
		}
		foreach (Window key; windows) {
			if (key.getPosition.isBetween(mme.x, mme.y)) {
				key.passMME(mec, mme);
				return;
			}
		}
		if (baseWindow) baseWindow.passMME(mec, mme);
	}
	/**
	 * Sets the BaseWindow to the given object.
	 *
	 * The base window has no priority and will reside forever in the background. Can be used for various ends.
	 */
	public Window setBaseWindow(Window w) @safe nothrow {
		import PixelPerfectEngine.graphics.layers.base : RenderingMode;
		w.addHandler(this);
		baseWindow = w;
		spriteLayer.addSprite(w.getOutput, 65_535, w.getPosition);
		spriteLayer.setSpriteRenderingMode(65_535, RenderingMode.Blitter);
		return baseWindow;
	}
	
	
	/**
	 * Replaces the window's old sprite in the spritelayer's display list with the new one.
	 *
	 * Needed to be called each time the window's sprite is being replaced, or else the previous one will be continued to
	 * be displayed without any updates.
	 */
	public void refreshWindow(Window sender) @safe {
		const int n = whichWindow(sender);
		spriteLayer.replaceSprite(windows[n].getOutput, n, windows[n].getPosition);
	}
	/**
	 * Adds a popup element and moves it to the current cursor position.
	 */
	public void addPopUpElement(PopUpElement p){
		popUpElements.put(p);
		p.addParent(this);
		p.draw;
		/+mouseX -= (p.getPosition.width/2);
		mouseY -= (p.getPosition.height/2);+/
		p.move(mouseX - p.getPosition.width/2, mouseY - p.getPosition.height/2);
		numOfPopUpElements--;
		spriteLayer.addSprite(p.getOutput,numOfPopUpElements,mouseX,mouseY);

	}
	public void addPopUpElement(PopUpElement p, int x, int y){
		popUpElements.put(p);
		p.addParent(this);
		p.draw;
		p.move(x, y);
		numOfPopUpElements--;
		spriteLayer.addSprite(p.getOutput,numOfPopUpElements, x, y);
	}
	private void removeAllPopUps(){
		for ( ; numOfPopUpElements < 0 ; numOfPopUpElements++){
			spriteLayer.removeSprite(numOfPopUpElements);
		}
		/+foreach (key ; popUpElements) {
			key.destroy;
		}+/
		///Why didn't I add a method to clear linked lists? (slams head into wall)
		popUpElements = PopUpSet(new PopUpElement[](0));
		/+while (popUpElements.length) {
			popUpElements.remove(0);
		}+/
	}
	private void removeTopPopUp(){

		spriteLayer.removeSprite(numOfPopUpElements++);

		popUpElements.remove(popUpElements.length - 1);
	}
	public StyleSheet getDefaultStyleSheet(){
		return defaultStyle;
	}
	public void endPopUpSession(PopUpElement p){
		removeAllPopUps();
	}
	public void closePopUp(PopUpElement p){
		popUpElements.removeByElem(p);
	}
	
	
	/*public Coordinate getAbsolutePosition(PopUpElement sender){
		for(int i ; i < popUpElements.length ; i++){
			if(popUpElements[i] = sender){

			}
		}
		return Coordinate();
	}*/
	//implementation of the `InputListener` interface
	/**
	 * Called when a keybinding event is generated.
	 * The `id` should be generated from a string, usually the name of the binding.
	 * `code` is a duplicate of the code used for fast lookup of the binding, which also contains other info (deviceID, etc).
	 * `timestamp` is the time lapsed since the start of the program, can be used to measure time between keypresses.
	 * NOTE: Hat events on joysticks don't generate keyReleased events, instead they generate keyPressed events on release.
	 */
	public void keyEvent(uint id, BindingCode code, uint timestamp, bool isPressed) {
		if (isPressed) {

		}
	}
	/**
	 * Called when an axis is being operated.
	 * The `id` should be generated from a string, usually the name of the binding.
	 * `code` is a duplicate of the code used for fast lookup of the binding, which also contains other info (deviceID, etc).
	 * `timestamp` is the time lapsed since the start of the program, can be used to measure time between keypresses.
	 * `value` is the current position of the axis normalized between -1.0 and +1.0 for joysticks, and 0.0 and +1.0 for analog
	 * triggers.
	 */
	public void axisEvent(uint id, BindingCode code, uint timestamp, float value) {

	}
}


