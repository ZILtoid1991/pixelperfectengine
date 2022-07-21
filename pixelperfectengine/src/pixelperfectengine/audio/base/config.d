module pixelperfectengine.audio.base.config;

import sdlang;

import pixelperfectengine.audio.base.handler;
import pixelperfectengine.audio.base.modulebase;


/** 
 * Module and audio routin configurator.
 * Loads an SDL file, then configures the modules and sets up their routing, presets, etc.
 * See `modulesetup.md` on documentation about how the format works internally.
 */
public class ModuleConfig {
	protected Tag			root;
	protected ModuleManager	manager;
	public this(string src, ModuleManager manager) {
		root = parseSource(src);
		this.manager = manager;
	}
	public void loadConfig(string src) {
		root = parseSource(src);
	}
	public void parseConfig() {
		manager.suspendAudioThread();
		
		manager.runAudioThread();
	}
}