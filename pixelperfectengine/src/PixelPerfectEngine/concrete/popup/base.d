module PixelPerfectEngine.concrete.popup.base;

public import PixelPerfectEngine.concrete.interfaces;
public import PixelPerfectEngine.concrete.types;
import PixelPerfectEngine.graphics.draw;

/**
 * For creating pop-up elements like menus.
 */
public abstract class PopUpElement : MouseEventReceptor {
	//public ActionListener[] al;
	protected BitmapDrawer output;
	public static InputHandler inputhandler;
	//public static StyleSheet styleSheet;
	public Coordinate position;
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
		if(styleSheet !is null){
			return styleSheet;
		}
		return parent.getStyleSheet();
	}
	///Returns the output of the element.
	///This method is preferred over directly accessing output.output, which won't be available in later versions.
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