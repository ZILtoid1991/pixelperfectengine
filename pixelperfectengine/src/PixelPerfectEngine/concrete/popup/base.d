module PixelPerfectEngine.concrete.popup.base;

public import PixelPerfectEngine.concrete.interfaces;
public import PixelPerfectEngine.concrete.types;
package import PixelPerfectEngine.graphics.draw;

/**
 * For creating pop-up elements like menus.
 */
public abstract class PopUpElement : MouseEventReceptor {
	//public ActionListener[] al;
	protected BitmapDrawer output;
	public static InputHandler inputhandler;
	//public static StyleSheet styleSheet;
	protected Box position;
	public StyleSheet customStyle;
	protected PopUpHandler parent;
	protected string source;
	protected Text text;
	/*public void delegate(Event ev) onMouseLClickRel;
	public void delegate(Event ev) onMouseRClickRel;
	public void delegate(Event ev) onMouseMClickRel;
	public void delegate(Event ev) onMouseHover;
	public void delegate(Event ev) onMouseMove;
	public void delegate(Event ev) onMouseLClickPre;
	public void delegate(Event ev) onMouseRClickPre;
	public void delegate(Event ev) onMouseMClickPre;*/

	public static void delegate() onDraw;			///Called when the element finished drawing
	public void delegate(Event ev) onMouseClick;	///Called on mouse click on element

	public abstract void draw();					///Called to draw the element
	///Mouse click events passed here
	public void onClick(int offsetX, int offsetY, int type = 0){

	}
	///Mouse scroll events passed here
	public void onScroll(int x, int y, int wX, int wY){

	}
	///Mouse movement events passed here
	public void onMouseMovement(int x, int y){

	}
	public void addParent(PopUpHandler p){
		parent = p;
	}

	protected StyleSheet getStyleSheet(){
		if(customStyle !is null){
			return customStyle;
		}
		return parent.getStyleSheet();
	}
	public Box getPosition() @nogc @safe pure nothrow const {
		return position;
	}
	public Box setPosition(Box val) @trusted {
		position = val;
		draw();
		return position;
	}
	///Moves the PopUp to the given location
	public Box move(int x, int y) @nogc @safe pure nothrow {
		position.move(x, y);
		return position;
	}
	///Relatively moves the PopUp by the given amount
	public Box relMove(int x, int y) @nogc @safe pure nothrow {
		position.relMove(x, y);
		return position;
	}
	///Returns the output of the element.
	public ABitmap getOutput() @safe{
		return output.output;
	}
	
	public void passMCE(MouseEventCommons mec, MouseClickEvent mce) {
		
	}
	
	public void passMME(MouseEventCommons mec, MouseMotionEvent mme) {
		
	}
	
	public void passMWE(MouseEventCommons mec, MouseWheelEvent mwe) {
		
	}
	
}