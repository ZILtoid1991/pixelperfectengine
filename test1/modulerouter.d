import pixelperfectengine.concrete.window; 

public class window : Window {
	ListView listView_presets;
	ListView listView_values;
	Button button_remove;
	Button button_add;
	Button button_export;
	public this(){
		super(Box(0, 0, 330, 330), "New Window");
		listView_presets = new ListView(new ListViewHeader(16, [40 ,40], ["col0" ,"col1"]), null, "listView0", Box(5, 20, 230, 100));
		listView_values = new ListView(new ListViewHeader(16, [40 ,40], ["col0" ,"col1"]), null, "listView1", Box(5, 105, 325, 325));
		button_remove = new Button("Remove"d, "button_remove", Box(235, 80, 290, 100));
		button_add = new Button("Add"d, "button_add", Box(235, 55, 290, 75));
		button_export = new Button("Export"d, "button_export", Box(235, 30, 290, 50));
	}
}
