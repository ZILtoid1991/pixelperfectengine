module test1.audioconfig;

import pixelperfectengine.concrete.window;
import pixelperfectengine.audio.base.handler;

import test1.app;

import iota.audio.output;
import iota.audio.device;
import iota.audio.midi;

import std.utf;
import std.conv : to;
import std.stdio;	//Bit ugly, but since we already have the command line window, let's use it for status messages!

public class AudioConfig : Window {
	ListView listView_AudDevs;
	ListView listView_MidiDev;
	TextBox textBox_sampleRate;
	TextBox textBox_buffer;
	TextBox textBox_frame;
	Label label0;
	Label label1;
	Label label2;
	Button button_apply;
	AudioDevKit app;
	public this(AudioDevKit app) {
		super(Box(0, 0, 355, 250), "Audio and MIDI setup");
		this.app = app;
		listView_AudDevs = new ListView(new ListViewHeader(16, [30 ,300], ["Num" ,"Audio Device"]), null, "listView0", 
				Box(5, 20, 175, 200));
		listView_MidiDev = new ListView(new ListViewHeader(16, [30 ,300], ["Num" ,"MIDI Device"]), null, "listView1", 
				Box(180, 20, 350, 200));
		textBox_sampleRate = new TextBox("48000"d, "textBox0", Box(5, 225, 90, 245));
		textBox_buffer = new TextBox("512"d, "textBox1", Box(94, 225, 175, 245));
		textBox_frame = new TextBox("64"d, "textBox2", Box(180, 225, 257, 245));
		label0 = new Label("Sample rate:"d, "label0", Box(5, 205, 91, 225));
		label1 = new Label("Buffer size:"d, "label1", Box(95, 205, 175, 225));
		label2 = new Label("Frame size:"d, "label2", Box(180, 205, 257, 222));
		button_apply = new Button("Apply"d, "button0", Box(260, 225, 350, 245));

		listView_AudDevs ~= new ListViewItem(16, ["-1", "Default"]);

		string[] drivers = getOutputDeviceNames();
		foreach (size_t id, string key; drivers) {
			listView_AudDevs ~= new ListViewItem(16, [to!dstring(id), toUTF32(key)]);
		}
		drivers = getMIDIInputDevs();
		foreach (size_t id, string key; drivers) {
			listView_MidiDev ~= new ListViewItem(16, [to!dstring(id), toUTF32(key)]);
		}

		button_apply.onMouseLClick = &button_apply_onClick;

		textBox_sampleRate.setFilter(TextInputFieldType.IntegerP);
		textBox_buffer.setFilter(TextInputFieldType.IntegerP);
		textBox_frame.setFilter(TextInputFieldType.IntegerP);

		addElement(listView_AudDevs);
		addElement(listView_MidiDev);
		addElement(textBox_sampleRate);
		addElement(textBox_buffer);
		addElement(textBox_frame);
		addElement(label0);
		addElement(label1);
		addElement(label2);
		addElement(button_apply);
	}
	protected void button_apply_onClick(Event ev) {
		import iota.audio.types;
		//create audio specs
		try {
			app.aS = AudioSpecs(predefinedFormats[PredefinedFormats.FP32], to!int(textBox_sampleRate.getText.text), 0, 2, 
					to!int(textBox_buffer.getText.text), Duration.init);
			int frameSize = to!int(textBox_frame.getText.text);
			app.adh = new AudioDeviceHandler(app.aS, frameSize, app.aS.bufferSize_slmp / frameSize);
			app.adh.initAudioDevice(to!int(listView_AudDevs.selectedElement[0].text.text));
			app.mm = new ModuleManager(app.adh);
			app.onStart();
			this.close();
		} catch (Exception e) {
			handler.message("Audio initialization error!", toUTF32(e.msg));
		}
	}
}
