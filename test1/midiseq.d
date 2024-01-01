module test1.midiseq;

import pixelperfectengine.concrete.window;

import pixelperfectengine.audio.base.midiseq : SequencerM1;
import pixelperfectengine.audio.m2.seq;
import test1.app;

public class SequencerCtrl : Window {
	SmallButton button_load;
	SmallButton button_play;
	SmallButton button_stop;
	AudioDevKit adk;

	public this(AudioDevKit adk) {
		this.adk = adk;
		super(Box.bySize(0, 0, 320, 32), "Test Sequencer");

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
		/* if (!adk.state.m2Toggle) seq.start();
		else seqM2.start(); */
	}
	protected void button_stop_onClick(Event ev) {
		adk.seqStop();
		/* if (!adk.state.m2Toggle) seq.stop();
		else seqM2.stop(); */
	}
}