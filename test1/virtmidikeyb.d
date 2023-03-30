module test1.virtmidikeyb;

import pixelperfectengine.concrete.window; 
import pixelperfectengine.system.input.types;
import pixelperfectengine.system.etc : hashCalc;
import midi2.types.structs;
import midi2.types.enums;
import test1.app;
import std.conv : to;

public class VirtualMidiKeyboard : Window {
	SmallButton[]	keys;
	TextBox			textBox_NoteOffset;
	TextBox			textBox_Channel;
	TextBox			textBox_PrgChange;
	ubyte			noteOffset = 36;
	ubyte			channel;
	bool			typematicBlock;
	AudioDevKit		app;
	public this(AudioDevKit app) {
		this.app = app;
		super(Box.bySize(0,0,200,85), "Virtual MIDI keyboard");
		for (int i ; i < 20 ; i++) {
			Box b;
			const int note = i % 12, oct = i / 12;
			switch (note) {
				case 1, 3, 6, 8, 10:
					b.top = 20;
					b.bottom = 20 + 15;
					break;
				default:
					b.top = 20 + 16;
					b.bottom = 20 + 16 + 15;
					break;
			}
			switch (note) {
				default:	//c
					b.left = 4 + (oct * 112);
					b.right = 4 + 15 + (oct * 112);
					break;
				case 1:		//c#
					b.left = 4 + (oct * 112) + 8;
					b.right = 4 + 15 + (oct * 112) + 8;
					break;
				case 2:		//d
					b.left = 4 + (oct * 112) + (16 * 1);
					b.right = 4 + 15 + (oct * 112) + (16 * 1);
					break;
				case 3:		//d#
					b.left = 4 + (oct * 112) + 8 + (16 * 1);
					b.right = 4 + 15 + (oct * 112) + 8 + (16 * 1);
					break;
				case 4:		//e
					b.left = 4 + (oct * 112) + (16 * 2);
					b.right = 4 + 15 + (oct * 112) + (16 * 2);
					break;
				case 5:		//f
					b.left = 4 + (oct * 112) + (16 * 3);
					b.right = 4 + 15 + (oct * 112) + (16 * 3);
					break;
				case 6:		//f#
					b.left = 4 + (oct * 112) + 8 + (16 * 3);
					b.right = 4 + 15 + (oct * 112) + 8 + (16 * 3);
					break;
				case 7:		//g
					b.left = 4 + (oct * 112) + (16 * 4);
					b.right = 4 + 15 + (oct * 112) + (16 * 4);
					break;
				case 8:		//g#
					b.left = 4 + (oct * 112) + 8 + (16 * 4);
					b.right = 4 + 15 + (oct * 112) + 8 + (16 * 4);
					break;
				case 9:		//a
					b.left = 4 + (oct * 112) + (16 * 5);
					b.right = 4 + 15 + (oct * 112) + (16 * 5);
					break;
				case 10:	//a#
					b.left = 4 + (oct * 112) + 8 + (16 * 5);
					b.right = 4 + 15 + (oct * 112) + 8 + (16 * 5);
					break;
				case 11:	//b
					b.left = 4 + (oct * 112) + (16 * 6);
					b.right = 4 + 15 + (oct * 112) + (16 * 6);
					break;
			}
			SmallButton sb = new SmallButton("closeButtonB", "closeButtonA", [cast(char)i], b);
			sb.mousePressEvent = true;
			sb.onMouseLClick = &onKey!(0xFFFF_0000);
			sb.onMouseMClick = &onKey!(0x7FFF_0000);
			sb.onMouseRClick = &onKey!(0x3FFF_0000);
			addElement(sb);
			keys ~= sb;
		}
		textBox_NoteOffset = new TextBox("36", "textBox_NoteOffset", Box(5, 25+16+16 , 45, 25+16+16+20));
		textBox_Channel = new TextBox("0", "textBox_Channel", Box(50, 25+16+16 , 95, 25+16+16+20));
		textBox_PrgChange = new TextBox("PrgCh", "textBox_PrgChange", Box(100, 25+16+16 , 170, 25+16+16+20));
		addElement(textBox_NoteOffset);
		addElement(textBox_Channel);
		addElement(textBox_PrgChange);
		textBox_NoteOffset.onTextInput = &textBox_NoteOffset_onTextInput;
		textBox_Channel.onTextInput = &textBox_Channel_onTextInput;
		textBox_PrgChange.onTextInput = &textBox_PrgChange_onTextInput;
		onClose = &app.onVirtMIDIKeybClose;
	}
	public int keyEventReceive(uint id, BindingCode code, uint timestamp, bool isPressed) {
		if (!active)
			return 0;
		if (isPressed) {
			if (typematicBlock) {
				return 1;
			}
			typematicBlock = true;
		} else {
			typematicBlock = false;
		}
		ubyte note;
		switch (id) {
			case hashCalc("VirtMIDIKB-C-0"):
				note = 0;
				break;
			case hashCalc("VirtMIDIKB-C#0"):
				note = 1;
				break;
			case hashCalc("VirtMIDIKB-D-0"):
				note = 2;
				break;
			case hashCalc("VirtMIDIKB-D#0"):
				note = 3;
				break;
			case hashCalc("VirtMIDIKB-E-0"):
				note = 4;
				break;
			case hashCalc("VirtMIDIKB-F-0"):
				note = 5;
				break;
			case hashCalc("VirtMIDIKB-F#0"):
				note = 6;
				break;
			case hashCalc("VirtMIDIKB-G-0"):
				note = 7;
				break;
			case hashCalc("VirtMIDIKB-G#0"):
				note = 8;
				break;
			case hashCalc("VirtMIDIKB-A-0"):
				note = 9;
				break;
			case hashCalc("VirtMIDIKB-A#0"):
				note = 10;
				break;
			case hashCalc("VirtMIDIKB-B-0"):
				note = 11;
				break;
			case hashCalc("VirtMIDIKB-C-1"):
				note = 12;
				break;
			case hashCalc("VirtMIDIKB-C#1"):
				note = 13;
				break;
			case hashCalc("VirtMIDIKB-D-1"):
				note = 14;
				break;
			case hashCalc("VirtMIDIKB-D#1"):
				note = 15;
				break;
			case hashCalc("VirtMIDIKB-E-1"):
				note = 16;
				break;
			case hashCalc("VirtMIDIKB-F-1"):
				note = 17;
				break;
			case hashCalc("VirtMIDIKB-F#1"):
				note = 18;
				break;
			case hashCalc("VirtMIDIKB-G-1"):
				note = 19;
				break;
			case hashCalc("VirtMIDIKB-oct+"):
				if (!isPressed) {
					noteOffset += 12;
					textBox_NoteOffset.setText(to!dstring(noteOffset));
				}
				return 1;
			case hashCalc("VirtMIDIKB-oct-"):
				if (!isPressed) {
					noteOffset -= 12;
					textBox_NoteOffset.setText(to!dstring(noteOffset));
				}
				return 1;
			case hashCalc("VirtMIDIKB-note+"):
				if (!isPressed) {
					noteOffset++;
					textBox_NoteOffset.setText(to!dstring(noteOffset));
				}
				return 1;
			case hashCalc("VirtMIDIKB-note-"):
				if (!isPressed) {
					noteOffset--;
					textBox_NoteOffset.setText(to!dstring(noteOffset));
				}
				return 1;
			default:
				return 0;
		}
		UMP midiPacket = UMP(MessageType.MIDI2, cast(ubyte)(channel>>4), isPressed ? MIDI2_0Cmd.NoteOn : MIDI2_0Cmd.NoteOff, 
				cast(ubyte)(channel&0x0F), cast(ubyte)(note + noteOffset), 0x00);
		uint velo = 0xFFFF_0000;
		if (app.selectedModule !is null) {
			app.selectedModule.midiReceive(midiPacket, velo);
		}
		return 1;
	}
	protected void onKey(uint velo)(Event ev) {
		SmallButton sender = cast(SmallButton)ev.sender;
		ubyte note = cast(ubyte)(noteOffset + sender.getSource[0]);
		UMP midiPacket = UMP(MessageType.MIDI2, cast(ubyte)(channel>>4), sender.isPressed ? MIDI2_0Cmd.NoteOn : 
				MIDI2_0Cmd.NoteOff, cast(ubyte)(channel&0x0F), note, 0x00);
		//uint velo = 0xFFFF_0000;
		if (app.selectedModule !is null) {
			app.selectedModule.midiReceive(midiPacket, velo);
		}
	}
	protected void textBox_PrgChange_onTextInput(Event ev) {
		dstring text = textBox_PrgChange.getText().toDString();
		if (text.length & 1 || text.length >= 7) {
			textBox_PrgChange.setText("Error!");
			return;
		}
		try {
			uint bankMSB, bankLSB, prg;
			if (text.length == 6) {
				bankMSB = to!uint(text[0..2], 16);
				text = text[2..$];
			}
			if (text.length == 4) {
				bankLSB = to!uint(text[0..2], 16);
				text = text[2..$];
			}
			prg = to!uint(text, 16);
			UMP midiPacket = UMP(MessageType.MIDI2, cast(ubyte)(channel>>4), MIDI2_0Cmd.PrgCh, 
					cast(ubyte)(channel&0x0F), 0x00, 0x00);
			uint velo = (prg<<24) | (bankMSB<<8) | bankLSB;
			if (app.selectedModule !is null) {
				app.selectedModule.midiReceive(midiPacket, velo);
			}
		} catch (Exception e) {
			textBox_PrgChange.setText("Error!");
		}
	}
	protected void textBox_NoteOffset_onTextInput(Event ev) {
		try {
			noteOffset = to!ubyte(textBox_NoteOffset.getText().toDString());
		} catch (Exception e) {
			textBox_NoteOffset.setText("Error!");
		}
	}
	protected void textBox_Channel_onTextInput(Event ev) {
		try {
			channel = to!ubyte(textBox_Channel.getText().toDString());
		} catch (Exception e) {
			textBox_Channel.setText("Error!");
		}
	}
}