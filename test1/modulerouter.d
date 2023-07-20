module test1.modulerouter;

import pixelperfectengine.concrete.window;
import pixelperfectengine.audio.base.config;

import test1.app;
import test1.editorevents;

import std.conv : to;

public class ModuleRouter : Window {
	ListView listView_modules;
	ListView listView_routing;
	Button button_addMod;
	Button button_remMod;
	Button button_preset;
	Button button_sampleman;
	Button button_audNode;
	Button button_midiNode;
	Button button_remNode;
	AudioDevKit adk;
	public this(AudioDevKit adk){
		super(Box(0, 16, 640, 480), "Modules and Routing");
		listView_modules = new ListView(new ListViewHeader(16, [256, 256], ["Type", "Name"]), null, "listView_modules", 
				Box(5, 20, 530, 175));
		listView_routing = new ListView(new ListViewHeader(16, [256, 256], ["From", "To"]), null, "listView_routing", 
				Box(5, 180, 530, 455));
		button_addMod = new Button("Add module..."d, "button_addMod", Box(535, 20, 635, 40));
		button_remMod = new Button("Remove module"d, "button_remMod", Box(535, 45, 635, 65));
		button_preset = new Button("Presets..."d, "button_preset", Box(535, 70, 635, 90));
		button_sampleman = new Button("Samples..."d, "button_samples", Box(535, 95, 635, 115));
		button_audNode = new Button("Add audio node"d, "button_audNode", Box(535, 180, 635, 200));
		//button_midiNode = new Button("Add MIDI node"d, "button1", Box(535, 205, 635, 225));
		button_remNode = new Button("Remove node"d, "button_remNode", Box(535, 205, 635, 225));
		button_addMod.onMouseLClick = &button_addMod_onClick;
		button_audNode.onMouseLClick = &button_addNode_onClick;
		button_preset.onMouseLClick = &button_preset_onClick;
		button_sampleman.onMouseLClick = &button_sampleman_onClick;
		listView_modules.editEnable = true;
		listView_modules.onTextInput = &listView_modules_onTextEdit;
		listView_modules.onItemSelect = &listView_modules_onItemSelect;
		listView_routing.editEnable = true;
		listView_routing.multicellEditEnable = true;
		listView_routing.onTextInput = &listView_routing_onTextEdit;
		addElement(listView_modules);
		addElement(listView_routing);
		addElement(button_addMod);
		addElement(button_remMod);
		addElement(button_sampleman);
		addElement(button_preset);
		addElement(button_audNode);
		//addElement(button_midiNode);
		addElement(button_remNode);

		this.adk = adk;
		refreshRoutingTable();
		refreshModuleList();
	}
	public void refreshRoutingTable() {
		ModuleConfig mcfg = adk.mcfg;
		string[2][] routingTable = mcfg.getRoutingTable;
		listView_routing.clear();
		foreach (string[2] key; routingTable) {
			listView_routing ~= new ListViewItem(16, [key[0].to!dstring, key[1].to!dstring], 
					[TextInputFieldType.ASCIIText, TextInputFieldType.ASCIIText]);
		}
		listView_routing.refresh();
	}
	public void refreshModuleList() {
		ModuleConfig mcfg = adk.mcfg;
		string[2][] moduleList = mcfg.getModuleList;
		listView_modules.clear();
		foreach (string[2] key; moduleList) {
			listView_modules ~= new ListViewItem(16, [key[0].to!dstring, key[1].to!dstring,], 
				[TextInputFieldType.None, TextInputFieldType.ASCIIText]);
		}
	}
	private void listView_modules_onItemSelect(Event e) {
		ListViewItem item = cast(ListViewItem)e.aux;
		if (item[1].getText != "Rename me!") {
			ModuleConfig mcfg = adk.mcfg;
			adk.selectedModID = item[1].getText.to!string;
			adk.selectedModule = mcfg.getModule(adk.selectedModID);
		}
	}
	private void button_addMod_onClick(Event e) {
		handler.addPopUpElement(new PopUpMenu([new PopUpMenuElement("qm816", "QM816"), new PopUpMenuElement("pcm8", "PCM8")], 
				"moduleSelector", &onModuleTypeSelect));
	}
	private void button_preset_onClick(Event e) {
		adk.openPresetEditor();
	}
	private void onModuleTypeSelect(Event e) {
		MenuEvent me = cast(MenuEvent)e;
		listView_modules ~= new ListViewItem(16, [me.itemSource.to!dstring, "Rename me!"], 
				[TextInputFieldType.None, TextInputFieldType.ASCIIText]);
		listView_modules.refresh();
		//adk.eventStack.addToTop(new AddModuleEvent(adk.mcfg, me.itemSource, me.itemSource));
	}
	private void button_addNode_onClick(Event e) {
		listView_routing ~= new ListViewItem(16, ["!NONE!", "!NONE!"], 
				[TextInputFieldType.ASCIIText, TextInputFieldType.ASCIIText]);
		listView_routing.refresh();
	}
	private void button_sampleman_onClick(Event e) {
		import test1.sampleman;
		adk.wh.addWindow(new SampleMan(adk));
	}
	private void listView_modules_onTextEdit(Event e) {
		//CellEditEvent ce = cast(CellEditEvent)e;
		ListViewItem item = cast(ListViewItem)e.aux;
		adk.eventStack.addToTop(new AddModuleEvent(adk.mcfg, item[0].getText().to!string, item[1].getText().to!string));
	}
	private void listView_routing_onTextEdit(Event e) {
		ListViewItem item = cast(ListViewItem)e.aux;
		if (item[0].getText != "!NONE!" && item[1].getText != "!NONE!") {
			adk.eventStack.addToTop(new AddRoutingNodeEvent(adk.mcfg, item[0].getText().to!string, item[1].getText().to!string));
		}
	}
}
