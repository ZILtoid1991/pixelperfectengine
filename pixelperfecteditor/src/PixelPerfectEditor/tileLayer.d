 module tileLayer;

 import PixelPerfectEngine.concrete.window;
 import PixelPerfectEngine.graphics.common;
 import editor;
 import std.string;
 
 public class TileLayerEditor : Window, ActionListener { 
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
	this(Editor e){
		super(Coordinate(0, 0, 410, 410), "TileLayer"w);
		tileList = new ListBox("tileList",Coordinate(5, 20, 320, 244), null, new ListBoxHeader(["ID"w, "Name"w, "Source"w], [32, 80, 320]), 16);
		addElement(tileList, EventProperties.MOUSE | EventProperties.SCROLL);
		button_Add = new Button("Add"w, "button_Add", Coordinate(325, 20, 405, 40));
		addElement(button_Add, EventProperties.MOUSE);
		button_Add.al ~= this;
		button_rem = new Button("Remove"w, "button_rem", Coordinate(325, 45, 405, 65));
		addElement(button_rem, EventProperties.MOUSE);
		button_rem.al ~= this;
		button_rrem = new Button("Rec.rem"w, "button_rrem", Coordinate(325, 70, 405, 90));
		addElement(button_rrem, EventProperties.MOUSE);
		button_rrem.al ~= this;
		button_rep = new Button("Replace"w, "button_rep", Coordinate(325, 95, 405, 115));
		addElement(button_rep, EventProperties.MOUSE);
		button_rep.al ~= this;
		button_imp = new Button("Import"w, "button_imp", Coordinate(325, 130, 405, 150));
		addElement(button_imp, EventProperties.MOUSE);
		button_imp.al ~= this;
		button_res = new Button("Resize"w, "button_res", Coordinate(325, 165, 405, 185));
		addElement(button_res, EventProperties.MOUSE);
		button_res.al ~= this;
		checkBox_hm = new CheckBox("horizMir"w, "checkBox_hm", Coordinate(5, 255, 125, 275));
		addElement(checkBox_hm, EventProperties.MOUSE);
		checkBox_hm.al ~= this;
		checkBox_vm = new CheckBox("vertMir"w, "checkBox_vm", Coordinate(100, 255, 265, 275));
		addElement(checkBox_vm, EventProperties.MOUSE);
		checkBox_vm.al ~= this;
		checkBox_overwrite = new CheckBox("Disable overwrite on non-null characters"w, "checkBox_overwrite", Coordinate(5, 280, 350, 300));
		addElement(checkBox_overwrite, EventProperties.MOUSE);
		checkBox_overwrite.al ~= this;
		label1 = new Label("pri/flags(0-63):"w, "label1", Coordinate(190, 253, 328, 269));
		addElement(label1, EventProperties.MOUSE);
		textBox_pri = new TextBox("0"w, "textBox_pri", Coordinate(325, 250, 405, 270));
		addElement(textBox_pri, EventProperties.MOUSE);
		textBox_pri.al ~= this;
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
		sXRate.al ~= this;
		sXOffset = new TextBox("0"w, "sXOffset", Coordinate(80, 330, 170, 350));
		addElement(sXOffset, EventProperties.MOUSE);
		sXOffset.al ~= this;
		sYRate = new TextBox("0.0"w, "sYRate", Coordinate(250, 305, 340, 325));
		addElement(sYRate, EventProperties.MOUSE);
		sYRate.al ~= this;
		sYOffset = new TextBox("0"w, "sYOffset", Coordinate(250, 330, 340, 350));
		addElement(sYOffset, EventProperties.MOUSE);
		sYOffset.al ~= this;
		checkBox_vis = new CheckBox("Visible"w, "checkBox_vis", Coordinate(5, 355, 135, 371));
		addElement(checkBox_vis, EventProperties.MOUSE);
		checkBox_vis.al ~= this;
		checkBox_solo = new CheckBox("Solo"w, "checkBox_solo", Coordinate(80, 355, 164, 371));
		addElement(checkBox_solo, EventProperties.MOUSE);
		checkBox_solo.al ~= this;
		checkBox_warp = new CheckBox("Warp"w, "checkBox_warp", Coordinate(130, 355, 210, 371));
		addElement(checkBox_warp, EventProperties.MOUSE);
		checkBox_warp.al ~= this;
		button_prev = new Button("Previous"w, "button_prev", Coordinate(325, 380, 400, 400));
		addElement(button_prev, EventProperties.MOUSE);
		button_prev.al ~= this;
		button_next = new Button("Next"w, "button_next", Coordinate(325, 355, 400, 375));
		addElement(button_next, EventProperties.MOUSE);
		button_next.al ~= this;
		button_down = new Button("Down"w, "button_down", Coordinate(345, 330, 400, 350));
		addElement(button_down, EventProperties.MOUSE);
		button_down.al ~= this;
		button_up = new Button("Up"w, "button_up", Coordinate(345, 305, 400, 325));
		addElement(button_up, EventProperties.MOUSE);
		button_up.al ~= this;
		label6 = new Label("Layername:"w, "label6", Coordinate(5, 382, 95, 403));
		addElement(label6, EventProperties.MOUSE);
		layerName = new TextBox("tilelayer1"w, "layerName", Coordinate(100, 380, 320, 400));
		addElement(layerName, EventProperties.MOUSE);
		layerName.al ~= this;
		edi = e;
	}
	override public void actionEvent(Event event){
		import PixelPerfectEngine.system.etc;
		switch(event.source){
			case "sXRate":
				if(isNumeric(sXRate.getText())){
				
				}else{
					parent.messageWindow("Input error!", "Please enter a numeric value into field sXRate!");
				}
				break;
			case "sYRate":
				if(isNumeric(sYRate.getText())){
				
				}else{
					parent.messageWindow("Input error!", "Please enter a numeric value into field sYRate!");
				}
				break;
			case "sXOffset":
				if(isInteger(sXOffset.getText())){
				
				}else{
					parent.messageWindow("Input error!", "Please enter a numeric value into field sXOffset!");
				}
				break;
			case "sYOffset":
				if(isInteger(sYOffset.getText())){
				
				}else{
					parent.messageWindow("Input error!", "Please enter a numeric value into field sYOffset!");
				}
				break;
			default: break;
		}
	}
}