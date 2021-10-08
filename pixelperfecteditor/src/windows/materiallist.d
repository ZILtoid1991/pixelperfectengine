module windows.materiallist;

import pixelperfectengine.concrete.window;
import pixelperfectengine.map.mapformat;

import app;

import std.utf : toUTF32, toUTF8;
import pixelperfectengine.system.etc : intToHex;

/**
 * Preliminary, future version will feature material selection with images.
 */
public class MaterialList : Window {
	//ListBox			listBox_materials;
	ListView		listView_materials;
	Label			palettePos;
	SmallButton		removeMaterial;
	SmallButton		addMaterial;
	CheckBox		horizMirror;
	CheckBox		vertMirror;
	CheckBox		ovrwrtIns;
	SmallButton		paletteUp;
	SmallButton		paletteDown;
	SmallButton		settings;

	protected TileInfo[] tiles;
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
		listView_materials.editEnable = true;
		listView_materials.onTextInput = &onItemRename;
		addElement(listView_materials);
		
		removeMaterial = new SmallButton("removeMaterialB", "removeMaterialA", "rem", Box(113, 233, 129, 248));
		removeMaterial.onMouseLClick = &button_trash_onClick;
		addElement(removeMaterial);
		
		addMaterial = new SmallButton("addMaterialB", "addMaterialA", "add", Box(113, 217, 129, 232));
		addMaterial.onMouseLClick = &button_addMaterial_onClick;
		addElement(addMaterial);
		
		horizMirror = new CheckBox("horizMirrorB", "horizMirrorA", "horizMirror", Box(1, 217, 16, 232));
		horizMirror.onToggle = &horizMirror_onClick;
		addElement(horizMirror);
		
		vertMirror = new CheckBox("vertMirrorB", "vertMirrorA", "vertMirror", Box(17, 217, 32, 232));
		vertMirror.onToggle = &vertMirror_onClick;
		addElement(vertMirror);
		
		ovrwrtIns = new CheckBox("ovrwrtInsB", "ovrwrtInsA", "ovrwrtIns", Box(33, 217, 48, 232));
		ovrwrtIns.onToggle = &ovrwrtIns_onClick;
		addElement(ovrwrtIns);
		
		paletteUp = new SmallButton("paletteUpB", "paletteUpA", "palUp", Box(1, 233, 16, 248));
		paletteUp.onMouseLClick = &palUp_onClick;
		addElement(paletteUp);
		
		paletteDown = new SmallButton("paletteDownB", "paletteDownA", "palDown", Box(17, 233, 32, 248));
		paletteDown.onMouseLClick = &palDown_onClick;
		addElement(paletteDown);
		
		settings = new SmallButton("settingsButtonB", "settingsButtonA", "editMat", Box(97, 233, 112, 248));
		settings.onMouseLClick = &button_editMat_onClick;
		addElement(settings);
		
		palettePos = new Label("0x00", "palettePos", Box(34, 234, 96, 248));
		addElement(palettePos);
	}
	public void updateMaterialList(TileInfo[] list) @trusted {
		import pixelperfectengine.system.etc : intToHex;
		tiles = list;
		/+ListViewItem[] output;
		output.reserve = list.length;+/
		listView_materials.clear;
		foreach (item ; list) {
			ListViewItem f = new ListViewItem(16, [intToHex!dstring(item.id, 4) ~ "h", toUTF32(item.name)]);
			f[1].editable = true;
			listView_materials ~= f;
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
		if (listView_materials.value != -1) {
			prg.selDoc.removeTile(tiles[listView_materials.value].id);
		}
	}
	public void palUp_onClick(Event ev) {
		palettePos.setText("0x" ~ intToHex!dstring(prg.selDoc.tileMaterial_PaletteUp, 2));
	}
	public void palDown_onClick(Event ev) {
		palettePos.setText("0x" ~ intToHex!dstring(prg.selDoc.tileMaterial_PaletteDown, 2));
	}

	private void ovrwrtIns_onClick(Event ev) {
		CheckBox sender = cast(CheckBox)ev.sender;
		if (prg.selDoc)
			prg.selDoc.voidfill = sender.isChecked;
	}
	private void onItemSelect(Event ev) {
		prg.selDoc.tileMaterial_Select(tiles[listView_materials.value].id);
	}
	private void onItemRename(Event ev) {
		CellEditEvent cee = cast(CellEditEvent)ev;
		string newName = toUTF8(cee.text().text());
		prg.selDoc.renameTile(tiles[listView_materials.value].id, newName);
	}
	public void nextTile() {
		listView_materials.value = listView_materials.value + 1;
		if (listView_materials.value != -1)
			prg.selDoc.tileMaterial_Select(tiles[listView_materials.value].id);
	}
	public void prevTile() {
		listView_materials.value = listView_materials.value - 1;
		if (listView_materials.value != -1)
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
