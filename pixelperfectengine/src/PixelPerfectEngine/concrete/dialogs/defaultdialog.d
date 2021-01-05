module PixelPerfectEngine.concrete.dialogs.defaultdialog;

public import PixelPerfectEngine.concrete.window;
import PixelPerfectEngine.concrete.elements;

/**
 * Default dialog for simple messageboxes.
 */
public class DefaultDialog : Window{
	private string source;
	public void delegate(Event ev) output;

	public this(Coordinate size, string source, Text title, Text[] message, Text[] options = [],
			string[] values = ["close"], StyleSheet customStyle = null) {
		super(size, title, null, customStyle);
		//generate text
		if(options.length == 0)
			options ~= new Text("Ok", getStyleSheet().getChrFormatting("button"));
		
		this.source = source;
		int x1, x2, y1 = 20, y2 = getStyleSheet.drawParameters["TextSpacingTop"] + getStyleSheet.drawParameters["TextSpacingBottom"]
								+ options[0].font.size;
		//Label msg = new Label(message[0], "null", Coordinate(5, 20, size.width()-5, 40));
		//addElement(msg, EventProperties.MOUSE);

		//generate buttons

		x1 = size.width() - 10;
		Button[] buttons;
		int button1 = size.height - getStyleSheet.drawParameters["WindowBottomPadding"];
		int button2 = button1 - getStyleSheet.drawParameters["ComponentHeight"];
		
		
		for(int i; i < options.length; i++) {
			x2 = x1 - (options[i].getWidth + getStyleSheet.drawParameters["ButtonPaddingHoriz"]);
			buttons ~= new Button(options[i], values[i], Coordinate(x2, button2, x1, button1));
			buttons[i].onMouseLClick = &actionEvent;
			addElement(buttons[i]);
			x1 = x2;
		}
		//add labels
		for(int i; i < message.length; i++) {
			Label msg = new Label(message[i], "null", Coordinate(getStyleSheet.drawParameters["WindowLeftPadding"],
								y1, size.width()-getStyleSheet.drawParameters["WindowRightPadding"], y1 + y2));
			addElement(msg);
			y1 += y2;
		}
	}
	///Ditto
	public this(Coordinate size, string source, dstring title, dstring[] message, dstring[] options = ["Close"],
			string[] values = ["close"], StyleSheet customStyle = null) {
		this.customStyle = customStyle;
		Text[] opt_2;
		opt_2.reserve(options.length);
		foreach (dstring key; options) 
			opt_2 ~= new Text(key, getStyleSheet().getChrFormatting("button"));
		
		Text[] msg_2;
		msg_2.reserve(message.length);
		foreach (dstring key; message)
			msg_2 ~= new Text(key, getStyleSheet().getChrFormatting("label"));
		this(size, source, new Text(title, getStyleSheet().getChrFormatting("windowHeader")),msg_2,opt_2,values,customStyle);
	}
	public void actionEvent(Event ev){
		WindowElement we = cast(WindowElement)ev.sender;
		if(we.getSource == "close") {
			close();
		} else {
			output(ev);
		}
	}
}