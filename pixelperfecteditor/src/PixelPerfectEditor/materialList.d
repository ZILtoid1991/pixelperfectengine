import PixelPerfectEngine.concrete.window;

/**
 * Preliminary, future version will feature direct material selection.
 */
public class MaterialList : Window {
	ListBox listBox_layers;
	SmallButton[] buttons;
	public void delegate() onClose;
	public this(int x, int y, void delegate() onClose){
		super(Coordinate(x, y, x + 98, y + 213 ), "Materials"d);
		this.onClose = onClose;
		StyleSheet ss = getStyleSheet();
		listBox_layers = new ListBox("listBox0", Coordinate(1, 17, 97, 180), [], new ListBoxHeader(["code"d, "name"d], [32, 80]));
		addElement(listBox_layers);

		//CheckBox_Visible = new CheckBox("Visible"d, "CheckBox0", Coordinate(1, 180, 97, 196));
	}

}
