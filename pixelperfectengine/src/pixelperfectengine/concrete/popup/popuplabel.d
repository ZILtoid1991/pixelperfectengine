module pixelperfectengine.concrete.popup.popuplabel;

import pixelperfectengine.concrete.popup.base;

/**
 *
 */
public class PopUpLabel : PopUpElement {
	protected int maxWidth, maxHeight;
	protected int scroll;
	public this (Text text, string source, int maxWidth = 256, int maxHeight = 256) {
		this.text = text;
		this.source = source;
		this.maxWidth = maxWidth;
		this.maxHeight = maxHeight;
	}
	public override void draw(){
		import pixelperfectengine.graphics.draw;
		
		StyleSheet ss = getStyleSheet();
		Text[] outputTextInLines = text.breakTextIntoMultipleLines(maxWidth);
		int height, finalHeight;
		foreach (line ; outputTextInLines) {
			height += line.getHeight();
		}
		finalHeight = height + 2 * ss.drawParameters["PopUpLabelVertPadding"];
		if (parent !is null) {
			const int maxScreenHeight = parent.getRasterSizes()[1];
			//Priority of height limiting: locally set height, screen height
			//If locally set height limit is greater than the screen, then the max height will be overwritten.
			if (maxScreenHeight < maxHeight)
				maxHeight = maxScreenHeight;
			if (finalHeight > maxHeight)
				finalHeight = maxHeight;
			else
				scroll = 0;
		}
		if (output is null) {
			output = new BitmapDrawer(maxWidth + 2 * ss.drawParameters["PopUpLabelHorizPadding"], 
					finalHeight);
			position = Box.bySize(0, 0, output.output.width, output.output.height);
		}
		with (output) {
			drawFilledBox(Box.bySize(0, 0, position.width, position.height), ss.getColor("window"));
			drawLine(position.cornerUL, position.cornerUR, ss.getColor("windowascent"));
			drawLine(position.cornerUL, position.cornerLL, ss.getColor("windowascent"));
			drawLine(position.cornerLL, position.cornerLR, ss.getColor("windowdescent"));
			drawLine(position.cornerUR, position.cornerLR, ss.getColor("windowdescent"));
			drawMultiLineText(Box(ss.drawParameters["PopUpLabelHorizPadding"], ss.drawParameters["PopUpLabelVertPadding"],
					position.width - ss.drawParameters["PopUpLabelHorizPadding"] - 1, 
					position.height - ss.drawParameters["PopUpLabelVertPadding"] - 1), outputTextInLines, 0 , scroll);
		}
	}
	public override void passMCE(MouseEventCommons mec, MouseClickEvent mce) {
		parent.endPopUpSession(this);
	}
	public override void passMME(MouseEventCommons mec, MouseMotionEvent mme) {
		if (!position.isBetween(mme.x, mme.y))
			parent.endPopUpSession(this);
	}
	public override void passMWE(MouseEventCommons mec, MouseWheelEvent mwe) {
		scroll += mwe.y;
		draw();
	}
}