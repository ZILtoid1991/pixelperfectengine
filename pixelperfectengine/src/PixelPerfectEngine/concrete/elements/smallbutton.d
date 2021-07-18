module PixelPerfectEngine.concrete.elements.smallbutton;

public import PixelPerfectEngine.concrete.elements.base;

public class SmallButton : WindowElement, ISmallButton {
	public string			iconPressed, iconUnpressed;
	private bool			_isPressed;
	//protected IRadioButtonGroup		radioButtonGroup;	//If set, the element works like a radio button

	//public int brushPressed, brushNormal;

	public this(string iconPressed, string iconUnpressed, string source, Box position){
		this.position = position;

		//this.text = text;
		this.source = source;
		this.iconPressed = iconPressed;
		this.iconUnpressed = iconUnpressed;
		
		
	}
	public override void draw(){
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
