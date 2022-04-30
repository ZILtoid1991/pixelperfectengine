import pixelperfectengine.concrete.window; 
import std.conv : to;

public class ModuleEditor : Window {
	ListView listView_presets;
	ListView listView_values;
	Button button_remove;
	Button button_add;
	Button button_export;
	public this(dstring name){
		super(Box(0, 0, 330, 330), name);
		listView_presets = new ListView(new ListViewHeader(16, [32, 32, 240], ["Bank" ,"Prg" ,"Name"]), null, 
				"listView_presets", Box(5, 20, 230, 100));
		listView_values = new ListView(new ListViewHeader(16, [200, 100], ["" ,"listView1" ,""]), null, "listView_values", 
				Box(5, 105, 325, 325));
		button_remove = new Button("Remove"d, "button_remove", Box(235, 80, 290, 100));
		button_add = new Button("Add"d, "button_add", Box(235, 55, 290, 75));
		button_export = new Button("Export"d, "button_export", Box(235, 30, 290, 50));
		addElement(listView_presets);
		addElement(listView_values);
		addElement(button_remove);
		addElement(button_add);
		addElement(button_export);
	}
}
