module test1.modulerouter;

import pixelperfectengine.concrete.window;

import test1.app;

public class ModuleRouter : Window {
	ListView listView_modules;
	ListView listView_routing;
	Button button_addMod;
	Button button_remMod;
	Button button_preset;
	Button button_setup;
	Button button_audNode;
	Button button_midiNode;
	Button button_remNode;
	public this(AudioDevKit adk){
		super(Box(0, 0, 640, 480), "Modules and Routing");
		listView_modules = new ListView(new ListViewHeader(16, [64, 256, 256], ["ID", "Type", "Name"]), null, "listView0", 
				Box(5, 20, 530, 175));
		listView_routing = new ListView(new ListViewHeader(16, [64, 128, 125], ["Num", "From", "To"]), null, "listView1", 
				Box(5, 180, 530, 455));
		button_addMod = new Button("Add module..."d, "button_addMod", Box(535, 20, 635, 40));
		button_remMod = new Button("Remove module"d, "button_remMod", Box(535, 45, 635, 65));
		button_preset = new Button("Presets..."d, "button_preset", Box(535, 70, 635, 90));
		button_setup = new Button("Settings..."d, "button_setup", Box(535, 95, 635, 115));
		button_audNode = new Button("Add audio node"d, "button_audNode", Box(535, 180, 635, 200));
		//button_midiNode = new Button("Add MIDI node"d, "button1", Box(535, 205, 635, 225));
		button_remNode = new Button("Remove node"d, "button_remNode", Box(535, 205, 635, 225));

		addElement(listView_modules);
		addElement(listView_routing);
		addElement(button_addMod);
		addElement(button_remMod);
		addElement(button_setup);
		addElement(button_preset);
		addElement(button_audNode);
		//addElement(button_midiNode);
		addElement(button_remNode);
	}
}
