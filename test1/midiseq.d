/*******************************************
 * Authors: László Szerémi
 * PixelPerfectEngine/Test1 - MIDI Sequencer module
 *******************************************/

module test1.midiseq;

import std.utf : toUTF32;
import std.algorithm.searching : countUntil;
import std.algorithm.mutation : remove;

import pixelperfectengine.concrete.window;

import pixelperfectengine.audio.base.midiseq : SequencerM1;
import pixelperfectengine.audio.m2.seq;
import pixelperfectengine.audio.base.config;
import test1.app;
import collections.sortedlist;
import midi2.types.structs;
import midi2.types.enums;

const ushort[128] pianoRollPositionsZI = [
//    0   1   2   3   4   5   6   7   8   9   A   B   C   D   E   F
	910,903,896,889,882,874,867,860,853,846,839,832,824,817,810,803, //0
	796,788,781,774,767,760,753,746,738,731,724,717,710,702,695,688, //1
	681,674,667,660,652,645,638,631,624,616,609,602,595,588,581,574, //2
	566,559,552,545,538,530,523,516,509,502,495,488,480,473,466,459, //3
	452,444,437,430,423,416,409,402,394,387,380,373,366,358,351,344, //4
	337,330,323,316,308,301,294,287,280,272,265,258,251,244,237,230, //5
	222,215,208,201,194,186,179,172,165,158,151,144,136,129,122,115, //6
	108,100, 93, 86, 79, 72, 65, 58, 50, 43, 36, 29, 22, 14,  7,  0, //7
];
const ushort[128] pianoRollPositionsZO = [
//    0   1   2   3   4   5   6   7   8   9   A   B   C   D   E   F
	371,368,365,362,359,356,353,350,347,344,341,338,335,332,329,326, //0
	323,320,317,314,311,308,305,302,299,296,293,290,287,284,281,278, //1
	275,272,269,266,263,260,257,254,251,248,245,242,239,236,233,230, //2
	227,224,221,218,215,212,219,216,213,210,207,204,201,198,195,192, //3
	189,186,183,180,177,174,171,168,165,162,159,156,153,150,147,144, //4
	141,138,135,132,129,126,123,120,117,114,111,108,105,102, 99, 96, //5
	 93, 90, 87, 84, 81, 78, 75, 72, 69, 66, 63, 60, 57, 54, 51, 48, //6
	 45, 42, 39, 36, 33, 30, 27, 24, 21, 18, 15, 12,  9,  6,  3,  0, //7
];
public ubyte searchNote(int pos, bool type) {
	return cast(ubyte)(127 - countUntil(type ? pianoRollPositionsZI : pianoRollPositionsZO), cast(ushort)pos);
}
/**
 * Implements a piano roll display using the Concrete subsystem of the engine.
 */
public class PianoRoll : WindowElement {
	int vScrollAmount;
	HorizScrollBar hScrollRedirect;
	VertScrollBar vScrollRedirect;
	AudioModule selectedModule;
	ubyte selectedChannel;
	protected static enum ZOOMOUT = 1<<16;	///Zoomout mode flag: view is vertically zoomed out to allow a better overview.
	static Bitmap8Bit pianoRollLarge;
	static Bitmap8Bit pianoRollSmall;
	public this(string source, Box position) {
		this.position = position;
		this.source = source;
	}
	public override void draw() {
		parent.clearArea(position);
		if (flags & ZOOMOUT) {
			parent.bitBLT(Point(position.left, position.top), pianoRollSmall, Box.bySize(0, vScrollAmount, 32,
					position.height >= 384 ? 384 : position.height));
		} else {
			parent.bitBLT(Point(position.left, position.top), pianoRollLarge, Box.bySize(0, vScrollAmount, 32, position.height));
		}
		if (onDraw !is null) {
			onDraw();
		}
	}
	public bool zoomOut(bool val) {
		if (val) flags |= ZOOMOUT;
		else flags &= ~ZOOMOUT;
		return val;
	}
	public bool zoomOut() @safe @nogc pure nothrow {
		return (flags & ZOOMOUT) != 0;
	}
	public override void passMWE(MouseEventCommons mec, MouseWheelEvent mwe) {
		hScrollRedirect.passMWE(mec, mwe);
		vScrollRedirect.passMWE(mec, mwe);
	}
	public override void passMCE(MouseEventCommons mec, MouseClickEvent mce) {
		UMP cmdToSend;
		if (mce.state) cmdToSend = UMP(MessageType.MIDI2, selectedChannel>>4, MIDI2_0Cmd.NoteOn, selectedChannel & 0x0F);
		else cmdToSend = UMP(MessageType.MIDI2, selectedChannel>>4, MIDI2_0Cmd.NoteOff, selectedChannel & 0x0F);
		uint velocity = mce.y - position.left;
		if (selectedModule !is null) selectedModule.midiReceive(cmdToSend, 0x07FF_0000 | (velocity<<26));
	}
}
/// Stores data regarding
public struct RhythmNotationCmd {
	long pos;
	ushort upper = 4;
	ushort lower = 4;
	float bpm = 120.0;
	int opCmp(RhythmNotationCmd rhs) @nogc @safe nothrow pure const {
		return cast(int)((this.pos > rhs.pos) - (this.pos < rhs.pos));
	}
	bool opEquals(RhythmNotationCmd rhs) @nogc @safe nothrow pure const {
		return this.opCmp(rhs) == 0;
	}
	size_t toHash() @nogc @safe nothrow pure const {
		return 0;		///Take that serve-D!!!
	}
}

