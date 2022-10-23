module test1.editorevents;

import pixelperfectengine.concrete.eventchainsystem;
import pixelperfectengine.audio.base.modulebase;
import pixelperfectengine.audio.base.config;

public class AddModuleEvent : UndoableEvent {
    
    public this() {

    }

    public void redo() {
        
    }

    public void undo() {
        
    }
}
public class EditPresetParameterEvent : UndoableEvent {
    AudioModule mod;
    ModuleConfig mcfg;
    public this(AudioModule mod, ModuleConfig mcfg) {
        
    }

    public void redo() {
        
    }

    public void undo() {
        
    }
}