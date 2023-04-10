module pixelperfectengine.concrete.dialogs.textinputdialog;

public import pixelperfectengine.concrete.window;
import pixelperfectengine.concrete.elements;

/**
 * Standard text input form for various applications.
 */
public class TextInputDialog : Window {
	//public ActionListener[] al;
	private TextBox textInput;
	private string source;
	public void delegate(Text text) textOutput;
	/**
	 * Creates a TextInputDialog. Auto-sizing version is not implemented yet.
	 */
	public this(Box size, void delegate(Text text) textOutput, string source, Text title, Text message, Text text = null, 
            Text okBtnText = null, StyleSheet customStyle = null) {
		super(size, title, null, customStyle);
        this.textOutput = textOutput;
		Label msg = new Label(message, "null", Box(8, 20, size.width()-8, 39));
		addElement(msg);

		textInput = new TextBox(text, "textInput", Coordinate(8, 40, size.width()-8, 59));
		addElement(textInput);
		if(okBtnText is null) okBtnText = new Text("Close", getStyleSheet().getChrFormatting("defaultCJ"));

		Button ok = new Button(okBtnText, "ok", Coordinate(size.width()-48, 65, size.width()-8, 84));
		ok.onMouseLClick = &button_onClick;
		addElement(ok);
		this.source = source;
	}
	///Ditto
	public this(Box size, void delegate(Text text) textOutput,string source, dstring title, dstring message, 
            dstring text = "", dstring okBtnText = "", StyleSheet customStyle = null) {
		this.customStyle = customStyle;
		this(size, textOutput, source, new Text(title, getStyleSheet().getChrFormatting("windowHeader")), 
				new Text(message, getStyleSheet().getChrFormatting("windowHeader")), 
				text.length ? new Text(text, getStyleSheet().getChrFormatting("label")) : null,
				okBtnText.length ? new Text(okBtnText, getStyleSheet().getChrFormatting("button")) : null,
				customStyle);
	}
	///Called when the "ok" button is pressed
	protected void button_onClick(Event ev) {
		if(textOutput !is null){
			textOutput(textInput.getText);
		}

		close();

	}
}