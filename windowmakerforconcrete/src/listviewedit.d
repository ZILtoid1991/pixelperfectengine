import pixelperfectengine.concrete.window; 
import editorEvents;
import newsdlang;
import std.conv : to;
import std.utf;

public class ListViewEditor : Window {
	ListView listView_headerEdit;
	Button button_add;
	Button button_remove;
	Button button_apply;
	string target;
	public this(string target){
		this.target = target;
		super(Box(0, 0, 340, 325), "ListView Header Editor");
		listView_headerEdit = new ListView(new ListViewHeader(16, [48 ,400], ["Width" ,"Text"]), null, "listView0", 
				Box(5, 20, 235, 320));
		button_add = new Button("Add Entry"d, "button0", Box(240, 20, 335, 40));
		button_remove = new Button("Remove Entry"d, "button0", Box(240, 45, 335, 65));
		button_apply = new Button("Apply"d, "button0", Box(240, 300, 335, 320));

		listView_headerEdit.editEnable = true;
		listView_headerEdit.multicellEditEnable = true;
		DLTag header = wserializer.getTag(target, "header");
		button_add.onMouseLClick = &button_add_onClick;
		button_remove.onMouseLClick = &button_remove_onClick;
		button_apply.onMouseLClick = &button_apply_onClick;
		addElement(button_add);
		addElement(button_remove);
		addElement(button_apply);
		foreach (DLTag key; header.tags) {
			listView_headerEdit += new ListViewItem(16, [key.values[1].get!int().to!dstring(), 
					toUTF32(key.values[0].get!string)], [TextInputFieldType.DecimalP, TextInputFieldType.Text]);
		}
		addElement(listView_headerEdit);
	}
	/* private void listView_headerEdit_textEdit(Event ev) {
		CellEditEvent ceev = cast(CellEditEvent)ev;
	} */
	private void button_add_onClick(Event ev) {
		const int pos = listView_headerEdit.value;
		if (pos >= 0)
			listView_headerEdit.insertAt(pos, new ListViewItem(16, ["40", "col"], 
					[TextInputFieldType.DecimalP, TextInputFieldType.Text]));
		listView_headerEdit.draw();
	}
	private void button_remove_onClick(Event ev) {
		const int pos = listView_headerEdit.value;
		if (pos >= 0)
			listView_headerEdit.removeEntry(pos);
		listView_headerEdit.draw();
	}
	private void button_apply_onClick(Event ev) {
		DLElement[] headerTags;
		dstring[] texts;
		int[] widths;
		headerTags.reserve = listView_headerEdit.numEntries;
		texts.reserve = listView_headerEdit.numEntries;
		widths.reserve = listView_headerEdit.numEntries;
		for (int i ; i < listView_headerEdit.numEntries ; i++) {
			headerTags ~= new DLTag(null, null, [new DLValue(toUTF8(listView_headerEdit[i][1].text.text)),
					new DLValue(to!int(listView_headerEdit[i][0].text.text))]);
			texts ~= listView_headerEdit[i][1].text.text;
			widths ~= to!int(listView_headerEdit[i][0].text.text);
		}
		ListViewHeader newHeader = new ListViewHeader(16, widths, texts);
		editorTarget.eventStack.addToTop(new ListViewHeaderEditEvent(headerTags, newHeader, target));
		close();
	}
}
