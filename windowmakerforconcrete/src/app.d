module app;

import pixelperfectengine.system.common;
import editor;
import std.algorithm;
import std.conv;
import pixelperfectengine.system.file;

int main(string[] args) {
	int guiScaling = 2;
    foreach (string arg ; args[1..$]) {
		if (arg.startsWith("--ui-scaling=")) {
			try {
				guiScaling = arg[13..$].to!int;
			} catch (Exception e) {

			}
		} else if (arg.startsWith("--shadervers=")) {
			pathSymbols["SHDRVER"] = arg[13..$];
		}

	}
	Editor e = new Editor(guiScaling);
	e.whereTheMagicHappens();

    return 0;
}
