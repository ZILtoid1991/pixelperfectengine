# Delay line layout and introduction

## Single tap layout

```
[tap in]──[FIR]─┬─[MixerOut A/B]─[To mixer]
                │
                └─[FBOut A/B]────[To feedback]
```

## Effects layout

```
                   
[Input A]──╔═══════╗           [LFO ×4]                ╔═════╗
           ║Routing║───────────[DelayLineA/B]──────────║Mixer║─────[Output A/B]
[Input B]──╚═══════╝     FBOut└(Taps ×4)               ╚═════╝
                                                      (IIR ×4)
```

## Effects properties

* 2 inputs and outputs
* 4 LFOs assignable to position and level
* 2 Delay lines, with each having 4 taps with a 16 element FIR line
* A mixer with 4×2 IIR filters for equalization