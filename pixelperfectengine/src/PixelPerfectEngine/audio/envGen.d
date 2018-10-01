module PixelPerfectEngine.audio.envGen;
/*
 * Copyright (C) 2015-2018, by Laszlo Szeremi under the Boost license.
 *
 * Pixel Perfect Engine, envelop generator module
 */

 import std.bitmanip;

public enum StageType : ubyte{
	NULL		=	0,	/// Terminates the envelope
	ascending	=	1,
	descending	=	2,
	sustain		=	3,	/// Descending until either a key release command or reaches zero.
	revSustain	=	4,	/// Ascending until either key release or max level reached.
	hold		=	5,	/// Keeps the value of targetLevel until holdTime.
}

/**
 * Defines a single envelope stage.
 */
public struct EnvelopeStage{

	public uint targetLevel;	/// If reached, jumps to the next stage
	public uint stepping;		/// If slow enabled, it sets how much cycles needed for a single increment, otherwise sets the increment for each cycle
	public byte linearity;		/// 0 = Linear. Greater than 0 = Pseudolog. Less than 0 = Pseudoantilog.
	mixin(bitfields!(
		ubyte, "type", 3,
		bool, "slow", 1,
		ubyte, "unused", 4));
	public ushort holdTime;		/// If used, it describes the hold time in milliseconds
}

public struct EnvelopeGenerator{
	public EnvelopeStage[] stages;
	private sizediff_t currentStage;
	private uint currentLevel, stepNumber;
	private uint log;
	private bool isRunning, keyON;

	public @nogc @property uint output(){
		return currentLevel;
	}

	public @nogc void step(){
		if(isRunning){
			switch(stages[currentStage].type){
				case StageType.ascending:
					if(stages[currentStage].linearity > 0){
						currentLevel += stages[currentStage].stepping;
						log += stages[currentStage].stepping;
						currentLevel += log / (128 - stages[currentStage].linearity);

						if(currentLevel >= stages[currentStage].targetLevel){
							currentLevel = stages[currentStage].targetLevel;
							currentStage++;
							log = 0;
						}
					}else if(stages[currentStage].linearity < 0){
						currentLevel += stages[currentStage].stepping;
						currentLevel += (stages[currentStage].targetLevel - currentLevel) / (129 - stages[currentStage].linearity * -1);
						if(currentLevel >= stages[currentStage].targetLevel){
							currentLevel = stages[currentStage].targetLevel;
							currentStage++;
						}
					}else{
						if(stages[currentStage].slow){
							stepNumber++;
							if(stepNumber == stages[currentStage].stepping){
								stepNumber = 0;
								currentLevel++;
							}
						}else{
							currentLevel += stages[currentStage].stepping;
						}
						if(currentLevel >= stages[currentStage].targetLevel){
							currentLevel = stages[currentStage].targetLevel;
							currentStage++;
						}
					}
					break;
				case StageType.descending:
					if(stages[currentStage].linearity > 0){
						currentLevel -= stages[currentStage].stepping;
						log += stages[currentStage].stepping;
						currentLevel -= log / (128 - stages[currentStage].linearity);

						if(currentLevel <= stages[currentStage].targetLevel){
							currentLevel = stages[currentStage].targetLevel;
							currentStage++;
							log = 0;
						}
					}else if(stages[currentStage].linearity < 0){
						currentLevel -= stages[currentStage].stepping;
						currentLevel -= (stages[currentStage].targetLevel - currentLevel) / (129 - stages[currentStage].linearity * -1);
						if(currentLevel <= stages[currentStage].targetLevel){
							currentLevel = stages[currentStage].targetLevel;
							currentStage++;
						}
					}else{
						if(stages[currentStage].slow){
							stepNumber++;
							if(stepNumber == stages[currentStage].stepping){
								stepNumber = 0;
								currentLevel--;
							}
						}else{
							currentLevel -= stages[currentStage].stepping;
						}
						if(currentLevel <= stages[currentStage].targetLevel){
							currentLevel = stages[currentStage].targetLevel;
							currentStage++;
						}
					}
					break;
				case StageType.sustain:
					if(stages[currentStage].linearity > 0){
						currentLevel -= stages[currentStage].stepping;
						log += stages[currentStage].stepping;
						currentLevel -= log / (128 - stages[currentStage].linearity);

						if(currentLevel <= 0){
							isRunning = false;
						}
						if(!keyON){
							currentStage++;
						}
					}else if(stages[currentStage].linearity < 0){
						currentLevel -= stages[currentStage].stepping;
						currentLevel -= (stages[currentStage].targetLevel - currentLevel) / (129 - stages[currentStage].linearity * -1);
						if(currentLevel <= 0){
							isRunning = false;
						}
						if(!keyON){
							currentStage++;
						}
					}else{
						if(stages[currentStage].slow){
							stepNumber++;
							if(stepNumber == stages[currentStage].stepping){
								stepNumber = 0;
								currentLevel--;
							}
						}else{
							currentLevel -= stages[currentStage].stepping;
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
		}
	}
}
