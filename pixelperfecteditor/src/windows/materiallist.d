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
	//ListBox			listBox_materials;
	ListView		listView_materials;
	Label			palettePos;
	//SmallButton[]	buttons;
	
	protected TileInfo[] tiles;
	/+protected Text[] tileListHeaderS;// = ["ID"d, "Name"d];
	protected Text[] spriteListHeaderS;// = ["ID"d, "Name"d, "Dim"d];
	protected int[] tileListHeaderW = [32, 120];
	protected int[] spriteListHeaderW = [40, 120, 64];+/
	protected ListViewHeader tileListHeader;
	protected ListViewHeader spriteListHeader;
	public this(int x, int y, void delegate() onClose) @trusted {
		super(Coordinate(x, y, x + 129, y + 249), "Materials"d);
		this.onClose = onClose;
		StyleSheet ss = getStyleSheet();
		/+listBox_materials = new ListBox("listBox0", Coordinate(1, 17, 129, 218), [], new ListBoxHeader(tileListHeaderS.dup,
				tileListHeaderW.dup));+/
		tileListHeader = new ListViewHeader(16, [32, 120], ["ID"d, "Name"d]);
		spriteListHeader = new ListViewHeader(16, [40, 120, 64], ["ID"d, "Name"d, "Dim"d]);
		listView_materials = new ListView(tileListHeader, null, "listView_materials", Box(1, 17, 128, 215));
		listView_materials.onItemSelect = &onItemSelect;
		addElement(listView_materials);
		{
			SmallButton sb = new SmallButton("removeMaterialB", "removeMaterialA", "rem", Box(113, 233, 129, 248));
			sb.onMouseLClick = &button_trash_onClick;
			addElement(sb);
		}
		{
			SmallButton sb = new SmallButton("addMaterialB", "addMaterialA", "add", Box(113, 217, 129, 232));
			sb.onMouseLClick = &button_addMaterial_onClick;
			addElement(sb);
		}
		{
			CheckBox sb = new CheckBox("horizMirrorB", "horizMirrorA", "horizMirror", Box(1, 217, 16, 232));
			sb.onToggle = &horizMirror_onClick;
			addElement(sb);
		}
		{
			CheckBox sb = new CheckBox("vertMirrorB", "vertMirrorA", "vertMirror", Box(17, 217, 32, 232));
			sb.onToggle = &vertMirror_onClick;
			addElement(sb);
		}
		{
			CheckBox sb = new CheckBox("ovrwrtInsB", "ovrwrtInsA", "ovrwrtIns", Box(33, 217, 48, 232));
			sb.onToggle = &ovrwrtIns_onClick;
			addElement(sb);
		}
		{
			SmallButton sb = new SmallButton("paletteUpB", "paletteUpA", "palUp", Box(1, 233, 16, 248));
			sb.onMouseLClick = &palUp_onClick;
			addElement(sb);
		}
		{
			SmallButton sb = new SmallButton("paletteDownB", "paletteDownA", "palDown", Box(17, 233, 32, 248));
			sb.onMouseLClick = &palDown_onClick;
			addElement(sb);
		}
		{
			SmallButton sb = new SmallButton("settingsButtonB", "settingsButtonA", "editMat", Box(97, 233, 112, 248));
			sb.onMouseLClick = &button_editMat_onClick;
			addElement(sb);
		}
		palettePos = new Label("0x00", "palettePos", Box(34, 234, 96, 248));
		addElement(palettePos);
	}
	public void updateMaterialList(TileInfo[] list) @trusted {
		import PixelPerfectEngine.system.etc : intToHex;
		tiles = list;
		/+ListViewItem[] output;
		output.reserve = list.length;+/
		listView_materials.clear;
		foreach (item ; list) {
			listView_materials ~= new ListViewItem(16, [intToHex!dstring(item.id, 4) ~ "h", toUTF32(item.name)]);
		}
		listView_materials.refresh;
		/+listBox_materials.updateColumns(output, new ListBoxHeader(tileListHeaderS.dup, tileListHeaderW.dup));+/
	}
	private void vertMirror_onClick(Event ev) {
		CheckBox sender = cast(CheckBox)ev.sender;
		if (prg.selDoc) {
			if(sender.isChecked) {
				prg.selDoc.tileMaterial_FlipVertical(true);
			} else {
				prg.selDoc.tileMaterial_FlipVertical(false);
			}
		}
	}
	private void horizMirror_onClick(Event ev) {
		CheckBox sender = cast(CheckBox)ev.sender;
		if (prg.selDoc) {
			if(sender.isChecked) {
				prg.selDoc.tileMaterial_FlipHorizontal(true);
			} else {
				prg.selDoc.tileMaterial_FlipHorizontal(false);
			}
		}
	}
	private void button_addMaterial_onClick(Event ev) {
		prg.initAddMaterials;
	}
	private void button_editMat_onClick(Event ev) {

	}
	private void button_trash_onClick(Event ev) {
		
	}
	private void palUp_onClick(Event ev) {
		palettePos.setText("0x" ~ intToHex!dstring(prg.selDoc.tileMaterial_PaletteUp, 2));
	}
	private void palDown_onClick(Event ev) {
		palettePos.setText("0x" ~ intToHex!dstring(prg.selDoc.tileMaterial_PaletteDown, 2));
	}

	private void ovrwrtIns_onClick(Event ev) {
		CheckBox sender = cast(CheckBox)ev.sender;
		prg.selDoc.voidfill = sender.isChecked;
	}
	private void onItemSelect(Event ev) {
		prg.selDoc.tileMaterial_Select(tiles[listView_materials.value].id);
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
