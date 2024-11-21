module test1.midiseq;

import pixelperfectengine.concrete.window;

import pixelperfectengine.audio.base.midiseq : SequencerM1;
import pixelperfectengine.audio.m2.seq;
import test1.app;

const ushort[128] pianoRollPositions = [
//    0   1   2   3   4   5   6   7   8   9   A   B   C   D   E   F
	939,932,925,918,911,903,896,889,882,875,868,861,853,846,839,832, //0
	825,817,810,803,796,789,782,775,767,760,753,746,739,731,724,717, //1
	710,703,696,689,681,674,667,660,653,645,638,631,624,617,610,603, //2
	595,588,581,574,567,559,552,545,538,531,524,517,509,502,495,488, //3
	481,473,466,459,452,445,438,431,423,416,409,402,395,387,380,373, //4
	366,359,352,345,337,330,323,316,309,301,294,287,280,273,266,259, //5
	251,244,237,230,223,215,208,201,194,187,180,173,165,158,151,144, //6
	137,129,122,115,108,101,094,087,079,072,065,058,051,043,036,029, //7
];

public class PianoRoll : WindowElement {
	int vScrollAmount;
	protected static enum ZOOMOUT = 1<<16;	///Zoomout mode flag: view is vertically zoomed out to allow a better overview.
	Bitmap8Bit pianoRollLarge;
	Bitmap8Bit pianoRollSmall;
	public this(string source, Box position) {
		this.position = position;
		this.source = source;
	}
	public override void draw() {
		if (flags & ZOOMOUT) {
			parent.bitBLT(Point(position.left, position.top), pianoRollSmall, Box.bySize(0, 0, 16,
					position.height >= 256 ? 256 : position.height));
		} else {
			parent.bitBLT(Point(position.left, position.top), pianoRollLarge, Box.bySize(0, vScrollAmount, 16, position.height));
		}
		if (onDraw !is null) {
			onDraw();
		}
	}
}

public class NoteEditor : WindowElement {
	long hScrollAmount;
	int vScrollAmount;
	protected static enum ZOOMOUT = 1<<16;	///Zoomout mode flag: view is vertically zoomed out to allow a better overview.
	public this(string source, Box position) {
		this.position = position;
		this.source = source;
	}
	private void drawNote(Box notePos, ubyte[] color) {
		//bail out if note out of boundary
		if (notePos.left > position.right) return;
		if (notePos.right < position.left) return;
		if (notePos.top > position.bottom) return;
		if (notePos.bottom < position.top) return;
		//limit note within the borders of the note editor
		with (notePos) {
			left = notePos.left < position.left + 1 ? position.left + 1 : notePos.left;
			right = notePos.right > position.right - 1 ? position.right - 1 : notePos.right;
			top = notePos.top < position.top + 1 ? position.top + 1 : notePos.top;
			bottom = notePos.bottom > position.bottom - 1 ? position.bottom - 1 : notePos.bottom;
		}
		for (int i = notePos.top ; i <= notePos.bottom ; i++) {
			parent.drawLine(Point(notePos.left, i), Point(notePos.right, i), color[i % color.length]);
		}
	}
	public override void draw() {
		if (onDraw !is null) {
			onDraw();
		}
	}
}

public class EnvelopEditor : WindowElement {
	struct EnvelopCmd {
		ushort device;
		ubyte channel;
		ubyte targetType;
		ushort target;
		uint value;
	}
	long hScrollAmount;
	protected static enum CMDMODE = 1<<16;	///Command mode flag: lists command events instead of displaying the selected envelop slot
	public this(string source, Box position) {
		this.position = position;
		this.source = source;
	}
	public override void draw() {
// 		if (flags & CMDMODE) {
//
// 		} else {
//
// 		}
		if (onDraw !is null) {
			onDraw();
		}
	}
}

public class RhythmNotation : WindowElement {
	struct Marker {
		long from;
		long to;
		float bpm;
		ushort meterUpper;
		ushort meterLower;
	}

	long hScrollAmount;
	public this(string source, Box position) {
		this.position = position;
		this.source = source;
	}
	public override void draw() {
	}
}

public class SequencerCtrl : Window {
	MenuBar menuBar;
	SmallButton button_new;
	SmallButton button_load;
	SmallButton button_save;
	SmallButton button_play;
	SmallButton button_stop;
	AudioDevKit adk;

	public this(AudioDevKit adk) {
		this.adk = adk;
		super(Box.bySize(0, 0, 640, 448), "Sequencer");

		button_load = new SmallButton("loadB", "loadA", "load", Box.bySize(0, 16, 16, 16));
		button_play = new SmallButton("playB", "playA", "play", Box.bySize(16, 16, 16, 16));
		button_stop = new SmallButton("stopB", "stopA", "stop", Box.bySize(32, 16, 16, 16));

		addElement(button_load);
		button_load.onMouseLClick = &button_load_onClick;
		addElement(button_play);
		button_play.onMouseLClick = &button_play_onClick;
		addElement(button_stop);
		button_stop.onMouseLClick = &button_stop_onClick;
	}
	protected void button_load_onClick(Event ev) {
		adk.onMIDILoad();
	}
	protected void button_play_onClick(Event ev) {
		adk.seqStart();

	}
	protected void button_stop_onClick(Event ev) {
		adk.seqStop();

	}
}
