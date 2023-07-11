module test1.editorevents;

import pixelperfectengine.concrete.eventchainsystem;
import pixelperfectengine.audio.base.modulebase;
import pixelperfectengine.audio.base.config;
import sdlang : Tag, Value;
import collections.commons : defaultHash;
/**
 * Adds a module to the module configuration.
 */
public class AddModuleEvent : UndoableEvent {
	Tag backup;
	ModuleConfig mcfg;
	string type;
	string name;
	public this(ModuleConfig mcfg, string type, string name) {
		this.mcfg = mcfg;
		this.type = type;
		this.name = name;
	}

	public void redo() {
		if (backup) {
			mcfg.addModule(backup);
		} else {
			mcfg.addModule(type, name);
		}
	}

	public void undo() {
		backup = mcfg.removeModule(name);
	}
}
public class RenameModuleEvent : UndoableEvent {
	ModuleConfig mcfg;
	string oldName;
	string newName;
	public this(ModuleConfig mcfg, string oldName, string newName) {
		this.mcfg = mcfg;
		this.oldName = oldName;
		this.newName = newName;
	}

	public void redo() {
		mcfg.renameModule(oldName, newName);
	}

	public void undo() {
		mcfg.renameModule(newName, oldName);
	}
}
/**
 * Deletes a module from the audio configuration while holding a backup of it.
 */
public class DeleteModuleEvent : UndoableEvent {
	Tag backup;
	ModuleConfig mcfg;
	string name;
	public this(ModuleConfig mcfg, string name) {
		this.mcfg = mcfg;
		this.name = name;
	}
	public void redo() {
		backup = mcfg.removeModule(name);
	}
	public void undo() {
		mcfg.addModule(backup);
	}
}
/**
 * Edits or adds a preset parameter to the audio configuration, also edits the one in the module.
 */
public class EditPresetParameterEvent : UndoableEvent {
	ModuleConfig mcfg;
	Value oldVal, newVal;
	Value paramID;
	string modID;
	int presetID;
	string presetName;
	/* AudioModule mod; */
	public this(VT, PT)(ModuleConfig mcfg, VT newVal, PT paramID, string modID, int presetID, string presetName, 
			/* AudioModule mod */) {
		this.mcfg = mcfg;
		this.newVal = Value(newVal);
		this.paramID = Value(paramID);
		this.modID = modID;
		this.presetID = presetID;
		this.presetName = presetName;
		/* this.mod = mod; */
		/* if (mod !is null) {
			if (newVal.peek!int) {
				oldVal = Value(mod.readParam_int(presetID, _paramID));
			} else if (newVal.peek!long) {
				oldVal = Value(mod.readParam_long(presetID, _paramID));
			} else if (newVal.peek!double) {
				oldVal = Value(mod.readParam_double(presetID, _paramID));
			} else {
				oldVal = Value(mod.readParam_string(presetID, _paramID));
			}
		} */
	}

	public void redo() {
		mcfg.editPresetParameter(modID, presetID, paramID, newVal, oldVal, presetName);
		/* if (mod !is null) {
			uint _paramID;
			if (paramID.peek!string) {
				_paramID = defaultHash(paramID.get!string);
			} else {
				_paramID = cast(uint)paramID.get!long;
			}
			if (newVal.peek!int) {
				mod.writeParam_int(presetID, _paramID, newVal.get!int);
			} else if (newVal.peek!long) {
				mod.writeParam_long(presetID, _paramID, newVal.get!long);
			} else if (newVal.peek!double) {
				mod.writeParam_double(presetID, _paramID, newVal.get!double);
			} else {
				mod.writeParam_string(presetID, _paramID, newVal.get!string);
			}
		} */
	}

	public void undo() {
		Value dummy;
		mcfg.editPresetParameter(modID, presetID, paramID, oldVal, dummy, presetName);
		/* if (mod !is null) {
			uint _paramID;
			if (paramID.peek!string) {
				_paramID = defaultHash(paramID.get!string);
			} else {
				_paramID = cast(uint)paramID.get!long;
			}
			if (oldVal.peek!int) {
				mod.writeParam_int(presetID, _paramID, oldVal.get!int);
			} else if (oldVal.peek!long) {
				mod.writeParam_long(presetID, _paramID, oldVal.get!long);
			} else if (oldVal.peek!double) {
				mod.writeParam_double(presetID, _paramID, oldVal.get!double);
			} else {
				mod.writeParam_string(presetID, _paramID, oldVal.get!string);
			}
		} */
	}
}
public class AddRoutingNodeEvent : UndoableEvent {
	ModuleConfig mcfg;
	string from, to;
	public this (ModuleConfig mcfg, string from, string to) {
		this.mcfg = mcfg;
		this.from = from;
		this.to = to;
	}
	public void redo() {
		mcfg.addRouting(from, to);
	}

	public void undo() {
		mcfg.removeRouting(from, to);
	}
}
public class RemovePresetEvent : UndoableEvent {
	ModuleConfig mcfg;
	string modID;
	int presetID;
	Tag backup;
	public this (ModuleConfig mcfg, string modID, int presetID) {
		this.mcfg = mcfg;
		this.modID = modID;
		this.presetID = presetID;
	}
	public void redo() {
		backup = mcfg.removePreset(modID, presetID);
	}

	public void undo() {
		mcfg.addPreset(modID, backup);
	}
}
public class AddSampleFile : UndoableEvent {

}
public class AddSampleSlice : UndoableEvent {

}
public class RemoveSample : UndoableEvent {
	
}