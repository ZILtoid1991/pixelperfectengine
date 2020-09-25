module windows.materiallist;

import PixelPerfectEngine.concrete.window;
import PixelPerfectEngine.map.mapformat;

import app;

import std.utf : toUTF32;
import PixelPerfectEngine.system.etc : intToHex;

/**
 * Preliminary, future version will feature material selection with images.
 */
public class MaterialList : Window {
	ListBox			listBox_materials;
	Label			palettePos;
	//SmallButton[]	buttons;
	public void delegate() onClose;
	protected TileInfo[] tiles;
	protected static immutable dstring[] tileListHeaderS = ["ID"d, "Name"d];
	protected static immutable dstring[] spriteListHeaderS = ["ID"d, "Name"d, "Dim"d];
	protected static immutable int[] tileListHeaderW = [32, 120];
	protected static immutable int[] spriteListHeaderW = [40, 120, 64];
	public this(int x, int y, void delegate() onClose) @trusted {
		super(Coordinate(x, y, x + 130, y + 251 ), "Materials"d);
		this.onClose = onClose;
		StyleSheet ss = getStyleSheet();
		listBox_materials = new ListBox("listBox0", Coordinate(1, 17, 129, 218), [], new ListBoxHeader(tileListHeaderS.dup,
				tileListHeaderW.dup));
		listBox_materials.onItemSelect = &onItemSelect;
		addElement(listBox_materials);
		{
			SmallButton sb = new SmallButton("removeMaterialB", "removeMaterialA", "rem", Coordinate(113, 234, 129, 250));
			//sb.onMouseLClickRel = &button_trash_onClick;
			addElement(sb);
		}
		{
			SmallButton sb = new SmallButton("addMaterialB", "addMaterialA", "add", Coordinate(113, 218, 129, 234));
			sb.onMouseLClickRel = &button_addMaterial_onClick;
			addElement(sb);
		}
		{
			CheckBox sb = new CheckBox("horizMirrorB", "horizMirrorA", "horizMirror", Coordinate(1, 218, 17, 234));
			sb.onToggle = &horizMirror_onClick;
			addElement(sb);
		}
		{
			CheckBox sb = new CheckBox("vertMirrorB", "vertMirrorA", "vertMirror", Coordinate(17, 218, 33, 234));
			sb.onToggle = &vertMirror_onClick;
			addElement(sb);
		}
		{
			CheckBox sb = new CheckBox("ovrwrtInsB", "ovrwrtInsA", "ovrwrtIns", Coordinate(33, 218, 49, 234));
			sb.onToggle = &ovrwrtIns_onClick;
			addElement(sb);
		}
		{
			SmallButton sb = new SmallButton("paletteUpB", "paletteUpA", "palUp", Coordinate(1, 234, 17, 250));
			sb.onMouseLClickRel = &palUp_onClick;
			addElement(sb);
		}
		{
			SmallButton sb = new SmallButton("paletteDownB", "paletteDownA", "palDown", Coordinate(17, 234, 33, 250));
			sb.onMouseLClickRel = &palDown_onClick;
			addElement(sb);
		}
		{
			SmallButton sb = new SmallButton("settingsButtonB", "settingsButtonA", "editMat", Coordinate(97, 234, 113, 250));
			//sb.onMouseLClickRel = &button_trash_onClick;
			addElement(sb);
		}
		palettePos = new Label("0x00", "palettePos", Coordinate(34, 234, 96, 250));
		addElement(palettePos);
	}
	public void updateMaterialList(TileInfo[] list) @trusted {
		import PixelPerfectEngine.system.etc : intToHex;
		tiles = list;
		ListBoxItem[] output;
		foreach (item ; list) {
			output ~= new ListBoxItem ([intToHex!dstring(item.id, 4) ~ "h", toUTF32(item.name)]);
		}
		listBox_materials.updateColumns(output, new ListBoxHeader(tileListHeaderS.dup, tileListHeaderW.dup));
	}
	private void vertMirror_onClick(Event ev) {
		CheckBox sender = cast(CheckBox)ev.sender;
		if(sender.value) {
			prg.selDoc.tileMaterial_FlipVertical(true);
		} else {
			prg.selDoc.tileMaterial_FlipVertical(false);
		}
	}
	private void horizMirror_onClick(Event ev) {
		CheckBox sender = cast(CheckBox)ev.sender;
		if(sender.value) {
			prg.selDoc.tileMaterial_FlipHorizontal(true);
		} else {
			prg.selDoc.tileMaterial_FlipHorizontal(false);
		}
	}
	private void button_addMaterial_onClick(Event ev) {
		prg.initAddMaterials;
	}
	private void palUp_onClick(Event ev) {
		palettePos.setText("0x" ~ intToHex!dstring(prg.selDoc.tileMaterial_PaletteUp, 2));
	}
	private void palDown_onClick(Event ev) {
		palettePos.setText("0x" ~ intToHex!dstring(prg.selDoc.tileMaterial_PaletteDown, 2));
	}
	private void ovrwrtIns_onClick(Event ev) {
		CheckBox sender = cast(CheckBox)ev.sender;
		prg.selDoc.voidfill = sender.value;
	}
	private void onItemSelect(Event ev) {
		prg.selDoc.tileMaterial_Select(tiles[ev.value].id);
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
