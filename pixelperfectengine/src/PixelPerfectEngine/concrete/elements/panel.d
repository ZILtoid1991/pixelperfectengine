module PixelPerfectEngine.concrete.elements.panel;

/**
 * Panel for grouping elements.
 * Does not directly handle elements, instead relies on blitter transparency. However, can handle
 * the state of the elements.
 */
public class Panel : WindowElement {
	///This element can optionally handle the state of others put onto it.
	///Make sure this panel has higher priority than the others.
	public WindowElement[] connectedElems;
	/**
	 * Default CTOR
	 */
	public this(Text text, string source, Coordinate coordinates) {
		position = coordinates;
		this.text = text;
		this.source = source;
		output = new BitmapDrawer(coordinates.width, coordinates.height);
	}
	///Ditto
	public this(dstring text, string source, Coordinate position) {
		this(new Text(text, getAvailableStyleSheet().getChrFormatting("panel")), source, position);
	}
	public override void draw() {
		StyleSheet ss = getAvailableStyleSheet();
		//Draw the title
		output.drawSingleLineText(Coordinate(ss.drawParameters["PanelTitleFirstCharOffset"], 0,
				position.width, text.font.size), text);
		//Draw the borders
		output.drawLine(ss.drawParameters["PanelPadding"], ss.drawParameters["PanelPadding"] + 
				ss.drawParameters["PanelTitleFirstCharOffset"], ss.drawParameters["PanelPadding"], 
				ss.drawParameters["PanelPadding"], ss.getColor("PanelBorder"));
		output.drawLine(ss.drawParameters["PanelPadding"] + ss.drawParameters["PanelTitleFirstCharOffset"], 
				position.width - ss.drawParameters["PanelPadding"], ss.drawParameters["PanelPadding"],
				ss.drawParameters["PanelPadding"], ss.getColor("PanelBorder"));
		output.drawLine(ss.drawParameters["PanelPadding"], position.width - ss.drawParameters["PanelPadding"], 
				position.height - ss.drawParameters["PanelPadding"], position.height - ss.drawParameters["PanelPadding"], 
				ss.getColor("PanelBorder"));
		output.drawLine(ss.drawParameters["PanelPadding"], ss.drawParameters["PanelPadding"], 
				ss.drawParameters["PanelPadding"], position.height - ss.drawParameters["PanelPadding"], 
				ss.getColor("PanelBorder"));
		output.drawLine(position.width - ss.drawParameters["PanelPadding"], position.width - ss.drawParameters["PanelPadding"], 
				ss.drawParameters["PanelPadding"], position.height - ss.drawParameters["PanelPadding"], 
				ss.getColor("PanelBorder"));
		if(_state != ElementState.Enabled) {

		}
	}
}