public struct NoteCmd {
	long pos;
	uint dur;
	uint auxField;
	ushort devID;
	ubyte channel;
	ubyte note;
	ushort vel;
	ushort flags;
	static enum MIDI1_0 = 1<<0;
	static enum AFTERTOUCH_CMD = 1<<1;
	static enum POLY_AFTERTOUCH_CMD = 1<<2;
	static enum AUX_EXPRESSION = 1<<3;
	static enum AUX_PITCHDATA = 1<<4;
	int opCmp(NoteCmd rhs) @nogc @safe nothrow pure const {
		return cast(int)((this.pos > rhs.pos) - (this.pos < rhs.pos));
	}
	bool opEquals(NoteCmd rhs) @nogc @safe nothrow pure const {
		return this.opCmp(rhs) == 0;
	}
	size_t toHash() @nogc @safe nothrow pure const {
		return 0;		///Take that serve-D!!!
	}
}

public class NoteEditor : WindowElement {

	alias NoteCmdList = SortedList!NoteCmd;
	NoteCmdList notes;	///Currently displayed notes
	NoteCmdList backUp;
	ulong ticsPerSecs = 48_000;
	int hScrollAmount;
	int vScrollAmount;
	int hDiv = 4096;	///Amount of ticks per horizontal pixel
	SortedList!RhythmNotationCmd rhtmNot;
	MouseClickEvent prevMouseClickEvent;
	HorizScrollBar hScrollRedirect;
	VertScrollBar vScrollRedirect;
	protected static enum ZOOMOUT = 1<<16;	///Zoomout mode flag: view is vertically zoomed out to allow a better overview.
	public this(Box position) {
		this.position = position;
		rhtmNot.put(RhythmNotationCmd.init);
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
	public void clearForHScroll(int scrollAmount) {
		// const int hScrollDelta = hScrollAmount - scrollAmount;
		const long newPosLeft = cast(long)scrollAmount * cast(long)hDiv;
		const long newPosRight = newPosLeft + (cast(long)(position.width - 2) * cast(long)hDiv);
		backUp = NoteCmdList.init;
		// if (hScrollDelta > 0) {	// Scrolling to the right
		foreach (NoteCmd note ; notes) {
			if ((note.pos < newPosLeft && note.pos + note.dur > newPosLeft) ||
					(note.pos < newPosRight && note.pos + note.dur > newPosRight)) {
				backUp.put(note);
			}
		}
		notes = NoteCmdList.init;
		// } else {

		// }
		hScrollAmount = scrollAmount;
	}
	public override void draw() {
		static ubyte[] ptrn0 = [0, 0, 0, 1, 1];
		static ubyte[] ptrn1 = [0, 1, 1];

		parent.clearArea(position);

		const screenWidth = position.width - 2;
		const hScrollRight = hScrollAmount + screenWidth;
		const screenHeight = position.height - 2;
		const vScrollBottom = vScrollAmount + screenHeight;
		const noteHeight = (flags & ZOOMOUT) != 0 ? 3 : 5;
		const notesBegin = cast(long)hScrollAmount * cast(long)hDiv;
		const notesEnd = cast(long)(hScrollAmount + screenWidth) * cast(long)hDiv;
		// const pixelTimebase = ticsPerSecs / hDiv;

		size_t rnBegin, rnEnd;

		for (size_t i ; i < rhtmNot.length ; i++) {
			RhythmNotationCmd r = rhtmNot[i];
			if (r.pos <= notesBegin) rnBegin = i;
			rnEnd = i;
			if (r.pos >= notesEnd) break;
		}
		ulong currPos;
		for (size_t i = rnBegin ; i <= rnEnd ; i++) {
			RhythmNotationCmd r = rhtmNot[i];
			//const rnBegin = r.pos / hDiv;
			const rnEndP = i != rnEnd ? rhtmNot[i + 1].pos : notesEnd;
			currPos = r.pos;
			const beatDur = (r.bpm * (4.0 / r.lower)) / 60.0;
			const ulong beatLength = cast(ulong)(ticsPerSecs * beatDur);
			for (int lineCntr ; currPos <= rnEndP ; currPos += beatLength, lineCntr++) {
				if (currPos < notesBegin) continue;
				const int xPos = cast(int)(currPos / hDiv) + position.left;
				parent.drawLinePattern(Point(xPos, position.top), Point(xPos, position.bottom), lineCntr % r.upper ? ptrn0 : ptrn1);
			}
		}

		foreach (NoteCmd note; notes) {
			const posInPixels = note.pos / hDiv;
			const durInPixels = note.dur / hDiv;
			const endInPixels = posInPixels + durInPixels;
			const noteTop = (flags & ZOOMOUT) != 0 ? pianoRollPositionsZO[note.note] + 1 : pianoRollPositionsZI[note.note] + 1;
			const noteBottom = noteTop + noteHeight;
			if ((posInPixels < hScrollRight || endInPixels > hScrollAmount) && (noteBottom > vScrollAmount ||
					noteTop < vScrollBottom)) {
				drawNote(Box(cast(int)(posInPixels - hScrollAmount), noteTop - vScrollAmount,
						cast(int)(endInPixels - hScrollAmount), noteBottom - vScrollAmount),
						[cast(ubyte)(note.channel + 192), cast(ubyte)(note.devID + 192), cast(ubyte)((note.vel>>9) + 128)]);
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
			case MouseButtons.Left:		//Place note/play note
				break;
			case MouseButtons.Middle:	//Delete note
				break;
			case MouseButtons.Right:	//Context menu
				break;
			default: break;
			}
		} else {
			switch (mce.button) {
			case MouseButtons.Left:		//Place note/stop note
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
	public override void passMWE(MouseEventCommons mec, MouseWheelEvent mwe) {
		hScrollRedirect.passMWE(mec, mwe);
		vScrollRedirect.passMWE(mec, mwe);
	}
}
public enum EnvCtrlCmdType : ushort {
	init,
	IMBCCtrlCmd,
	MIDICmd
}
public struct EnvCtrlCmd {
	long pos;
	int dur;
	ushort type;
	ushort device;
	union {
		M2Command imbcCtrlCmd;
		UMP midiCmd;
	}
	uint value;
	int opCmp(NoteCmd rhs) @nogc @safe nothrow pure const {
		return cast(int)((this.pos > rhs.pos) - (this.pos < rhs.pos));
	}
	bool opEquals(NoteCmd rhs) @nogc @safe nothrow pure const {
		return this.opCmp(rhs) == 0;
	}
	size_t toHash() @nogc @safe nothrow pure const {
		return 0;		///Take that serve-D!!!
	}
}
public class EnvelopEditor : WindowElement {

	long hScrollAmount;
	ulong ticsPerSecs = 48_000;
	int hDiv = 4096;
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

public class RhythmSelector : PopUpElement {
	protected static immutable Box NOTELEN_AREA = Box(0, 8, 127, 39);
	protected static immutable Box TUPLET_AREA = Box(0, 48, 127, 79);
	protected static immutable Box DOT_AREA = Box(0, 88, 127, 103);
	protected static immutable Box[] NOTELEN_TABLE = [Box(0, 8, 15, 23), Box(16, 8, 31, 23), Box(32, 8, 15, 23),
			Box(48, 8, 63, 23), Box(64, 8, 79, 23), Box(80, 8, 95, 23), Box(96, 8, 111, 23), Box(112, 8, 127, 23),
			Box(0, 24, 15, 39), Box(16, 24, 31, 39), Box(32, 24, 47, 39)];
	protected static immutable Box[] TUPLET_TABLE = [Box(0, 48, 15, 63), Box(16, 48, 31, 63), Box(32, 48, 15, 63),
			Box(48, 48, 63, 63), Box(64, 48, 79, 63), Box(80, 48, 95, 63), Box(96, 48, 111, 63), Box(112, 48, 127, 63),
			Box(0, 64, 15, 79), Box(16, 64, 31, 79), Box(32, 64, 15, 79),
			Box(48, 64, 63, 79), Box(64, 64, 79, 79), Box(80, 64, 95, 79), Box(96, 64, 111, 79), Box(112, 64, 127, 79)];
	protected static immutable Box[] DOT_TABLE = [Box(0, 88, 15, 95), Box(16, 88, 31, 95), Box(32, 88, 15, 95),
			Box(48, 88, 63, 95), Box(64, 88, 79, 95), Box(80, 88, 95, 95), Box(96, 88, 111, 95), Box(112, 88, 127,953),
			Box(0, 96, 15, 103)];
	public void delegate(int noleLen, int tuplet, int dots) eventDeleg;
	protected int noteLen;
	protected int tuplet;
	protected int dots;
	protected Point mouseMove;
	public this(int noleLen, int tuplet, int dots, void delegate(int noleLen, int tuplet, int dots) eventDeleg) {
		import pixelperfectengine.graphics.draw;
		this.noteLen = noteLen;
		this.tuplet = tuplet;
		this.dots = dots;
		this.eventDeleg = eventDeleg;
		output = new BitmapDrawer(128, 104);
	}
	private int searchAreas(immutable Box[] haysack, Point needle) @safe @nogc pure nothrow const {
		for (int i ; i < haysack.length ; i++) {
			if (haysack[i].isBetween(needle)) return i;
		}
		return -1;
	}
	public override void draw() {
		import pixelperfectengine.graphics.draw;
		StyleSheet ss = getStyleSheet();
		output.bitBLT(Point(0, 0), ss.getImage("ADKrhythmnot"), Box(0,0,127,103));
		output.drawBox(NOTELEN_TABLE[noteLen], ss.getColor("yellow"));
		output.drawBox(TUPLET_TABLE[tuplet], ss.getColor("yellow"));
		output.drawBox(DOT_TABLE[dots], ss.getColor("yellow"));
		if (NOTELEN_AREA.isBetween(mouseMove)) {
			const int areaNum = searchAreas(NOTELEN_TABLE, mouseMove);
			if (areaNum != -1) output.drawBox(NOTELEN_TABLE[areaNum], ss.getColor("select"));
		} else if (TUPLET_AREA.isBetween(mouseMove)) {
			const int areaNum = searchAreas(TUPLET_TABLE, mouseMove);
			if (areaNum != -1) output.drawBox(TUPLET_TABLE[areaNum], ss.getColor("select"));
		} else if (DOT_AREA.isBetween(mouseMove)) {
			const int areaNum = searchAreas(DOT_TABLE, mouseMove);
			if (areaNum != -1) output.drawBox(DOT_TABLE[areaNum], ss.getColor("select"));
		}
		parent.updateOutput(this);
	}
	public override void passMCE(MouseEventCommons mec, MouseClickEvent mce) {
		if (position.isBetween(mce.x, mce.y)) {
			mouseMove = Point(mce.x - position.left, mce.y - position.top);
			if (NOTELEN_AREA.isBetween(mouseMove)) {
				const int areaNum = searchAreas(NOTELEN_TABLE, mouseMove);
				if (areaNum != -1) noteLen = areaNum;
			} else if (TUPLET_AREA.isBetween(mouseMove)) {
				const int areaNum = searchAreas(TUPLET_TABLE, mouseMove);
				if (areaNum != -1) tuplet = areaNum;
			} else if (DOT_AREA.isBetween(mouseMove)) {
				const int areaNum = searchAreas(DOT_TABLE, mouseMove);
				if (areaNum != -1) dots = areaNum;
			}
			if (eventDeleg !is null) eventDeleg(noteLen, tuplet, dots);
		}
		parent.endPopUpSession(this);
	}
	public override void passMME(MouseEventCommons mec, MouseMotionEvent mme) {
		if (position.isBetween(mme.x, mme.y)) {
			mouseMove.x = mme.x - position.left;
			mouseMove.y = mme.y - position.top;
		} else {
			mouseMove.x = -1;
			mouseMove.y = -1;
		}
		draw();
	}
}

public class DisplayProcessor {

	void processCommands() {
		// seek to the time position
		// clear display systems
		// process commands, then add them to the appropriate display systems
	}
}

public struct ChannelInfo {
	uint moduleNum;
	uint channelNum;
	int opCmp(const ChannelInfo rhs) const pure nothrow @nogc @safe {
		const l0 = this.moduleNum | (this.channelNum<<16), l1 = rhs.moduleNum | (rhs.channelNum<<16);
		return (l0 > l1) - (l0 < l1);
	}
	bool opEquals(const ChannelInfo rhs) const pure nothrow @nogc @safe {
		return opCmp(rhs) == 0;
	}
	size_t toHash() const pure nothrow @nogc @safe {
		return this.moduleNum | (this.channelNum<<16);
	}
}

public class SequencerCtrl : Window {
	// MenuBar menuBar;
	SmallButton button_new;
	SmallButton button_load;
	SmallButton button_save;
	SmallButton button_record;
	SmallButton button_play;
	SmallButton button_stop;
	CheckBox button_zoomOut;
	SmallButton button_chnlList;

	SmallButton envEdit_pitchbend;
	SmallButton envEdit_cc;
	SmallButton envEdit_pc;
	SmallButton envEdit_sysex;
	SmallButton envEdit_etc;
	SmallButton envEdit_imbc;
	SmallButton envEdit_arit;

	SmallButton horizZoom;
	SmallButton button_noteLen;

	HorizScrollBar seeker;
	VertScrollBar vsb_notes;
	PianoRoll pianoRoll;
	NoteEditor noteEdit;
	AudioDevKit adk;

	SequencerM2 seq;

	ModuleConfig mcfg;

	ChannelInfo[] channelList;
	dstring[] channelNames;

	ChannelInfo[] selectedChannels;

	ulong hPos;
	/// Stores the number of previously parsed audio modules. Reset when new modules are added.
	size_t prevAudioModuleNumber;
	/// Stores the note length for the current rhythm.
	/// 1: main division, 2: tuplet division, 3: dotted rhythm
	int[3] notelen;

	public this(AudioDevKit adk, SequencerM2 seq, ModuleConfig mcfg) {
		this.adk = adk;
		this.seq = seq;
		this.mcfg = mcfg;
		resizableV = true;
		resizableH = true;
		minW = 320;
		minH = 240;
		super(Box.bySize(0, 0, 640, 448), "Sequencer");

		button_new = new SmallButton("newButtonB", "newButtonA", "new", Box.bySize(0, 0, 16, 16));
		button_load = new SmallButton("loadButtonB", "loadButtonA", "load", Box.bySize(0, 0, 16, 16));
		button_save = new SmallButton("saveButtonB", "saveButtonA", "load", Box.bySize(0, 0, 16, 16));
		button_record = new SmallButton("recordB", "recordA", "record", Box.bySize(0, 0, 16, 16));
		button_play = new SmallButton("playB", "playA", "play", Box.bySize(0, 0, 16, 16));
		button_stop = new SmallButton("stopB", "stopA", "stop", Box.bySize(0, 0, 16, 16));
		button_zoomOut = new CheckBox("vzoomB", "vzoomA", "play", Box.bySize(0, 0, 16, 16));
		button_chnlList = new SmallButton("chSelB", "chSelA", "stop", Box.bySize(0, 0, 16, 16));

		addHeaderButton(button_new);
		addHeaderButton(button_load);
		button_load.onMouseLClick = &button_load_onClick;
		addHeaderButton(button_save);
		addHeaderButton(button_record);
		addHeaderButton(button_play);
		button_play.onMouseLClick = &button_play_onClick;
		addHeaderButton(button_stop);
		button_stop.onMouseLClick = &button_stop_onClick;
		addHeaderButton(button_zoomOut);
		button_zoomOut.onToggle = &button_zoomOut_onToggle;
		addHeaderButton(button_chnlList);

		button_noteLen = new SmallButton("notelenB", "notelenA", "notelen", Box.bySize(2, 16, 16, 16));
		button_noteLen.onMouseLClick = &button_noteLen_onClick;
		addElement(button_noteLen);

		horizZoom = new SmallButton("hzoomB", "hzoomA", "hzoom", Box.bySize(position.width - 18, 16, 16, 16));
		horizZoom.onMouseLClick = &horizZoom_in;
		horizZoom.onMouseRClick = &horizZoom_out;
		addElement(horizZoom);


		const envEditBegin = position.height - 65;
		envEdit_pitchbend = new SmallButton("pbendB", "pbendA", "envEdit_chSel", Box.bySize(2, envEditBegin, 16, 16));
		envEdit_cc = new SmallButton("ccB", "ccA", "envEdit_cc", Box.bySize(2, envEditBegin + 16, 16, 16));
		envEdit_pc = new SmallButton("pcB", "pcA", "envEdit_pc", Box.bySize(2, envEditBegin + 32, 16, 16));
		envEdit_sysex = new SmallButton("sysExB", "sysExA", "envEdit_sysex", Box.bySize(2, envEditBegin + 48, 16, 16));
		envEdit_etc = new SmallButton("etcB", "etcA", "envEdit_etc", Box.bySize(18, envEditBegin + 48, 16, 16));
		envEdit_imbc = new SmallButton("imbcCmdB", "imbcCmdA", "envEdit_imbc", Box.bySize(18, envEditBegin, 16, 16));
		envEdit_arit = new SmallButton("aritCmdB", "aritCmdA", "envEdit_arit", Box.bySize(18, envEditBegin + 16, 16, 16));

		addElement(envEdit_pitchbend);
		addElement(envEdit_cc);
		addElement(envEdit_pc);
		addElement(envEdit_sysex);
		addElement(envEdit_etc);
		addElement(envEdit_imbc);
		addElement(envEdit_arit);

		seeker = new HorizScrollBar(1, "seeker", Box.bySize(34, 16, position.width - 52, 16));
		vsb_notes = new VertScrollBar(910 - (position.height - 98), "notes",
				Box.bySize(position.width - 18, 32, 16, position.height - 98));

		addElement(seeker);
		addElement(vsb_notes);
		vsb_notes.onScrolling = &vsb_notes_onScroll;
		seeker.onScrolling = &seeker_onScroll;

		pianoRoll = new PianoRoll("pr", Box.bySize(2, 32, 32, position.height - 98));
		pianoRoll.hScrollRedirect = seeker;
		pianoRoll.vScrollRedirect = vsb_notes;
		addElement(pianoRoll);

		noteEdit = new NoteEditor(Box(34, 32, position.width - 18, position.height - 66));
		noteEdit.hScrollRedirect = seeker;
		noteEdit.vScrollRedirect = vsb_notes;
		addElement(noteEdit);
	}

	override public void onResize() {
		seeker.setPosition(Box.bySize(34, 16, position.width - 52, 16));
		const vsb_length = (button_zoomOut.isChecked ? 384 : 910) - (position.height - 98);
		vsb_notes.maxValue(vsb_length > 0 ? vsb_length : 0);
		vsb_notes.setPosition(Box.bySize(position.width - 18, 32, 16, position.height - 98));
		pianoRoll.setPosition(Box.bySize(2, 32, 32, position.height - 98));
		noteEdit.setPosition(Box(34, 32, position.width - 18, position.height - 66));

		const envEditBegin = position.height - 65;
		envEdit_pitchbend.setPosition(Box.bySize(2, envEditBegin, 16, 16));
		envEdit_cc.setPosition(Box.bySize(2, envEditBegin + 16, 16, 16));
		envEdit_pc.setPosition(Box.bySize(2, envEditBegin + 32, 16, 16));
		envEdit_sysex.setPosition(Box.bySize(2, envEditBegin + 48, 16, 16));
		envEdit_etc.setPosition(Box.bySize(18, envEditBegin + 48, 16, 16));
		envEdit_imbc.setPosition(Box.bySize(18, envEditBegin, 16, 16));
		envEdit_arit.setPosition(Box.bySize(18, envEditBegin + 16, 16, 16));

		super.onResize();
	}
	public void onMIDILoad() {
		import pixelperfectengine.concrete.dialogs.filedialog;
		handler.addWindow(new FileDialog("Load MIDI file.", "loadMidiDialog", &onMIDIFileLoad,
			[/+FileDialog.FileAssociationDescriptor("MIDI file", ["*.mid"]),+/
			FileDialog.FileAssociationDescriptor("Intelligent MIDI Bytecode file", ["*.imbc", "*.imb"])], "./"));
	}
	protected void onMIDIFileLoad(Event ev) {
		import mididi;
		import pixelperfectengine.audio.m2.rw;
		FileEvent fe = cast(FileEvent)ev;
		switch (fe.extension) {
			// case ".mid":
			// 	if (midiSeq !is null) {
			// 		midiSeq.stop();
			// 		midiSeq.openMIDI(readMIDIFile(fe.getFullPath));
			// 		state.m2Toggle = false;
			// 		mm.midiSeq = midiSeq;
			// 	} else {
			// 		wh.message("Error!", "No routing table has been initialized in current audio configuration!");
			// 	}
			// 	break;
			case ".imbc", ".imb":
				seq.stop();
				seq.loadSong(loadIMBCFile(fe.getFullPath), mcfg);
				mcfg.manager.midiSeq = seq;
				break;
			default:
				break;
		}
	}
	public void seqStart() {
		seq.start();
	}
	public void seqStop() {
		seq.stop();
	}
	protected void button_load_onClick(Event ev) {
		onMIDILoad();
	}
	protected void button_play_onClick(Event ev) {
		seqStart();
	}
	protected void button_stop_onClick(Event ev) {
		seqStop();
	}
	public void reparseAudioModulesAndChannels() {
		channelNames.length = 0;
		channelList.length = 0;
		foreach (size_t i, AudioModule am ; mcfg.modules) {
			string[] localChNames = am.getChannelNames();
			ubyte[] chNums = am.getAvailableChannels();
			string modName = mcfg.modNames[i];
			foreach (string name ; localChNames) {
				channelNames ~= toUTF32("[" ~ modName ~ "]:" ~ name);
			}
			foreach (ubyte u ; chNums) {
				channelList ~= ChannelInfo(cast(uint)i, u);
			}
		}
		prevAudioModuleNumber = mcfg.modules.length;
	}
	protected void button_chnlList_onClick(Event ev) {
		if (prevAudioModuleNumber == mcfg.modules.length) reparseAudioModulesAndChannels();
		PopUpMenuElement[] menuElements;
		foreach (size_t i, dstring chName ; chNames) {
			dstring isSelected = selectedChannels.countUntil(channelList[i]) == -1 ? "" : "X";
			menuElements ~= new PopUpMenuElement("", chName);
		}
		handler.addPopUpElement(new PopUpMenu(menuElements, "chSel", &onChannelSelect));
	}
	protected void onChannelSelect(Event ev) {
		MenuEvent me = cast(MenuEvent)ev;
		ChannelInfo selChnl = channelList[me.itemNum];
		const isChannelSelected = selectedChannels.countUntil(selChnl);
		if (isChannelSelected == -1) {
			selectedChannels ~= selChnl;
		} else {
			selectedChannels.remove(isChannelSelected);
		}
	}
	protected void button_noteLen_onClick(Event ev) {
		handler.addPopUpElement(new RhythmSelector(notelen[0], notelen[1], notelen[2]));
	}
	protected void onNotelenSelect(int noleLen, int tuplet, int dots) {
		notelen[0] = noleLen;
		notelen[1] = tuplet;
		notelen[2] = dots;
	}
	protected void horizZoom_in(Event ev) {
		if (noteEdit.hDiv > 32) {
			noteEdit.hDiv /= 2;
		}
	}
	protected void horizZoom_out(Event ev) {
		if (noteEdit.hDiv < 65_536) {
			noteEdit.hDiv *= 2;
		}
	}
	protected void button_zoomOut_onToggle(Event ev) {
		const vsb_length = (button_zoomOut.isChecked ? 384 : 910) - (position.height - 82);
		vsb_notes.maxValue(vsb_length > 0 ? vsb_length : 0);
		vsb_notes.draw();
		pianoRoll.zoomOut = button_zoomOut.isChecked();
		pianoRoll.draw();
	}
	protected void vsb_notes_onScroll(Event ev) {
		pianoRoll.vScrollAmount = vsb_notes.value;
		noteEdit.vScrollAmount = vsb_notes.value;
		pianoRoll.draw();
		noteEdit.draw();
	}

	protected void seeker_onScroll(Event ev) {

	}
}
