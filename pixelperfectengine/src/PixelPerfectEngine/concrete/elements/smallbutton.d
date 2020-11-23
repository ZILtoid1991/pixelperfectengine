module PixelPerfectEngine.concrete.elements.smallbutton;

public import PixelPerfectEngine.concrete.elements.base;

public class SmallButton : WindowElement {
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
		if (isFocused) {
			const int textPadding = ss.drawParameters["horizTextPadding"];
			parent.drawBoxPattern(position - textPadding, ss.pattern["blackDottedLine"]);
		}

		if (state == ElementState.Disabled) {
			parent.bitBLTPattern(position, ss.getImage("ElementDisabledPtrn"));
		}
	}
}
