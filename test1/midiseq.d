module test1.midiseq;

import pixelperfectengine.concrete.window;

import pixelperfectengine.audio.base.midiseq : SequencerM1;
import test1.app;

public class SequencerCtrl : Window {
	SmallButton button_load;
	SmallButton button_play;
	SmallButton button_stop;
	AudioDevKit adk;
	SequencerM1 seq;

	public this(AudioDevKit adk) {
		this.adk = adk;
		seq = adk.midiSeq;
		super(Box.bySize(0, 0, 320, 32), "Test Sequencer");

		button_load = new SmallButton("loadB", "loadA", "load", Box.bySize(0, 16, 16, 16));
		button_play = new SmallButton("playB", "playA", "play", Box.bySize(16, 16, 16, 16));
		button_stop = new SmallButton("stopB", "stopA", "stop", Box.bySize(32, 16, 16, 16));

		addElement(button_load);
		addElement(button_play);
		addElement(button_stop);
	}
	protected void button_load_onClick(Event ev) {
		adk.onMIDILoad();
	}
	protected void button_play_onClick(Event ev) {
		seq.start();
	}
	protected void button_stop_onClick(Event ev) {
		seq.stop();
	}
}