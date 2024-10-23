
import pixelperfectengine.system.common;
import editor;
import std.algorithm;
import std.conv;

int main(string[] args) {
	int guiScaling = 2;
    foreach (string arg ; args) {
		if (arg.startsWith("--ui-scaling=")) {
			try {
				guiScaling = arg[13..$].to!int;
			} catch (Exception e) {

			}
		}
	}
	Editor e = new Editor(guiScaling);
	e.whereTheMagicHappens();

    return 0;
}
