module test1.preseteditor;

import pixelperfectengine.concrete.window; 
import pixelperfectengine.audio.base.modulebase;
import std.conv : to;
import std.utf : toUTF32, toUTF8;
import std.algorithm.searching : countUntil;
import pixelperfectengine.audio.base.config;

import test1.app;
import test1.editorevents;

public class PresetEditor : Window {
	ListView listView_presets;
	ListView listView_values;
	SmallButton[] smallButtons;
	CheckBox checkBox_Globals;
	AudioModule editedModule;
	string editedModID;
	AudioDevKit adk;
	MValue[] params;
	int[] paramIDs;
	int presetID;
	string presetName;
	
	//CheckBox	checkBox_globals;
	public this(AudioDevKit adk) {
		super(Box(0, 0, 330, 330), "`" ~ toUTF32(adk.selectedModID) ~ "` presets"d);
		listView_presets = new ListView(new ListViewHeader(16, [32, 32, 240], ["Bank" ,"Prg" ,"Name"]), null, 
				"listView_presets", Box(5, 20, 230, 100));
		listView_values = new ListView(new ListViewHeader(16, [200, 100], ["Name" ,"Value"]), null, "listView_values", 
				Box(5, 105, 325, 325));
		//smallButtons ~= new SmallButton("loadB", "loadA", "load", Box(236, 20, 251, 35));
		//smallButtons ~= new SmallButton("saveB", "saveA", "save", Box(252, 20, 267, 35));
		//smallButtons ~= new SmallButton("importB", "importA", "import", Box(268, 20, 283, 36));
		//smallButtons ~= new SmallButton("exportB", "exportA", "export", Box(284, 20, 299, 36));

		smallButtons ~= new SmallButton("addB", "addA", "add", Box(236, 36, 251, 51));
		smallButtons ~= new SmallButton("removeB", "removeA", "remove", Box(252, 36, 267, 51));
		checkBox_Globals = new CheckBox("globalsB", "globalsA", "globals", Box(268, 36, 283, 51));
		//smallButtons ~= new SmallButton("macroB", "macroA", "macro", Box(284, 36, 299, 51));

		listView_presets.editEnable = true;
		listView_presets.multicellEditEnable = true;
		addElement(listView_presets);
		listView_presets.onItemSelect = &listView_presets_onSelect;
		listView_presets.onTextInput = &listView_presets_onTextEdit;
		listView_values.editEnable = true;
		addElement(checkBox_Globals);
		checkBox_Globals.onToggle = &checkBox_Globals_onToggle;
		addElement(listView_values);
		listView_values.onItemSelect = &listView_values_onSelect;
		listView_values.onTextInput = &listView_values_onTextEdit;
		foreach (SmallButton key; smallButtons) {
			addElement(key);
			key.onMouseLClick = &smallButtons_onClick;
		}
		this.editedModule = adk.selectedModule;
		this.editedModID = adk.selectedModID;
		this.adk = adk;
		params = editedModule.getParameters;
		loadPresets();
	}
	private void fillValues() {
		StyleSheet ss = globalDefaultStyle;
		paramIDs.length = 0;
		listView_values.clear();
		foreach (MValue key; params) {
			const char fc = key.name.length ? key.name[0] : ' ';
			if ((fc == '_' && checkBox_Globals.isChecked) || (fc != '_' && !checkBox_Globals.isChecked)) {
				ListViewItem.Field[] fields = 
						[ListViewItem.Field(new Text(toUTF32(key.name), ss.getChrFormatting("listViewItem")), null)];
				final switch (key.type) with (MValueType) {
					case init:
						assert(0, "Something went really wrong...");
					case String:
						dstring val = toUTF32(editedModule.readParam_string(presetID, key.id));
						fields ~= 
								ListViewItem.Field(new Text(val, ss.getChrFormatting("listViewItem")), null, TextInputFieldType.ASCIIText);
						break;
					case Int32, Boolean:
						dstring val = to!dstring(editedModule.readParam_int(presetID, key.id));
						fields ~= 
								ListViewItem.Field(new Text(val, ss.getChrFormatting("listViewItem")), null, TextInputFieldType.Integer);
						break;
					case Int64:
						dstring val = to!dstring(editedModule.readParam_long(presetID, key.id));
						fields ~= 
								ListViewItem.Field(new Text(val, ss.getChrFormatting("listViewItem")), null, TextInputFieldType.Integer);
						break;
					case Float:
						dstring val = to!dstring(editedModule.readParam_double(presetID, key.id));
						fields ~= 
								ListViewItem.Field(new Text(val, ss.getChrFormatting("listViewItem")), null, TextInputFieldType.Decimal);
						break;
				}
				listView_values ~= new ListViewItem(16, fields);
				paramIDs ~= key.id;
			}
		}
		listView_values.refresh();
	}
	private void loadPresets() {
		listView_presets.clear();
		foreach (key; adk.mcfg.getPresetList(adk.selectedModID)) {
			if (key.id < (1<<21))
				listView_presets ~= new ListViewItem(16, [(key.id>>7).to!dstring, (key.id & 127).to!dstring, toUTF32(key.name)], 
						[TextInputFieldType.DecimalP, TextInputFieldType.DecimalP, TextInputFieldType.Text]);
		}
		listView_presets.refresh();
	}
	protected void checkBox_Globals_onToggle(Event ev) {
		if (checkBox_Globals.isChecked) {
			presetID = 1<<21;
			presetName = "globals";
		} else if (listView_presets.selectedElement() !is null) {
			if (listView_presets.selectedElement()[0].getText() != "!" && listView_presets.selectedElement()[1].getText() != "!") {
				presetID = (to!int(listView_presets.selectedElement()[0].getText())<<7) || 
						(to!int(listView_presets.selectedElement()[1].getText()));
			}
			presetName = toUTF8(listView_presets.selectedElement()[2].getText());
		}
		fillValues();
	}
	protected void smallButtons_onClick(Event ev) {
		SmallButton sender = cast(SmallButton)ev.sender;
		switch (sender.getSource) {
			case "add":
				listView_presets ~= new ListViewItem(16, ["!", "!", ""], 
						[TextInputFieldType.DecimalP, TextInputFieldType.DecimalP, TextInputFieldType.Text]);
				listView_presets.refresh();
				break;
			case "remove":
				if (presetID == 1<<21)
					adk.eventStack.addToTop(new RemovePresetEvent(adk.mcfg, editedModID, presetID));
				break;
			default:
				break;
		}
	}
	protected void listView_presets_onSelect(Event ev) {
		import midi2.types.structs;
		import midi2.types.enums;
		ListViewItem item = cast(ListViewItem)ev.aux;
		if (item[0].getText != "!" && item[1].getText != "!") {
			const uint bank = item[0].getText().to!uint;
			const uint preset = item[1].getText().to!uint;
			presetID = preset | (bank<<7);
			presetName = item[2].getText().toUTF8;
			fillValues();
			editedModule.midiReceive(UMP(MessageType.MIDI2, 0, MIDI2_0Cmd.PrgCh, 0), 
					(preset<<24) | (bank & 0x7F) | ((bank>>7)<<8));
			/* editedModule.midiReceive(UMP(MessageType.MIDI2, 0, MIDI2_0Cmd.PrgCh, 0), 
					((presetID & 127)<<24) | ((presetID>>7) & 0x7F) | ((presetID>>14)<<8)); */
		}
	}
	protected void listView_presets_onTextEdit(Event ev) {
		ListViewItem item = cast(ListViewItem)ev.aux;
		if (item[0].getText != "!" && item[1].getText != "!") {
			const uint bank = item[0].getText().to!uint;
			const uint preset = item[1].getText().to!uint;
			presetID = preset | (bank<<7);
			presetName = item[2].getText().toUTF8;
		}
	}
	protected void listView_values_onSelect(Event ev) {

	}
	protected void listView_values_onTextEdit(Event ev) {
		CellEditEvent cee = cast(CellEditEvent)ev;
		MValue currparam = params[countUntil!"a.id == b"(params, paramIDs[cee.row])];
		dstring str = listView_values[cee.row][1].text.toDString;
		ModuleConfig mcfg = adk.mcfg;
		final switch (currparam.type) with (MValueType) {
			case init:
				break;
			case String:
				editedModule.writeParam_string(presetID, currparam.id, toUTF8(str));
				string newVal = editedModule.readParam_string(presetID, currparam.id); //str = toUTF32(editedModule.readParam_string(presetID, currparam.id));
				str = toUTF32(newVal);
				listView_values[cee.row] = new ListViewItem(16, [toUTF32(currparam.name), str], 
						[TextInputFieldType.None, TextInputFieldType.Text]);
				if (currparam.idType)
					adk.eventStack.addToTop(new EditPresetParameterEvent(mcfg, newVal, currparam.id, editedModID, presetID, 
							presetName));
				else
					adk.eventStack.addToTop(new EditPresetParameterEvent(mcfg, newVal, currparam.name, editedModID, presetID, 
							presetName));
				break;
			case Int32, Boolean:
				editedModule.writeParam_int(presetID, currparam.id, to!int(str));
				int newVal = editedModule.readParam_int(presetID, currparam.id); //str = to!dstring(editedModule.readParam_int(presetID, currparam.id));
				str = to!dstring(newVal);
				listView_values[cee.row] = new ListViewItem(16, [toUTF32(currparam.name), str], 
						[TextInputFieldType.None, TextInputFieldType.Integer]);
				if (currparam.idType)
					adk.eventStack.addToTop(new EditPresetParameterEvent(mcfg, newVal, currparam.id, editedModID, presetID, 
							presetName));
				else
					adk.eventStack.addToTop(new EditPresetParameterEvent(mcfg, newVal, currparam.name, editedModID, presetID, 
							presetName));
				break;
			case Int64:
				editedModule.writeParam_long(presetID, currparam.id, to!long(str));
				long newVal = editedModule.readParam_long(presetID, currparam.id); //str = to!dstring(editedModule.readParam_long(presetID, currparam.id));
				str = to!dstring(newVal);
				listView_values[cee.row] = new ListViewItem(16, [toUTF32(currparam.name), str], 
						[TextInputFieldType.None, TextInputFieldType.Integer]);
				if (currparam.idType)
					adk.eventStack.addToTop(new EditPresetParameterEvent(mcfg, newVal, currparam.id, editedModID, presetID, 
							presetName));
				else
					adk.eventStack.addToTop(new EditPresetParameterEvent(mcfg, newVal, currparam.name, editedModID, presetID, 
							presetName));
				break;
			case Float:
				editedModule.writeParam_double(presetID, currparam.id, to!double(str));
				double newVal = editedModule.readParam_double(presetID, currparam.id); //str = to!dstring(editedModule.readParam_double(presetID, currparam.id));
				str = to!dstring(newVal);
				listView_values[cee.row] = new ListViewItem(16, [toUTF32(currparam.name), str], 
						[TextInputFieldType.None, TextInputFieldType.Decimal]);
				if (currparam.idType)
					adk.eventStack.addToTop(new EditPresetParameterEvent(mcfg, newVal, currparam.id, editedModID, presetID, 
							presetName));
				else
					adk.eventStack.addToTop(new EditPresetParameterEvent(mcfg, newVal, currparam.name, editedModID, presetID, 
							presetName));
				break;
		}
		//listView_values[cee.row][1].text.text = str;
		import midi2.types.structs;
		import midi2.types.enums;
		if (!checkBox_Globals.isChecked)
			editedModule.midiReceive(UMP(MessageType.MIDI2, 0, MIDI2_0Cmd.PrgCh, 0), 
					((presetID & 127)<<24) | ((presetID>>7) & 0x7F) | ((presetID>>14)<<8));
		//listView_values.refresh();
	}
}
