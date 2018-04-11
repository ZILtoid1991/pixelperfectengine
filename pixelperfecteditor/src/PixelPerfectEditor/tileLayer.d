 module tileLayer;

 import PixelPerfectEngine.concrete.window;
 import PixelPerfectEngine.graphics.common;
 import editor;
 import std.conv;
 
 public class TileLayerEditor : Window { 
	ListBox tileList;
	Button button_Add;
	Button button_rem;
	Button button_rrem;
	Button button_rep;
	Button button_imp;
	Button button_res;
	CheckBox checkBox_hm;
	CheckBox checkBox_vm;
	CheckBox checkBox_overwrite;
	Label label1;
	TextBox textBox_pri;
	Label label2;
	Label label3;
	Label label4;
	Label label5;
	TextBox sXRate;
	TextBox sXOffset;
	TextBox sYRate;
	TextBox sYOffset;
	CheckBox checkBox_vis;
	CheckBox checkBox_solo;
	CheckBox checkBox_warp;
	Button button_prev;
	Button button_next;
	Button button_down;
	Button button_up;
	Label label6;
	TextBox layerName;
	Editor edi;
	int selectedLayer;
	this(Editor e){
		super(Coordinate(0, 0, 410, 410), "TileLayer"w);
		tileList = new ListBox("tileList",Coordinate(5, 20, 320, 244), null, new ListBoxHeader(["ID"w, "Name"w, "Source"w], [32, 80, 320]), 16);
		addElement(tileList, EventProperties.MOUSE | EventProperties.SCROLL);
		button_Add = new Button("Add"w, "button_Add", Coordinate(325, 20, 405, 40));
		addElement(button_Add, EventProperties.MOUSE);
		button_Add.onMouseLClickRel = &button_Add_onMouseLClickRel;
		button_rem = new Button("Remove"w, "button_rem", Coordinate(325, 45, 405, 65));
		addElement(button_rem, EventProperties.MOUSE);
		button_rem.onMouseLClickRel = &button_rem_onMouseLClickRel;
		button_rrem = new Button("Rec.rem"w, "button_rrem", Coordinate(325, 70, 405, 90));
		addElement(button_rrem, EventProperties.MOUSE);
		button_rrem.onMouseLClickRel = &button_rrem_onMouseLClickRel;
		button_rep = new Button("Replace"w, "button_rep", Coordinate(325, 95, 405, 115));
		addElement(button_rep, EventProperties.MOUSE);
		button_rep.onMouseLClickRel = &button_rep_onMouseLClickRel;
		button_imp = new Button("Import"w, "button_imp", Coordinate(325, 130, 405, 150));
		addElement(button_imp, EventProperties.MOUSE);
		button_imp.onMouseLClickRel = &button_imp_onMouseLClickRel;
		button_res = new Button("Resize"w, "button_res", Coordinate(325, 165, 405, 185));
		addElement(button_res, EventProperties.MOUSE);
		button_res.onMouseLClickRel = &button_res_onMouseLClickRel;
		checkBox_hm = new CheckBox("horizMir"w, "checkBox_hm", Coordinate(5, 255, 125, 275));
		addElement(checkBox_hm, EventProperties.MOUSE);
		checkBox_hm.onToggle = &checkBox_hm_onToggle;
		checkBox_vm = new CheckBox("vertMir"w, "checkBox_vm", Coordinate(100, 255, 265, 275));
		addElement(checkBox_vm, EventProperties.MOUSE);
		checkBox_vm.onToggle = &checkBox_vm_onToggle;
		checkBox_overwrite = new CheckBox("Disable overwrite on non-null characters"w, "checkBox_overwrite", Coordinate(5, 280, 350, 300));
		addElement(checkBox_overwrite, EventProperties.MOUSE);
		checkBox_overwrite.onToggle = &checkBox_overwrite_onToggle;
		label1 = new Label("pri/flags(0-63):"w, "label1", Coordinate(190, 253, 328, 269));
		addElement(label1, EventProperties.MOUSE);
		textBox_pri = new TextBox("0"w, "textBox_pri", Coordinate(325, 250, 405, 270));
		addElement(textBox_pri, EventProperties.MOUSE);
		textBox_pri.onTextInput = &textBox_pri_onTextInput;
		label2 = new Label("sXRate:"w, "label2", Coordinate(5, 307, 73, 325));
		addElement(label2, EventProperties.MOUSE);
		label3 = new Label("sYRate:"w, "label3", Coordinate(175, 307, 240, 325));
		addElement(label3, EventProperties.MOUSE);
		label4 = new Label("sXOffset:"w, "label4", Coordinate(5, 332, 80, 350));
		addElement(label4, EventProperties.MOUSE);
		label5 = new Label("sYOffset:"w, "label5", Coordinate(175, 332, 264, 350));
		addElement(label5, EventProperties.MOUSE);
		sXRate = new TextBox("0.0"w, "sXRate", Coordinate(80, 305, 170, 325));
		addElement(sXRate, EventProperties.MOUSE);
		sXRate.onTextInput = &sXRate_onTextInput;
		sXOffset = new TextBox("0"w, "sXOffset", Coordinate(80, 330, 170, 350));
		addElement(sXOffset, EventProperties.MOUSE);
		sXOffset.onTextInput = &sXOffset_onTextInput;
		sYRate = new TextBox("0.0"w, "sYRate", Coordinate(250, 305, 340, 325));
		addElement(sYRate, EventProperties.MOUSE);
		sYRate.onTextInput = &sYRate_onTextInput;
		sYOffset = new TextBox("0"w, "sYOffset", Coordinate(250, 330, 340, 350));
		addElement(sYOffset, EventProperties.MOUSE);
		sYOffset.onTextInput = &sYOffset_onTextInput;
		checkBox_vis = new CheckBox("Visible"w, "checkBox_vis", Coordinate(5, 355, 135, 371));
		addElement(checkBox_vis, EventProperties.MOUSE);
		checkBox_vis.onToggle = &checkBox_vis_onToggle;
		checkBox_solo = new CheckBox("Solo"w, "checkBox_solo", Coordinate(80, 355, 164, 371));
		addElement(checkBox_solo, EventProperties.MOUSE);
		checkBox_solo.onToggle = &checkBox_solo_onToggle;
		checkBox_warp = new CheckBox("Warp"w, "checkBox_warp", Coordinate(130, 355, 210, 371));
		addElement(checkBox_warp, EventProperties.MOUSE);
		checkBox_warp.onToggle = &checkBox_warp_onToggle;
		button_prev = new Button("Previous"w, "button_prev", Coordinate(325, 380, 400, 400));
		addElement(button_prev, EventProperties.MOUSE);
		button_prev.onMouseLClickRel = &button_prev_onMouseLClickRel;
		button_next = new Button("Next"w, "button_next", Coordinate(325, 355, 400, 375));
		addElement(button_next, EventProperties.MOUSE);
		button_next.onMouseLClickRel = &button_next_onMouseLClickRel;
		button_down = new Button("Down"w, "button_down", Coordinate(345, 330, 400, 350));
		addElement(button_down, EventProperties.MOUSE);
		button_down.onMouseLClickRel = &button_down_onMouseLClickRel;
		button_up = new Button("Up"w, "button_up", Coordinate(345, 305, 400, 325));
		addElement(button_up, EventProperties.MOUSE);
		button_up.onMouseLClickRel = &button_up_onMouseLClickRel;
		label6 = new Label("Layername:"w, "label6", Coordinate(5, 382, 95, 403));
		addElement(label6, EventProperties.MOUSE);
		layerName = new TextBox("tilelayer1"w, "layerName", Coordinate(100, 380, 320, 400));
		addElement(layerName, EventProperties.MOUSE);
		//layerName.onTextInput ~= la;
		edi = e;
	}
	/+public void actionEvent(Event event){
		import PixelPerfectEngine.system.etc;
		import std.string;
		switch(event.source){
			case "sXRate":
				if(isNumeric(sXRate.getText())){
					edi.document.tld[selectedLayer].sX = to!double(sXRate.getText());
				}else{
					parent.messageWindow("Input error!", "Please enter a numeric value into field sXRate!");
				}
				break;
			case "sYRate":
				if(isNumeric(sYRate.getText())){
					edi.document.tld[selectedLayer].sY = to!double(sYRate.getText());
				}else{
					parent.messageWindow("Input error!", "Please enter a numeric value into field sYRate!");
				}
				break;
			case "sXOffset":
				if(isInteger(sXOffset.getText())){
					edi.document.tld[selectedLayer].sXOffset = to!double(sXOffset.getText());
				}else{
					parent.messageWindow("Input error!", "Please enter a numeric value into field sXOffset!");
				}
				break;
			case "sYOffset":
				if(isInteger(sYOffset.getText())){
					edi.document.tld[selectedLayer].sYOffset = to!double(sYOffset.getText());
				}else{
					parent.messageWindow("Input error!", "Please enter a numeric value into field sYOffset!");
				}
				break;
			case "button_Add":
				FileDialog f = new FileDialog("Add new tile"w, "tileAdd", this, [FileDialog.FileAssociationDescriptor("XMP file"w, ["*.xmp"])], "./");
				break;
			case "button_rem":
				break;
			case "button_rrem":
				break;
			case "button_rep":
				break;
			case "button_imp":
				break;
			case "button_res":
				break;
			case "checkBox_hm":
				break;
			case "checkBox_vm":
				break;
			case "checkBox_overwrite":
				break;
			case "textBox_pri":
				break;
			case "checkBox_vis":
				break;
			case "checkBox_solo":
				break;
			case "checkBox_warp":
				break;
			case "button_prev":
				selectedLayer = edi.getPreviousTileLayer(selectedLayer);
				layerName.setText(to!wstring(edi.document.tld[selectedLayer].name));
				sXRate.setText(to!wstring(edi.document.tld[selectedLayer].sX));
				sYRate.setText(to!wstring(edi.document.tld[selectedLayer].sY));
				sXOffset.setText(to!wstring(edi.document.tld[selectedLayer].sXOffset));
				sYOffset.setText(to!wstring(edi.document.tld[selectedLayer].sYOffset));
				checkBox_warp.value = edi.document.tld[selectedLayer].warp;
				break;
			case "button_next":
				selectedLayer = edi.getNePreviousTileLayer(selectedLayer);
				layerName.setText(to!wstring(edi.document.tld[selectedLayer].name));
				sXRate.setText(to!wstring(edi.document.tld[selectedLayer].sX));
				sYRate.setText(to!wstring(edi.document.tld[selectedLayer].sY));
				sXOffset.setText(to!wstring(edi.document.tld[selectedLayer].sXOffset));
				sYOffset.setText(to!wstring(edi.document.tld[selectedLayer].sYOffset));
				checkBox_warp.value = edi.document.tld[selectedLayer].warp;
				break;
			case "button_down":
				selectedLayer = edi.moveLayerDown(selectedLayer);
				break;
			case "button_up":
				selectedLayer = edi.moveLayerUp(selectedLayer);
				break;
			default: break;
		}
	}+/
	private void checkBox_hm_onToggle(Event ev){
	
	}
	private void checkBox_vm_onToggle(Event ev){
	
	}
	private void checkBox_overwrite_onToggle(Event ev){
	
	}
	private void checkBox_vis_onToggle(Event ev){
	
	}
	private void checkBox_solo_onToggle(Event ev){
	
	}
	private void checkBox_warp_onToggle(Event ev){
	
	}
	private void sXRate_onTextInput(Event ev){
		import std.string;
		if(isNumeric(sXRate.getText())){
			edi.document.tld[selectedLayer].sX = to!double(sXRate.getText());
		}else{
			parent.messageWindow("Input error!", "Please enter a numeric value into field sXRate!");
		}
	}
	private void sYRate_onTextInput(Event ev){
		import std.string;
		if(isNumeric(sYRate.getText())){
			edi.document.tld[selectedLayer].sY = to!double(sYRate.getText());
		}else{
			parent.messageWindow("Input error!", "Please enter a numeric value into field sYRate!");
		}
	}
	private void sXOffset_onTextInput(Event ev){
		import PixelPerfectEngine.system.etc;
		if(isInteger(sXOffset.getText())){
			edi.document.tld[selectedLayer].sXOffset = to!double(sXOffset.getText());
		}else{
			parent.messageWindow("Input error!", "Please enter a numeric value into field sXOffset!");
		}
	}
	private void sYOffset_onTextInput(Event ev){
		import PixelPerfectEngine.system.etc;
		if(isInteger(sYOffset.getText())){
			edi.document.tld[selectedLayer].sYOffset = to!double(sYOffset.getText());
		}else{
			parent.messageWindow("Input error!", "Please enter a numeric value into field sYOffset!");
		}
	}
	private void textBox_pri_onTextInput(Event ev){
	
	}
	private void button_rem_onMouseLClickRel(Event ev){
	
	}
	private void button_rrem_onMouseLClickRel(Event ev){
	
	}
	private void button_rep_onMouseLClickRel(Event ev){
	
	}
	private void button_imp_onMouseLClickRel(Event ev){
		FileDialog f = new FileDialog("Import resources from file"w, "resImp", &onResourceImport, [FileDialog.FileAssociationDescriptor("MAP file"w, ["*.map"])], "./");
	}
	private void button_Add_onMouseLClickRel(Event ev){
		FileDialog f = new FileDialog("Add new tile"w, "tileAdd", &onAddTile, [FileDialog.FileAssociationDescriptor("XMP file"w, ["*.xmp"])], "./");
	}
	private void button_res_onMouseLClickRel(Event ev){
	
	}
	private void button_prev_onMouseLClickRel(Event ev){
		selectedLayer = edi.getPreviousTileLayer(selectedLayer);
		layerName.setText(to!wstring(edi.document.tld[selectedLayer].name));
		sXRate.setText(to!wstring(edi.document.tld[selectedLayer].sX));
		sYRate.setText(to!wstring(edi.document.tld[selectedLayer].sY));
		sXOffset.setText(to!wstring(edi.document.tld[selectedLayer].sXOffset));
		sYOffset.setText(to!wstring(edi.document.tld[selectedLayer].sYOffset));
		checkBox_warp.value = edi.document.tld[selectedLayer].warp;
	}
	private void button_next_onMouseLClickRel(Event ev){
		selectedLayer = edi.getNextTileLayer(selectedLayer);
		layerName.setText(to!wstring(edi.document.tld[selectedLayer].name));
		sXRate.setText(to!wstring(edi.document.tld[selectedLayer].sX));
		sYRate.setText(to!wstring(edi.document.tld[selectedLayer].sY));
		sXOffset.setText(to!wstring(edi.document.tld[selectedLayer].sXOffset));
		sYOffset.setText(to!wstring(edi.document.tld[selectedLayer].sYOffset));
		checkBox_warp.value = edi.document.tld[selectedLayer].warp;
	}
	private void button_down_onMouseLClickRel(Event ev){
		selectedLayer = edi.moveLayerDown(selectedLayer);
	}
	private void button_up_onMouseLClickRel(Event ev){
		selectedLayer = edi.moveLayerUp(selectedLayer);
	}
	private void onAddTile(Event ev){
	
	}
	private void onResourceImport(Event ev){
	
	}
}