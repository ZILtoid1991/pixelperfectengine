module layerlist;

import PixelPerfectEngine.concrete.window;
import app;
import std.utf : toUTF32;
import std.conv : to;
import PixelPerfectEngine.graphics.layers;
import PixelPerfectEngine.map.mapformat : LayerInfo;

public class LayerList : Window {
	ListBox listBox_layers;
	SmallButton[] buttons;
	public void delegate() onClose;
	//CheckBox CheckBox_Visible;
	public this(int x, int y, void delegate() onClose){
		//super(Coordinate(0 + x, 16 + y, 98 + x, 213 + y), "Layers"d);
		super(Coordinate(0 + x, 0 + y, 130 + x, 213 + y), "Layers"d);
		this.onClose = onClose;
		//StyleSheet ss = getStyleSheet();
		listBox_layers = new ListBox("listBox0", Coordinate(1, 17, 129, 180), [], new ListBoxHeader(["Pri"d ,"Type"d, "Name"d],
				[24, 24, 96]));
		addElement(listBox_layers, EventProperties.MOUSE);
		{
			SmallButton sb = new SmallButton("trashButtonB", "trashButtonA", "trash", Coordinate(113, 196, 129, 212));
			sb.onMouseLClickRel = &button_trash_onClick;
			buttons ~= sb;
		}
		{
			SmallButton sb = new SmallButton("settingsButtonB", "settingsButtonA", "editMat", Coordinate(97, 196, 113, 212));
			//sb.onMouseLClickRel = &button_trash_onClick;
			buttons ~= sb;
		}
		{
			SmallButton sb = new SmallButton("newTileLayerButtonB", "newTileLayerButtonA", "newTileLayer",
					Coordinate(1, 180, 17, 196));
			sb.onMouseLClickRel = &button_newTileLayer_onClick;
			buttons ~= sb;
		}
		{
			SmallButton sb = new SmallButton("newSpriteLayerButtonB", "newSpriteLayerButtonA", "newSpriteLayer",
					Coordinate(17, 180, 33, 196));
			sb.onMouseLClickRel = &button_newSpriteLayer_onClick;
			buttons ~= sb;
		}
		{
			SmallButton sb = new SmallButton("newTransformableTileLayerButtonB", "newTransformableTileLayerButtonA",
					"newTransformableTileLayer", Coordinate(33, 180, 49, 196));
			sb.onMouseLClickRel = &button_newTransformableTileLayer_onClick;
			buttons ~= sb;
		}
		{
			SmallButton sb = new SmallButton("importMaterialDataButtonB", "importMaterialDataButtonA", "importMat",
					Coordinate(97, 180, 113, 196));
			sb.onMouseLClickRel = &button_importMaterialData_onClick;
			buttons ~= sb;
		}
		{
			SmallButton sb = new SmallButton("importLayerDataButtonB", "importLayerDataButtonA", "importLayer",
					Coordinate(113, 180, 129, 196));
			sb.onMouseLClickRel = &button_importLayerData_onClick;
			buttons ~= sb;
		}
		{
			SmallButton sb = new SmallButton("upArrowB", "upArrowA", "moveLayerUp", Coordinate(1, 196, 17, 212));
			sb.onMouseLClickRel = &button_moveLayerUp_onClick;
			buttons ~= sb;
		}
		{
			SmallButton sb = new SmallButton("downArrowB", "downArrowA", "moveLayerDown", Coordinate(17, 196, 33, 212));
			sb.onMouseLClickRel = &button_moveLayerDown_onClick;
			buttons ~= sb;
		}
		foreach(sb ; buttons){
			addElement(sb, EventProperties.MOUSE);
		}
		//CheckBox_Visible = new CheckBox("Visible"d, "CheckBox0", Coordinate(1, 180, 97, 196));
	}
	private void listBox_layers_onItemSelect(Event ev){

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
		ListBoxItem[] list;
		foreach (i ; items) {
			list ~= new ListBoxItem([to!dstring(i.pri), to!dstring(i.type), toUTF32(i.name)]);
		}
		listBox_layers.updateColumns(list);
	}
	public override void close(){
		if(onClose !is null){
			onClose();
		}
		super.close;
	}
}
