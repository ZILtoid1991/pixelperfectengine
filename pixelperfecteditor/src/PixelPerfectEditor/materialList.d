import PixelPerfectEngine.concrete.window;

/**
 * Preliminary, future version will feature material selection with images.
 */
public class MaterialList : Window {
	ListBox listBox_materials;
	SmallButton[] buttons;
	public void delegate() onClose;
	protected static immutable dstring[] tileListHeaderS = ["ID"d, "name"d];
	protected static immutable dstring[] spriteListHeaderS = ["ID"d, "name"d, "dim"d];
	protected static immutable int[] tileListHeaderW = [32, 80];
	protected static immutable int[] spriteListHeaderW = [40, 80, 64];
	public this(int x, int y, void delegate() onClose){
		super(Coordinate(x, y, x + 98, y + 213 ), "Materials"d);
		this.onClose = onClose;
		StyleSheet ss = getStyleSheet();
		listBox_materials = new ListBox("listBox0", Coordinate(1, 17, 97, 180), [], new ListBoxHeader(tileListHeaderS.dup,
				tileListHeaderW.dup));
		addElement(listBox_materials);

		//CheckBox_Visible = new CheckBox("Visible"d, "CheckBox0", Coordinate(1, 180, 97, 196));
	}

}
/**
 * Defines a single material.
 */
public struct Material {
	dstring	id;		///Hexanumeric value of the ID
	dstring	name;	///Name of the object or tile
	dstring dim;	///Dimensions of the object, null on tiles since they share the same size on one layer
}
