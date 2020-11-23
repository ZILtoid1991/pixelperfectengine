module PixelPerfectEngine.concrete.elements.label;

public import PixelPerfectEngine.concrete.elements.base;

public class Label : WindowElement {
	public this(dstring text, string source, Coordinate coordinates) {
		this(new Text(text, getAvailableStyleSheet().getChrFormatting("label")), source, coordinates);
	}
	public this(Text text, string source, Coordinate coordinates) {
		position = coordinates;
		this.text = text;
		this.source = source;
		output = new BitmapDrawer(coordinates.width, coordinates.height);
		//draw();
	}
	public override void draw() {
		StyleSheet ss = getStyleSheet();
		parent.drawFilledBox(position, ss.getColor("window"));
		parent.drawTextSL(position, text, Point(0,0));
		if (isFocused) {
			const int textPadding = ss.drawParameters["horizTextPadding"];
			parent.drawBoxPattern(position - textPadding, ss.pattern["blackDottedLine"]);
		}

		if (state == ElementState.Disabled) {
			parent.bitBLTPattern(position, ss.getImage("ElementDisabledPtrn"));
		}
	}
	
}
