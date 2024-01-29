module pixelperfectengine.concrete.elements.smallbutton;

public import pixelperfectengine.concrete.elements.base;

/**
 * SmallButton is used to implement small buttons for toolbars, on window headers, etc.
 * Icons contain the frame of the buttons, etc., and are recalled from the closest 
 * available stylesheet.
 */
public class SmallButton : WindowElement, ISmallButton {
	///Defines what icons will the button use for its states.
	public string			iconPressed, iconUnpressed;
	
	/**
	 * Creates an instance of SmallButton.
	 * Params:
	 *   iconPressed = the string ID of the icon to be shown when the button is pressed.
	 *   iconUnpressed = the string ID of the icon to be shown when the button is not 
	 * pressed.
	 *   source = the source identifier passed in the event class.
	 *   position = the position where the button will be drawn. If the button will be 
	 * used as a window header button, you only need to set the size, since the final 
	 * position will be set by the window itself.
	 */
	public this(string iconPressed, string iconUnpressed, string source, Box position){
		this.position = position;

		//this.text = text;
		this.source = source;
		this.iconPressed = iconPressed;
		this.iconUnpressed = iconUnpressed;
		
		
	}
	public override void draw() {
		if (parent is null || state == ElementState.Hidden) return;
		StyleSheet ss = getStyleSheet();
		Bitmap8Bit icon = isPressed ? ss.getImage(iconPressed) : ss.getImage(iconUnpressed);
		parent.bitBLT(position.cornerUL, icon);
		Box pos = position;
		pos.bottom--;
		pos.right--;
		if (isFocused) {
			const int textPadding = ss.drawParameters["horizTextPadding"];
			parent.drawBoxPattern(pos - textPadding, ss.pattern["blackDottedLine"]);
		}

		if (state == ElementState.Disabled) {
			parent.bitBLTPattern(pos, ss.getImage("ElementDisabledPtrn"));
		}
		if (onDraw !is null) {
			onDraw();
		}
	}
	/**
	 * Returns true if the SmallButton is of size `height`, false otherwise.
	 */
	public bool isSmallButtonHeight(int height) {
		if (position.width == height && position.height == height) return true;
		else return false;
	}
	///Returns true if left side justified, false otherwise.
	public bool isLeftSide() @nogc @safe pure nothrow const {
		return flags & IS_LHS ? true : false;
	}
	///Sets the small button to the left side if true.
	public bool isLeftSide(bool val) @nogc @safe pure nothrow {
		if (val) flags |= IS_LHS;
		else flags &= ~IS_LHS;
		return flags & IS_LHS ? true : false;
	}
}
