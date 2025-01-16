module test1.midiseq;

import pixelperfectengine.concrete.window;

import pixelperfectengine.audio.base.midiseq : SequencerM1;
import pixelperfectengine.audio.m2.seq;
import test1.app;
import collections.sortedlist;

const ushort[128] pianoRollPositionsZI = [
//    0   1   2   3   4   5   6   7   8   9   A   B   C   D   E   F
	910,903,896,889,882,874,867,860,853,846,839,832,824,817,810,803, //0
	796,788,781,774,767,760,753,746,738,731,724,717,710,702,695,688, //1
	681,674,667,660,652,645,638,631,624,616,609,602,595,588,581,574, //2
	566,559,552,545,538,530,523,516,509,502,495,488,480,473,466,459, //3
	452,444,437,430,423,416,409,402,394,387,380,373,366,358,351,344, //4
	337,330,323,316,308,301,294,287,280,272,265,258,251,244,237,230, //5
	222,215,208,201,194,186,179,172,165,158,151,144,136,129,122,115, //6
	108,100,093,086,079,072,065,058,050,043,036,029,022,014,007,000, //7
];
const ushort[128] pianoRollPositionsZO = [
//    0   1   2   3   4   5   6   7   8   9   A   B   C   D   E   F
	371,368,365,362,359,356,353,350,347,344,341,338,335,332,329,326, //0
	323,320,317,314,311,308,305,302,299,296,293,290,287,284,281,278, //1
	275,272,269,266,263,260,257,254,251,248,245,242,239,236,233,230, //2
	227,224,221,218,215,212,219,216,213,210,207,204,201,198,195,192, //3
	189,186,183,180,177,174,171,168,165,162,159,156,153,150,147,144, //4
	141,138,135,132,129,126,123,120,117,114,111,108,105,102,099,096, //5
	093,090,087,084,081,078,075,072,069,066,063,060,057,054,051,048, //6
	045,042,039,036,033,030,027,024,021,018,015,012,009,006,003,000, //7
];

public class PianoRoll : WindowElement {
	int vScrollAmount;
	protected static enum ZOOMOUT = 1<<16;	///Zoomout mode flag: view is vertically zoomed out to allow a better overview.
	static Bitmap8Bit pianoRollLarge;
	static Bitmap8Bit pianoRollSmall;
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
	struct NoteCmd {
		long pos;
		uint dur;
		ushort devID;
		ubyte channel;
		ubyte note;
		ushort vel;
		ushort flags;
		static enum MIDI1_0 = 1<<0;
		int opCmp(NoteCmd rhs) @nogc @safe nothrow pure const {
			if (this.pos > rhs.pos) return 1;
			else if (this.pos < rhs.pos) return -1;
			return 0;
		}
	}
	SortedList!NoteCmd notes;
	int hScrollAmount;
	int vScrollAmount;
	int hDiv;
	MouseClickEvent prevMouseClickEvent;
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
		const screenWidth = position.width - 2;
		const hScrollRight = hScrollAmount + screenWidth;
		const screenHeight = position.height - 2;
		const vScrollBottom = vScrollAmount + screenHeight;
		const noteHeight = (flags & ZOOMOUT) != 0 ? 2 : 5;
		foreach (NoteCmd note; notes) {
			const posInPixels = pos / hDiv;
			const durInPixels = dur / hDiv;
			const endInPixels = posInPixels + durInPixels;
			const noteTop = (flags & ZOOMOUT) != 0 ? pianoRollPositionsZO[note.note] + 1 : pianoRollPositionsZI[note.note] + 1;
			const noteBottom = noteTop + noteHeight;
			if ((posInPixels < hScrollRight || endInPixels > hScrollAmount) && (noteBottom > vScrollAmount ||
					noteTop < vScrollBottom)) {
				drawNote(Box(posInPixels - hScrollAmount, noteTop - vScrollAmount, endInPixels - hScrollAmount,
						noteBottom - vScrollAmount), [cast(ubyte)(note.channel + 16), cast(ubyte)(note.devID + 16)]);
			} else if (posInPixels > hScrollRight) {
				break;
			}
		}
		if (onDraw !is null) {
			onDraw();
		}
	}
	public override void passMCE(MouseEventCommons mec, MouseClickEvent mce) {
		if (state != ElementState.Enabled) return;
		parent.requestFocus(this);

		if (mce.state) {
			switch (mce.button) {
			case MouseButtons.Left:		//Place note
				break;
			case MouseButtons.Middle:	//Delete note
				break;
			case MouseButtons.Right:	//Context menu
				break;
			default: break;
			}
		} else {
			switch (mce.button) {
			case MouseButtons.Left:		//Place note
				break;
			case MouseButtons.Middle:	//Delete note
				break;
			case MouseButtons.Right:	//Context menu
				break;
			default: break;
			}
		}

		draw;
	}
}

public class EnvelopEditor : WindowElement {
	struct EnvelopCmd {
		long pos;
		ushort device;
		ubyte channel;
		ubyte targetType;
		ushort target;
		uint value;
	}
	struct PatternCtrlCmd {
		long pos;
		M2Command cmd;
	}
	union DrawableCommand {
		EnvelopCmd ec;
		PatternCtrlCmd pcc;
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

public class DisplayProcessor {
	void processCommands() {
		// seek to the time position
		// clear display systems
		// process commands, then add them to the appropriate display systems
	}
}

public class SequencerCtrl : Window {
	MenuBar menuBar;
	SmallButton button_new;
	SmallButton button_load;
	SmallButton button_save;
	SmallButton button_play;
	SmallButton button_stop;
	HorizScrollBar seeker;
	VertScrollBar vsb_notes;
	AudioDevKit adk;

	public this(AudioDevKit adk) {
		this.adk = adk;
		resizableV = true;
		resizableH = true;
		minW = 320;
		minH = 240;
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
