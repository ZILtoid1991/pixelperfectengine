import pixelperfectengine.concrete.window; 
import pixelperfectengine.audio.base.modulebase;
import std.conv : to;

public class ModuleEditor : Window {
	ListView listView_presets;
	ListView listView_values;
	SmallButton[] smallButtons;
	//CheckBox	checkBox_globals;
	public this(dstring name) {
		super(Box(0, 0, 330, 330), name ~ " presets"d);
		listView_presets = new ListView(new ListViewHeader(16, [32, 32, 240], ["Bank" ,"Prg" ,"Name"]), null, 
				"listView_presets", Box(5, 20, 230, 100));
		listView_values = new ListView(new ListViewHeader(16, [200, 100], ["" ,"listView1" ,""]), null, "listView_values", 
				Box(5, 105, 325, 325));
		smallButtons ~= new SmallButton("loadB", "loadA", "load", Box(236, 20, 241, 35));
		smallButtons ~= new SmallButton("saveB", "saveA", "save", Box(242, 20, 257, 35));
		smallButtons ~= new SmallButton("importB", "importA", "import", Box(258, 20, 273, 36));
		smallButtons ~= new SmallButton("exportB", "exportA", "export", Box(274, 20, 289, 36));

		smallButtons ~= new SmallButton("addB", "addA", "add", Box(236, 36, 241, 51));
		smallButtons ~= new SmallButton("removeB", "removeA", "remove", Box(242, 36, 257, 51));
		smallButtons ~= new SmallButton("globalsB", "globalsA", "globals", Box(258, 36, 273, 51));
		smallButtons ~= new SmallButton("macroB", "macroA", "macro", Box(274, 36, 289, 51));

		listView_presets.editEnable = true;
		addElement(listView_presets);
		listView_presets.onItemSelect = &listView_presets_onSelect;
		listView_presets.onTextInput = &listView_presets_onTextEdit;
		listView_values.editEnable = true;
		addElement(listView_values);
		listView_values.onItemSelect = &listView_values_onSelect;
		listView_values.onTextInput = &listView_values_onTextEdit;
		foreach (SmallButton key; smallButtons) {
			addElement(key);
			key.onMouseLClick = &smallButtons_onClick;
		}
	}
	protected void smallButtons_onClick(Event ev) {
		SmallButton sender = cast(SmallButton)ev.sender;
	}
	protected void listView_presets_onSelect(Event ev) {

	}
	protected void listView_presets_onTextEdit(Event ev) {

	}
	protected void listView_values_onSelect(Event ev) {

	}
	protected void listView_values_onTextEdit(Event ev) {

	}
}
