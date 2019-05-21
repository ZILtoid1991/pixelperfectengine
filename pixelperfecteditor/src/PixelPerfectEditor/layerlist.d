import PixelPerfectEngine.concrete.window;
import app;

public class LayerList : Window {
	ListBox listBox_layers;
	SmallButton[] buttons;
	public void delegate() onClose;
	//CheckBox CheckBox_Visible;
	public this(int x, int y, void delegate() onClose){
		//super(Coordinate(0 + x, 16 + y, 98 + x, 213 + y), "Layers"d);
		super(Coordinate(0 + x, 0 + y, 98 + x, 213 + y), "Layers"d);
		this.onClose = onClose;
		//StyleSheet ss = getStyleSheet();
		listBox_layers = new ListBox("listBox0", Coordinate(1, 17, 97, 180), [], new ListBoxHeader(["Type"d, "Name"d], [24, 64]));
		addElement(listBox_layers, EventProperties.MOUSE);
		{
			SmallButton sb = new SmallButton("trashButtonB", "trashButtonA", "trash", Coordinate(81, 196, 97, 212));
			sb.onMouseLClickRel = &button_trash_onClick;
			buttons ~= sb;
		}
		{
			SmallButton sb = new SmallButton("newTileLayerButtonB", "newTileLayerButtonA", "newTileLayer", Coordinate(1, 180, 17, 196));
			sb.onMouseLClickRel = &button_newTileLayer_onClick;
			buttons ~= sb;
		}
		{
			SmallButton sb = new SmallButton("newSpriteLayerButtonB", "newSpriteLayerButtonA", "newSpriteLayer", Coordinate(17, 180, 33, 196));
			sb.onMouseLClickRel = &button_newSpriteLayer_onClick;
			buttons ~= sb;
		}
		{
			SmallButton sb = new SmallButton("newTransformableTileLayerButtonB", "newTransformableTileLayerButtonA", "newTransformableTileLayer",
					Coordinate(33, 180, 49, 196));
			sb.onMouseLClickRel = &button_newTransformableTileLayer_onClick;
			buttons ~= sb;
		}
		{
			SmallButton sb = new SmallButton("importMaterialDataButtonB", "importMaterialDataButtonA", "trash", Coordinate(65, 180, 81, 196));
			sb.onMouseLClickRel = &button_importMaterialData_onClick;
			buttons ~= sb;
		}
		{
			SmallButton sb = new SmallButton("importLayerDataButtonB", "importLayerDataButtonA", "trash", Coordinate(81, 180, 97, 196));
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
	public override void close(){
		if(onClose !is null){
			onClose();
		}
		super.close;
	}
}
