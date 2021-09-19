module windows.layerlist;

import pixelperfectengine.concrete.window;
import app;
import std.utf : toUTF32;
import std.conv : to;
import pixelperfectengine.graphics.layers;
import pixelperfectengine.map.mapformat : LayerInfo;

public class LayerList : Window {
	//ListBox listBox_layers;
	ListView listView_layers;
	SmallButton[] buttons;
	
	//CheckBox CheckBox_Visible;
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
		{
			SmallButton sb = new SmallButton("trashButtonB", "trashButtonA", "trash", Box(113, 197, 129, 213));
			sb.onMouseLClick = &button_trash_onClick;
			buttons ~= sb;
		}
		{
			SmallButton sb = new SmallButton("settingsButtonB", "settingsButtonA", "editMat", Box(97, 197, 113, 213));
			//sb.onMouseLClickRel = &button_trash_onClick;
			buttons ~= sb;
		}
		{
			SmallButton sb = new SmallButton("newTileLayerButtonB", "newTileLayerButtonA", "newTileLayer",
					Coordinate(1, 181, 16, 196));
			sb.onMouseLClick = &button_newTileLayer_onClick;
			buttons ~= sb;
		}
		{
			SmallButton sb = new SmallButton("newSpriteLayerButtonB", "newSpriteLayerButtonA", "newSpriteLayer",
					Coordinate(17, 181, 32, 196));
			sb.onMouseLClick = &button_newSpriteLayer_onClick;
			buttons ~= sb;
		}
		{
			SmallButton sb = new SmallButton("newTransformableTileLayerButtonB", "newTransformableTileLayerButtonA",
					"newTransformableTileLayer", Coordinate(33, 181, 48, 196));
			sb.onMouseLClick = &button_newTransformableTileLayer_onClick;
			buttons ~= sb;
		}
		{
			SmallButton sb = new SmallButton("importMaterialDataButtonB", "importMaterialDataButtonA", "importMat",
					Coordinate(97, 181, 113, 196));
			sb.onMouseLClick = &button_importMaterialData_onClick;
			buttons ~= sb;
		}
		{
			SmallButton sb = new SmallButton("importLayerDataButtonB", "importLayerDataButtonA", "importLayer",
					Coordinate(113, 181, 129, 196));
			sb.onMouseLClick = &button_importLayerData_onClick;
			buttons ~= sb;
		}
		{
			SmallButton sb = new SmallButton("upArrowB", "upArrowA", "moveLayerUp", Coordinate(1, 197, 16, 212));
			sb.onMouseLClick = &button_moveLayerUp_onClick;
			buttons ~= sb;
		}
		{
			SmallButton sb = new SmallButton("downArrowB", "downArrowA", "moveLayerDown", Coordinate(17, 197, 32, 212));
			sb.onMouseLClick = &button_moveLayerDown_onClick;
			buttons ~= sb;
		}
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
		}
	}
	private void button_trash_onClick(Event ev){
		
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
	private void button_moveLayerUp_onClick(Event ev){

	}
	private void button_moveLayerDown_onClick(Event ev){

	}
	public void updateLayerList(LayerInfo[] items) {
		//ListViewItem[] list;
		listView_layers.clear();
		foreach (i ; items) {
			//list ~= new ListViewItem(16, [to!dstring(i.pri), to!dstring(i.type), toUTF32(i.name)]);
			ListViewItem lvi = new ListViewItem(16, [to!dstring(i.pri), to!dstring(i.type), toUTF32(i.name)]);
			lvi[0].editable = true;
			lvi[2].editable = true;
			listView_layers ~= lvi;
		}
		listView_layers.refresh;
		//listView_layers.(list);
	}
	private void layerList_TextEdit(Event ev) {
		CellEditEvent cee = cast(CellEditEvent)ev;
		if (prg.selDoc !is null) {
			if (cee.column == 2) {	//Rename
				
			} else {				//Set new priority
	
			}
		}
	}
	public override void close(){
		if(onClose !is null){
			onClose();
		}
		super.close;
	}
}
