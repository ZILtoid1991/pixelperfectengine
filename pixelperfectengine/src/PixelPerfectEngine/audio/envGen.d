module PixelPerfectEngine.audio.envGen;
/*
 * Copyright (C) 2015-2018, by Laszlo Szeremi under the Boost license.
 *
 * Pixel Perfect Engine, envelop generator module
 */

import std.bitmanip;
import std.container.array;

public enum StageType : ubyte{
	NULL		=	0,	/// Terminates the envelope
	ascending	=	1,
	descending	=	2,
	sustain		=	3,	/// Descending until either a key release command or reaches zero.
	revSustain	=	4,	/// Ascending until either key release or max level reached.
	hold		=	5,	/// Keeps the value of targetLevel until holdTime.
	release		=	7,	/// Used on key-release,
}

/**
 * Defines a single envelope stage.
 */
public struct EnvelopeStage{

	public int targetLevel;	/// If reached, jumps to the next stage
	public int stepping;		/// If slow enabled, it sets how much cycles needed for a single increment, otherwise sets the increment for each cycle
	public byte linearity;		/// 0 = Linear. Greater than 0 = Pseudolog. Less than 0 = Pseudoantilog.
	mixin(bitfields!(
		ubyte, "type", 3,
		bool, "slow", 1,
		ubyte, "unused", 4));
	public ushort holdTime;		/// If used, it describes the hold time in milliseconds
}
///to fix some readability
alias EnvelopeStageList = Array!(EnvelopeStage);
/**
 * n-stage envelope generator with high-programmability and nonlinear capabilities.
 */
public struct EnvelopeGenerator{
	public EnvelopeStageList* stages;
	private sizediff_t currentStage;
	private int currentLevel, stepNumber;
	private int log;
	private bool isRunning, keyON, keyRelease;

	public @nogc @property int output(){
		return currentLevel;
	}
	public @nogc void reset(){
		currentStage = 0;
		currentLevel = 0;
		stepNumber = 0;
		log = 0;
		isRunning = false;
		keyON = false;
	}
	public @nogc void setKeyOn(){
		keyON = true;
		isRunning = true;
	}
	public @nogc void setKeyOff(){
		keyON = false;
	}
	public @nogc void step(){
		if(isRunning){
			if(keyON){
				switch(stages[0][currentStage].type){
					case StageType.ascending:
						if(stages[0][currentStage].linearity > 0){
							currentLevel += stages[0][currentStage].stepping;
							log += stages[0][currentStage].stepping;
							currentLevel += log / (128 - stages[0][currentStage].linearity);

							if(currentLevel >= stages[0][currentStage].targetLevel){
								currentLevel = stages[0][currentStage].targetLevel;
								currentStage++;
								log = 0;
							}
						}else if(stages[0][currentStage].linearity < 0){
							currentLevel += stages[0][currentStage].stepping;
							currentLevel += (stages[0][currentStage].targetLevel - currentLevel) / (129 - stages[0][currentStage].linearity * -1);
							if(currentLevel >= stages[0][currentStage].targetLevel){
								currentLevel = stages[0][currentStage].targetLevel;
								currentStage++;
							}
						}else{
							if(stages[0][currentStage].slow){
								stepNumber++;
								if(stepNumber == stages[0][currentStage].stepping){
									stepNumber = 0;
									currentLevel++;
								}
							}else{
								currentLevel += stages[0][currentStage].stepping;
							}
							if(currentLevel >= stages[0][currentStage].targetLevel){
								currentLevel = stages[0][currentStage].targetLevel;
								currentStage++;
							}
						}
						break;
					case StageType.descending:
						if(stages[0][currentStage].linearity > 0){
							currentLevel -= stages[0][currentStage].stepping;
							log += stages[0][currentStage].stepping;
							currentLevel -= log / (128 - stages[0][currentStage].linearity);

							if(currentLevel <= stages[0][currentStage].targetLevel){
								currentLevel = stages[0][currentStage].targetLevel;
								currentStage++;
								log = 0;
							}
						}else if(stages[0][currentStage].linearity < 0){
							currentLevel -= stages[0][currentStage].stepping;
							currentLevel -= (stages[0][currentStage].targetLevel - currentLevel) / (129 - stages[0][currentStage].linearity * -1);
							if(currentLevel <= stages[0][currentStage].targetLevel){
								currentLevel = stages[0][currentStage].targetLevel;
								currentStage++;
							}
						}else{
							if(stages[0][currentStage].slow){
								stepNumber++;
								if(stepNumber >= stages[0][currentStage].stepping){
									stepNumber = 0;
									currentLevel--;
								}
							}else{
								currentLevel -= stages[0][currentStage].stepping;
							}
							if(currentLevel <= stages[0][currentStage].targetLevel){
								currentLevel = stages[0][currentStage].targetLevel;
								currentStage++;
							}
						}
						break;
					case StageType.sustain:
						if(stages[0][currentStage].linearity > 0){
							currentLevel -= stages[0][currentStage].stepping;
							log += stages[0][currentStage].stepping;
							currentLevel -= log / (128 - stages[0][currentStage].linearity);

							if(currentLevel <= 0){
								isRunning = false;
							}
							if(!keyON){
								currentStage++;
							}
						}else if(stages[0][currentStage].linearity < 0){
							currentLevel -= stages[0][currentStage].stepping;
							currentLevel -= (stages[0][currentStage].targetLevel - currentLevel) / (129 - stages[0][currentStage].linearity * -1);
							if(currentLevel <= 0){
								isRunning = false;
							}
							if(!keyON){
								currentStage++;
							}
						}else{
							if(stages[0][currentStage].slow){
								stepNumber++;
								if(stepNumber >= stages[0][currentStage].stepping){
									stepNumber = 0;
									currentLevel--;
								}
							}else{
								currentLevel -= stages[0][currentStage].stepping;
							}
							if(currentLevel <= 0){
								isRunning = false;
							}
							if(!keyON){
								currentStage++;
							}
						}
						break;
					default:
						isRunning = false;
						break;
				}
			}else{		//keyOFF
				if(keyRelease){
					//descending, but terminate when reaching zero
					if(stages[0][currentStage].linearity > 0){
						currentLevel -= stages[0][currentStage].stepping;
						log += stages[0][currentStage].stepping;
						currentLevel -= log / (128 - stages[0][currentStage].linearity);
						if(currentLevel <= 0){
							currentLevel = 0;
							reset;
							log = 0;
						}
					}else if(stages[0][currentStage].linearity < 0){
						currentLevel -= stages[0][currentStage].stepping;
						currentLevel -= currentLevel / (129 - stages[0][currentStage].linearity * -1);
						if(currentLevel <= 0){
							currentLevel = 0;
							reset;
						}
					}else{
						if(stages[0][currentStage].slow){
							stepNumber++;
							if(stepNumber >= stages[0][currentStage].stepping){
								stepNumber = 0;
								currentLevel--;
							}
						}else{
							currentLevel -= stages[0][currentStage].stepping;
						}
						if(currentLevel <= 0){
							currentLevel = 0;
							reset;
						}
					}
				}else{
					//find a key release stage, if not present then terminate session by resetting
					for(; currentStage < stages.length ; currentStage++){
						if(stages[0][currentStage].type == StageType.release){
							keyRelease = true;
						}else if(stages[0][currentStage].type == StageType.NULL){
							break;
						}
					}
					reset;
				}
			}
		}
	}
}
