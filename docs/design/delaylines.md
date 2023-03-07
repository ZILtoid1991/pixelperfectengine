# Delay line tap layout

```
[tap in]──┬──────────────────────────┐
          │             -       +    │                ┌─[outLevelL]
          ├──[IIR0]────[filterAm0]   │                │
          │             │       │    │                ├─[outLevelR]
          ├──[IIR1]────[filterAm1]   │                │
          │             │       │    │                │
          └──[IIR2]────[filterAm2]   │                │
                        │       │    │  |------\      │               ┌─[feedbackSec]
                        │       └────┴──|+      \     │               │
                        │               | Mixer  >────┴──────[IIR3]───┴─[feedbackPri]
                        └───────────────|-      /
                                        |------/
```