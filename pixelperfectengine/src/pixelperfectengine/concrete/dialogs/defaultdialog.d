module pixelperfectengine.concrete.dialogs.defaultdialog;

public import pixelperfectengine.concrete.window;
import pixelperfectengine.concrete.elements;

/**
 * Default dialog for simple messageboxes.
 */
public class DefaultDialog : Window{
	private string source;
	public void delegate(Event ev) output;

	public this(Point pos, const int width, string source, Text title, Text message, Text[] options = [],
			string[] values = ["close"], StyleSheet customStyle = null) {
		const int textHeight = message.getTotalHeight(width);
		if (!customStyle) customStyle = globalDefaultStyle;
		super(Box.bySize(pos.x, pos.y, width + customStyle.drawParameters["defDialogPadding"], 
				textHeight + customStyle.drawParameters["WindowTopPadding"] + customStyle.drawParameters["WindowBottomPadding"] +
				customStyle.drawParameters["ComponentHeight"]), 
				title, null, customStyle);
		//generate text
		if(options.length == 0)
			options ~= new Text("Ok", getStyleSheet().getChrFormatting("button"));
		
		this.source = source;
		int x1, x2;
		
		x1 = position.width() - 10;
		Button[] buttons;
		const int button1 = position.height - getStyleSheet.drawParameters["WindowBottomPadding"];
		const int button2 = button1 - getStyleSheet.drawParameters["ComponentHeight"];
		
		
		for(int i; i < options.length; i++) {
			x2 = x1 - (options[i].getWidth + getStyleSheet.drawParameters["ButtonPaddingHoriz"]);
			buttons ~= new Button(options[i], values[i], Box(x2, button2, x1, button1));
			buttons[i].onMouseLClick = &actionEvent;
			addElement(buttons[i]);
			x1 = x2 - 1;
		}
		//add label
		Label msg = new Label(message, "", Box.bySize(customStyle.drawParameters["WindowLeftPadding"], 
				customStyle.drawParameters["WindowTopPadding"], width, textHeight));
		addElement(msg);
		/* for(int i; i < message.length; i++) {
			Label msg = new Label(message[i], "null", Box(getStyleSheet.drawParameters["WindowLeftPadding"],
								y1, size.width()-getStyleSheet.drawParameters["WindowRightPadding"], y1 + y2));
			
			y1 += y2;
		} */
		
	}
	///Ditto
	public this(Point pos, const int width, string source, dstring title, dstring message, dstring[] options = ["Close"],
			string[] values = ["close"], StyleSheet customStyle = null) {
		this.customStyle = customStyle;
		Text[] opt_2;
		opt_2.reserve(options.length);
		foreach (dstring key; options) 
			opt_2 ~= new Text(key, getStyleSheet().getChrFormatting("button"));
		
		this(pos, width, source, new Text(title, getStyleSheet().getChrFormatting("windowHeader")),new Text(message, 
				getStyleSheet().getChrFormatting("label")),opt_2,values,customStyle);
	}
	public void actionEvent(Event ev){
		WindowElement we = cast(WindowElement)ev.sender;
		if(we.getSource == "close") {
			close();
		} else {
			ev.aux = this;
			output(ev);
		}
	}
}