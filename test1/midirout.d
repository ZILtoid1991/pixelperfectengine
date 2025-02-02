module test1.midirout;

import std.conv : to;

import pixelperfectengine.concrete.window; 

import pixelperfectengine.audio.base.config;

public class MIDIRouting : Window {
	ListView listView0;
	SmallButton button_add;
	SmallButton button_remove;
	SmallButton button_moveUp;
	SmallButton button_moveDown;
	SmallButton button_save;

	ModuleConfig mcfg;
	public this(ModuleConfig mcfg){
		super(Box(0, 0, 285, 235), "New Window");
		listView0 = new ListView(new ListViewHeader(16, [40 ,223], ["Tr. Num" ,"Module Name"]), null, "listView0",
				Box(5, 20, 280, 210));
		listView0.editEnable = true;
		button_add = new SmallButton("addB", "addA", "button_add", Box.bySize(5, 215, 16, 16));
		button_remove = new SmallButton("removeB", "removeA", "button_remove", Box.bySize(5 + 16, 215, 16, 16));
		button_moveUp = new SmallButton("upArrowB", "upArrowA", "button_moveUp", Box.bySize(5 + 32, 215, 16, 16));
		button_moveDown = new SmallButton("downArrowB", "downArrowA", "button_moveDown", Box.bySize(5 + 48, 215, 16, 16));
		button_save = new SmallButton("saveButtonB", "saveButtonA", "button_save", Box.bySize(5 + 80, 215, 16, 16));

		this.addElement(listView0);
		this.addElement(button_add);
		this.addElement(button_remove);
		this.addElement(button_moveUp);
		this.addElement(button_moveDown);
		this.addElement(button_save);

		button_add.onMouseLClick = &button_add_onClick;
		button_remove.onMouseLClick = &button_remove_onClick;
		button_moveUp.onMouseLClick = &button_moveUp_onClick;
		button_moveDown.onMouseLClick = &button_moveDown_onClick;
		button_save.onMouseLClick = &onSave;

		this.mcfg = mcfg;
		
		foreach (size_t i, uint key; mcfg.midiRouting) {
			listView0 ~= new ListViewItem(16, [to!dstring(i), to!dstring(mcfg.modNames[key])], 
					[TextInputFieldType.None, TextInputFieldType.ASCIIText]);
		}
	}

	protected void refreshOrder() {
		for (int i ; i < listView0.numEntries ; i++) {
			listView0[i][0].text.text = to!dstring(i);
		}
		listView0.refresh();
	}

	protected void button_add_onClick(Event ev) {
		listView0.insertAt(listView0.value >= 0 ? listView0.value : 0, 
				new ListViewItem(16, [""d, ""d], [TextInputFieldType.None, TextInputFieldType.ASCIIText]));
		refreshOrder();
	}
	
	protected void button_remove_onClick(Event ev) {
		listView0.removeEntry(listView0.value);
		refreshOrder();
	}

	protected void button_moveUp_onClick(Event ev) {
		if (listView0.value > 0) {
			listView0.moveEntry(listView0.value, listView0.value - 1);
			refreshOrder();
		}
	}

	protected void button_moveDown_onClick(Event ev) {
		if (listView0.value < listView0.numEntries) {
			listView0.moveEntry(listView0.value, listView0.value + 1);
			refreshOrder();
		}
	}

	protected void onSave(Event ev) {
		uint[] newRouting;
		for (int i ; i < listView0.numEntries ; i++) {
			newRouting ~= cast(uint)mcfg.getModuleNum(to!string(listView0[i][1].getText));
		}
		mcfg.setMIDIrouting(newRouting);
		this.close();
	}
}
