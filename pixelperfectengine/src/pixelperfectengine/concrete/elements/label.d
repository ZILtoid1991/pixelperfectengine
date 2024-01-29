module pixelperfectengine.concrete.elements.label;

public import pixelperfectengine.concrete.elements.base;

/**
 * A simple label used on GUI elements to annotate things.
 */
public class Label : WindowElement {
	public this(dstring text, string source, Box position) {
		this(new Text(text, getStyleSheet().getChrFormatting("label")), source, position);
	}
	public this(Text text, string source, Box position) {
		this.position = position;
		this.text = text;
		this.source = source;
	}
	public override void draw() {
		if (parent is null || state == ElementState.Hidden) return;
		StyleSheet ss = getStyleSheet();
		parent.drawFilledBox(position, ss.getColor("window"));
		//parent.drawTextSL(position, text, Point(0,0));
		parent.drawTextML(position, text, Point(0,0));
		if (isFocused) {
			const int textPadding = ss.drawParameters["horizTextPadding"];
			parent.drawBoxPattern(position - textPadding, ss.pattern["blackDottedLine"]);
		}

		if (state == ElementState.Disabled) {
			parent.bitBLTPattern(position, ss.getImage("ElementDisabledPtrn"));
		}
		if (onDraw !is null) {
			onDraw();
		}
	}
}
