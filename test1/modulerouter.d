module test1.modulerouter;

import pixelperfectengine.concrete.window;

public class ModuleRouter : Window {
	ListView listView_modules;
	ListView listView_routing;
	Button button_addMod;
	Button button_remMod;
	Button button_setup;
	Button button_audNode;
	Button button_midiNode;
	Button button_remNode;
	public this(){
		super(Box(0, 0, 640, 480), "Modules and Routing");
		listView_modules = new ListView(new ListViewHeader(16, [64, 256, 256], ["ID", "Type", "Name"]), null, "listView0", 
				Box(5, 20, 530, 175));
		listView_routing = new ListView(new ListViewHeader(16, [64, 128, 125], ["Num", "From", "To"]), null, "listView1", 
				Box(5, 180, 530, 455));
		button_addMod = new Button("Add module..."d, "button_addMod", Box(535, 20, 635, 40));
		button_remMod = new Button("Remove module"d, "button_remMod", Box(535, 45, 635, 65));
		button_setup = new Button("Settings and Presets..."d, "button_setup", Box(535, 70, 635, 90));
		button_audNode = new Button("Add audio node"d, "button_audNode", Box(535, 180, 635, 200));
		//button_midiNode = new Button("Add MIDI node"d, "button1", Box(535, 205, 635, 225));
		button_remNode = new Button("Remove node"d, "button_remNode", Box(535, 230, 635, 250));
	}
}
