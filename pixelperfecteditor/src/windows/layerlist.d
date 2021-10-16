module windows.layerlist;

import pixelperfectengine.concrete.window;
import app;
import std.utf : toUTF32, toUTF8;
import std.conv : to;
import pixelperfectengine.graphics.layers;
import pixelperfectengine.map.mapformat : LayerInfo;

public class LayerList : Window {
	//ListBox listBox_layers;
	ListView listView_layers;
	SmallButton[] buttons;
	CheckBox checkBox_Hide;
	CheckBox checkBox_Solo;
	public this(int x, int y, void delegate() onClose){
		//super(Coordinate(0 + x, 16 + y, 98 + x, 213 + y), "Layers"d);
		super(Coordinate(0 + x, 0 + y, 129 + x, 213 + y), "Layers"d);
		this.onClose = onClose;
		//StyleSheet ss = getStyleSheet();
		/+listBox_layers = new ListBox("listBox0", Coordinate(1, 17, 129, 180), [], new ListBoxHeader(["Pri"d ,"Type"d, "Name"d],
				[24, 24, 96]));+/
		listView_layers = new ListView(
			new ListViewHeader(16, [24, 24, 96], ["Pri"d ,"Type"d, "Name"d]), null, "listView_layers", Box(1, 17, 128, 179)
		);
		listView_layers.editEnable = true;
		listView_layers.multicellEditEnable = true;
		addElement(listView_layers);
		listView_layers.onItemSelect = &listBox_layers_onItemSelect;
		listView_layers.onTextInput = &layerList_TextEdit;
		{//0
			SmallButton sb = new SmallButton("trashButtonB", "trashButtonA", "trash", Box(113, 197, 129, 213));
			sb.onMouseLClick = &button_trash_onClick;
			buttons ~= sb;
		}
		{//1
			SmallButton sb = new SmallButton("settingsButtonB", "settingsButtonA", "editMat", Box(97, 197, 113, 213));
			//sb.onMouseLClickRel = &button_trash_onClick;
			buttons ~= sb;
		}
		{//2
			SmallButton sb = new SmallButton("newTileLayerButtonB", "newTileLayerButtonA", "newTileLayer",
					Box(1, 181, 16, 196));
			sb.onMouseLClick = &button_newTileLayer_onClick;
			buttons ~= sb;
		}
		{//3
			SmallButton sb = new SmallButton("newSpriteLayerButtonB", "newSpriteLayerButtonA", "newSpriteLayer",
					Box(17, 181, 32, 196));
			sb.onMouseLClick = &button_newSpriteLayer_onClick;
			buttons ~= sb;
		}
		{//4
			SmallButton sb = new SmallButton("newTransformableTileLayerButtonB", "newTransformableTileLayerButtonA",
					"newTransformableTileLayer", Box(33, 181, 48, 196));
			sb.onMouseLClick = &button_newTransformableTileLayer_onClick;
			buttons ~= sb;
		}
		{//5
			SmallButton sb = new SmallButton("importMaterialDataButtonB", "importMaterialDataButtonA", "importMat",
					Box(97, 181, 113, 196));
			sb.onMouseLClick = &button_importMaterialData_onClick;
			buttons ~= sb;
		}
		{//6
			SmallButton sb = new SmallButton("importLayerDataButtonB", "importLayerDataButtonA", "importLayer",
					Box(113, 181, 129, 196));
			sb.onMouseLClick = &button_importLayerData_onClick;
			buttons ~= sb;
		}
		checkBox_Hide = new CheckBox("visibilityButtonB", "visibilityButtonA", "checkBox_Hide", Box(1, 197, 16, 212));
		checkBox_Hide.onToggle = &checkBox_Hide_onToggle;
		addElement(checkBox_Hide);
		checkBox_Solo = new CheckBox("soloButtonB", "soloButtonA", "checkBox_Solo", Box(17, 197, 32, 212));
		checkBox_Solo.onToggle = &checkBox_Solo_onToggle;
		addElement(checkBox_Solo);
		/+{
			SmallButton sb = new SmallButton("upArrowB", "upArrowA", "moveLayerUp", Coordinate(1, 197, 16, 212));
			sb.onMouseLClick = &button_moveLayerUp_onClick;
			buttons ~= sb;
		}
		{
			SmallButton sb = new SmallButton("downArrowB", "downArrowA", "moveLayerDown", Coordinate(17, 197, 32, 212));
			sb.onMouseLClick = &button_moveLayerDown_onClick;
			buttons ~= sb;
		}+/
		foreach(sb ; buttons){
			addElement(sb);
		}
		//CheckBox_Visible = new CheckBox("Visible"d, "CheckBox0", Coordinate(1, 180, 97, 196));
	}
	private void listBox_layers_onItemSelect(Event ev){
		if (prg.selDoc !is null) {
			ListViewItem lbi = cast(ListViewItem)ev.aux;
			const int selectedLayer = to!int(lbi.fields[0].text.text);
			prg.selDoc.selectedLayer = selectedLayer;
			prg.selDoc.updateMaterialList();
			if (selectedLayer in prg.selDoc.outputWindow.hiddenLayers)
				checkBox_Hide.check();
			else
				checkBox_Hide.unCheck();
			if (selectedLayer in prg.selDoc.outputWindow.soloedLayers)
				checkBox_Solo.check();
			else
				checkBox_Solo.unCheck();
		}
	}
	private void button_trash_onClick(Event ev){
		if (prg.selDoc !is null) {
			prg.selDoc.removeLayer();
		}
	}
	private void button_newTileLayer_onClick(Event ev){
		prg.initNewTileLayer;
	}
	private void button_newSpriteLayer_onClick(Event ev){

	}
	private void button_newTransformableTileLayer_onClick(Event ev){

	}
	private void button_importMaterialData_onClick(Event ev){

	}
	private void button_importLayerData_onClick(Event ev){

	}
	private void checkBox_Hide_onToggle(Event ev){
		if (prg.selDoc !is null) {
			const int selectedLayer = to!int(listView_layers[listView_layers.value][0].text.text);
			if (checkBox_Hide.isChecked)
				prg.selDoc.outputWindow.hiddenLayers.put(selectedLayer);
			else
				prg.selDoc.outputWindow.hiddenLayers.removeByElem(selectedLayer);
		}	
	}
	private void checkBox_Solo_onToggle(Event ev){
		if (prg.selDoc !is null) {
			const int selectedLayer = to!int(listView_layers[listView_layers.value][0].text.text);
			if (checkBox_Hide.isChecked)
				prg.selDoc.outputWindow.soloedLayers.put(selectedLayer);
			else
				prg.selDoc.outputWindow.soloedLayers.removeByElem(selectedLayer);
		}
	}
	public void updateLayerList(LayerInfo[] items) {
		//ListViewItem[] list;
		listView_layers.clear();
		foreach (i ; items) {
			//list ~= new ListViewItem(16, [to!dstring(i.pri), to!dstring(i.type), toUTF32(i.name)]);
			ListViewItem lvi = new ListViewItem(16, [to!dstring(i.pri), to!dstring(i.type), toUTF32(i.name)]);
			lvi[0].editable = true;
			lvi[0].integer = true;
			lvi[2].editable = true;
			listView_layers ~= lvi;
		}
		listView_layers.refresh;
		//listView_layers.(list);
	}
	private void layerList_TextEdit(Event ev) {
		import pixelperfectengine.system.etc : isInteger;
		CellEditEvent cee = cast(CellEditEvent)ev;
		if (prg.selDoc !is null) {
			if (cee.column == 2) {	//Rename
				prg.selDoc.renameLayer(toUTF8(cee.text.text));
			} else if (isInteger(cee.text.text)) {				//Set new priority
				prg.selDoc.changeLayerPriority(to!int(cee.text.text));
			}
		}
	}
	public override void close(){
		if(onClose !is null){
			onClose();
		}
		super.close;
	}
	public void nextLayer() {
		if (prg.selDoc !is null) {
			listView_layers.value = listView_layers.value + 1;
			const int selectedLayer = to!int(listView_layers[listView_layers.value][0].text.text);
			prg.selDoc.selectedLayer = selectedLayer;
			prg.selDoc.updateMaterialList();
			if (selectedLayer in prg.selDoc.outputWindow.hiddenLayers)
				checkBox_Hide.check();
			else
				checkBox_Hide.unCheck();
			if (selectedLayer in prg.selDoc.outputWindow.soloedLayers)
				checkBox_Solo.check();
			else
				checkBox_Solo.unCheck();
		}
	}
	public void prevLayer() {
		if (prg.selDoc !is null) {
			listView_layers.value = listView_layers.value - 1;
			const int selectedLayer = to!int(listView_layers[listView_layers.value][0].text.text);
			prg.selDoc.selectedLayer = selectedLayer;
			prg.selDoc.updateMaterialList();
			if (selectedLayer in prg.selDoc.outputWindow.hiddenLayers)
				checkBox_Hide.check();
			else
				checkBox_Hide.unCheck();
			if (selectedLayer in prg.selDoc.outputWindow.soloedLayers)
				checkBox_Solo.check();
			else
				checkBox_Solo.unCheck();
		}
	}
}
