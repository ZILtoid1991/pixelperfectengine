MIDI2.0 VER 1

HEADER
timeFormatID fmt3
timeFormatPeriod 48000
timeFormatRes 1
maxPattern 4
END

METADATA
name: "Toccata and Fugue in D Minor BWV 565"
composer: "J.S. Bach"
END

DEVLIST
fmsynth: 0
END

PATTERN main
display BPM 55
$[0]: pc 0 16
$[0]: pc 1 16
$[0]: pc 2 16
$[0]: pc 3 16
$[0]: pc 4 16
$[0]: pc 5 16
$[0]: pc 6 16
$[0]: pc 7 16
;bar 1
;$[0]: note 0 0x7FFF o:a-5
;$[0]: note 1 0x7FFF o:a-4
;wait o+t
$[0]: note 0 0x7FFF i:a-5
$[0]: note 1 0x7FFF i:a-4
wait i
$[0]: note 0 0x7FFF i:g-5
$[0]: note 1 0x7FFF i:g-4
wait i
$[0]: note 0 0x7FFF s.:a-5
$[0]: note 1 0x7FFF s.:a-4
wait s.+t
$[0]: note 0 0x7FFF i:g-5
$[0]: note 1 0x7FFF i:g-4
wait i
$[0]: note 0 0x7FFF i:f-5
$[0]: note 1 0x7FFF i:f-4
wait i
$[0]: note 0 0x7FFF i:e-5
$[0]: note 1 0x7FFF i:e-4
wait i
$[0]: note 0 0x7FFF i:d-5
$[0]: note 1 0x7FFF i:d-4
wait i
$[0]: note 0 0x7FFF t:c#5
$[0]: note 1 0x7FFF t:c#4
wait t
$[0]: note 0 0x7FFF s:d-5
$[0]: note 1 0x7FFF s:d-4
wait s+s+o
;$[0]: note 0 0x7FFF o:a-4
;$[0]: note 1 0x7FFF o:a-3
;wait o+t
$[0]: note 0 0x7FFF i:a-4
$[0]: note 1 0x7FFF i:a-3
wait i
$[0]: note 0 0x7FFF i:g-4
$[0]: note 1 0x7FFF i:g-3
wait i
$[0]: note 0 0x7FFF s.:a-4
$[0]: note 1 0x7FFF s.:a-3
wait s.+t
$[0]: note 0 0x7FFF t:e-4
$[0]: note 1 0x7FFF t:e-3
wait t
$[0]: note 0 0x7FFF t:f-4
$[0]: note 1 0x7FFF t:f-3
wait t
$[0]: note 0 0x7FFF t:c#4
$[0]: note 1 0x7FFF t:c#3
wait t
$[0]: note 0 0x7FFF s:d-4
$[0]: note 1 0x7FFF s:d-3
wait s+s+o
;$[0]: note 0 0x7FFF o:f-5
;$[0]: note 1 0x7FFF o:f-4
;wait o+t
;bar 2
;$[0]: note 0 0x7FFF o:a-3
;$[0]: note 1 0x7FFF o:a-2
;wait o+t
$[0]: note 0 0x7FFF i:a-3
$[0]: note 1 0x7FFF i:a-2
wait i
$[0]: note 0 0x7FFF i:g-3
$[0]: note 1 0x7FFF i:g-2
wait i
$[0]: note 0 0x7FFF s.:a-3
$[0]: note 1 0x7FFF s.:a-2
wait s.+t
$[0]: note 0 0x7FFF i:g-3
$[0]: note 1 0x7FFF i:g-2
wait i
$[0]: note 0 0x7FFF i:f-3
$[0]: note 1 0x7FFF i:f-2
wait i
$[0]: note 0 0x7FFF i:e-3
$[0]: note 1 0x7FFF i:e-2
wait i
$[0]: note 0 0x7FFF i:d-3
$[0]: note 1 0x7FFF i:d-2
wait i
$[0]: note 0 0x7FFF t:c#3
$[0]: note 1 0x7FFF t:c#2
wait t
$[0]: note 0 0x7FFF s:d-3
$[0]: note 1 0x7FFF s:d-2
wait s+s+o
$[0]: nn 7 0x7FFF d-2
wait s
$[0]: nn 6 0x7FFF c#3
wait s
$[0]: nn 5 0x7FFF e-3
wait s
$[0]: nn 4 0x7FFF g-3
wait s
$[0]: nn 3 0x7FFF a#3
wait s
$[0]: nn 2 0x7FFF c#4
wait s
$[0]: nn 1 0x7FFF e-4
wait s
;bar 3
wait q
$[0]: nf 6 0x7FFF c#3
$[0]: nf 5 0x7FFF e-3
$[0]: nf 3 0x7FFF a#3
$[0]: nf 2 0x7FFF c#4
$[0]: nf 1 0x7FFF e-4
$[0]: note 0 0x7FFF q:d-4
$[0]: note 1 0x7FFF q:a-3
$[0]: note 2 0x7FFF q:d-3
wait s
$[0]: nf 4 0x7FFF g-3
$[0]: note 3 0x7FFF s:e-3
wait s
$[0]: note 4 0x7FFF s:f#3
wait o
$[0]: nf 7 0x7FFF d-2
wait q+o+s
display BPM 200
$[0]: note 0 0x7FFF s:c#4
$[0]: note 1 0x7FFF s:c#3
wait s
;bar 4
$[0]: note 0 0x7FFF 3s:d-4
$[0]: note 1 0x7FFF 3s:d-3
wait 3s
$[0]: note 0 0x7FFF s:e-4
$[0]: note 1 0x7FFF s:e-3
wait 3s
$[0]: note 0 0x7FFF 3s:c#4
$[0]: note 1 0x7FFF 3s:c#3
wait 3s
$[0]: note 0 0x7FFF 3s:d-4
$[0]: note 1 0x7FFF 3s:d-3
wait 3s
$[0]: note 0 0x7FFF 3s:e-4
$[0]: note 1 0x7FFF 3s:e-3
wait 3s
$[0]: note 0 0x7FFF 3s:c#4
$[0]: note 1 0x7FFF 3s:c#3
wait 3s
$[0]: note 0 0x7FFF 3s:d-4
$[0]: note 1 0x7FFF 3s:d-3
wait 3s
$[0]: note 0 0x7FFF 3s:e-4
$[0]: note 1 0x7FFF 3s:e-3
wait 3s
$[0]: note 0 0x7FFF 3s:c#4
$[0]: note 1 0x7FFF 3s:c#3
wait 3s
$[0]: note 0 0x7FFF s:d-4
$[0]: note 1 0x7FFF s:d-3
wait s
$[0]: note 0 0x7FFF s:e-4
$[0]: note 1 0x7FFF s:e-3
wait s
$[0]: note 0 0x7FFF 3s:f-4
$[0]: note 1 0x7FFF 3s:f-3
wait 3s
$[0]: note 0 0x7FFF 3s:g-4
$[0]: note 1 0x7FFF 3s:g-3
wait 3s
$[0]: note 0 0x7FFF 3s:e-4
$[0]: note 1 0x7FFF 3s:e-3
wait 3s
$[0]: note 0 0x7FFF 3s:f-4
$[0]: note 1 0x7FFF 3s:f-3
wait 3s
$[0]: note 0 0x7FFF 3s:g-4
$[0]: note 1 0x7FFF 3s:g-3
wait 3s
$[0]: note 0 0x7FFF 3s:e-4
$[0]: note 1 0x7FFF 3s:e-3
wait 3s
$[0]: note 0 0x7FFF 3s:f-4
$[0]: note 1 0x7FFF 3s:f-3
wait 3s
$[0]: note 0 0x7FFF 3s:g-4
$[0]: note 1 0x7FFF 3s:g-3
wait 3s
$[0]: note 0 0x7FFF 3s:e-4
$[0]: note 1 0x7FFF 3s:e-3
wait 3s
$[0]: note 0 0x7FFF s:f-4
$[0]: note 1 0x7FFF s:f-3
wait s
$[0]: note 0 0x7FFF s:g-4
$[0]: note 1 0x7FFF s:g-3
wait s
;bar 5
$[0]: note 0 0x7FFF 3s:a-4
$[0]: note 1 0x7FFF 3s:a-3
wait 3s
$[0]: note 0 0x7FFF 3s:a#4
$[0]: note 1 0x7FFF 3s:a#3
wait 3s
$[0]: note 0 0x7FFF 3s:g-4
$[0]: note 1 0x7FFF 3s:g-3
wait 3s
$[0]: note 0 0x7FFF 3s:a-4
$[0]: note 1 0x7FFF 3s:a-3
wait 3s
$[0]: note 0 0x7FFF 3s:a#4
$[0]: note 1 0x7FFF 3s:a#3
wait 3s
$[0]: note 0 0x7FFF 3s:g-4
$[0]: note 1 0x7FFF 3s:g-3
wait 3s
$[0]: note 0 0x7FFF 3s:a-4
$[0]: note 1 0x7FFF 3s:a-3
wait 3s
$[0]: note 0 0x7FFF 3s:a#4
$[0]: note 1 0x7FFF 3s:a#3
wait 3s
$[0]: note 0 0x7FFF 3s:g-4
$[0]: note 1 0x7FFF 3s:g-3
wait 3s
$[0]: note 0 0x7FFF s:a-4
$[0]: note 1 0x7FFF s:a-3
wait s+s+q+o+s
$[0]: note 0 0x7FFF s:c#5
$[0]: note 1 0x7FFF s:c#4
wait s
;bar 6
$[0]: note 0 0x7FFF 3s:d-5
$[0]: note 1 0x7FFF 3s:d-4
wait 3s
$[0]: note 0 0x7FFF 3s:e-5
$[0]: note 1 0x7FFF 3s:e-4
wait 3s
$[0]: note 0 0x7FFF 3s:c#5
$[0]: note 1 0x7FFF 3s:c#4
wait 3s
$[0]: note 0 0x7FFF 3s:d-5
$[0]: note 1 0x7FFF 3s:d-4
wait 3s
$[0]: note 0 0x7FFF 3s:e-5
$[0]: note 1 0x7FFF 3s:e-4
wait 3s
$[0]: note 0 0x7FFF 3s:c#5
$[0]: note 1 0x7FFF 3s:c#4
wait 3s
$[0]: note 0 0x7FFF 3s:d-5
$[0]: note 1 0x7FFF 3s:d-4
wait 3s
$[0]: note 0 0x7FFF 3s:e-5
$[0]: note 1 0x7FFF 3s:e-4
wait 3s
$[0]: note 0 0x7FFF 3s:c#5
$[0]: note 1 0x7FFF 3s:c#4
wait 3s
$[0]: note 0 0x7FFF s:d-5
$[0]: note 1 0x7FFF s:d-4
wait s
$[0]: note 0 0x7FFF s:e-5
$[0]: note 1 0x7FFF s:e-4
wait s
$[0]: note 0 0x7FFF 3s:f-5
$[0]: note 1 0x7FFF 3s:f-4
wait 3s
$[0]: note 0 0x7FFF 3s:g-5
$[0]: note 1 0x7FFF 3s:g-4
wait 3s
$[0]: note 0 0x7FFF 3s:e-5
$[0]: note 1 0x7FFF 3s:e-4
wait 3s
$[0]: note 0 0x7FFF 3s:f-5
$[0]: note 1 0x7FFF 3s:f-4
wait 3s
$[0]: note 0 0x7FFF 3s:g-5
$[0]: note 1 0x7FFF 3s:g-4
wait 3s
$[0]: note 0 0x7FFF 3s:e-5
$[0]: note 1 0x7FFF 3s:e-4
wait 3s
$[0]: note 0 0x7FFF 3s:f-5
$[0]: note 1 0x7FFF 3s:f-4
wait 3s
$[0]: note 0 0x7FFF 3s:g-5
$[0]: note 1 0x7FFF 3s:g-4
wait 3s
$[0]: note 0 0x7FFF 3s:e-5
$[0]: note 1 0x7FFF 3s:e-4
wait 3s
$[0]: note 0 0x7FFF s:f-5
$[0]: note 1 0x7FFF s:f-4
wait s
$[0]: note 0 0x7FFF s:g-5
$[0]: note 1 0x7FFF s:g-4
wait s
;bar 7
$[0]: note 0 0x7FFF 3s:a-5
$[0]: note 1 0x7FFF 3s:a-4
wait 3s
$[0]: note 0 0x7FFF 3s:a#5
$[0]: note 1 0x7FFF 3s:a#4
wait 3s
$[0]: note 0 0x7FFF 3s:g-5
$[0]: note 1 0x7FFF 3s:g-4
wait 3s
$[0]: note 0 0x7FFF 3s:a-5
$[0]: note 1 0x7FFF 3s:a-4
wait 3s
$[0]: note 0 0x7FFF 3s:a#5
$[0]: note 1 0x7FFF 3s:a#4
wait 3s
$[0]: note 0 0x7FFF 3s:g-5
$[0]: note 1 0x7FFF 3s:g-4
wait 3s
$[0]: note 0 0x7FFF 3s:a-5
$[0]: note 1 0x7FFF 3s:a-4
wait 3s
$[0]: note 0 0x7FFF 3s:a#5
$[0]: note 1 0x7FFF 3s:a#4
wait 3s
$[0]: note 0 0x7FFF 3s:g-5
$[0]: note 1 0x7FFF 3s:g-4
wait 3s
$[0]: note 0 0x7FFF s:a-5
$[0]: note 1 0x7FFF s:a-4
wait s+s+q+o+s
$[0]: note 0 0x7FFF s:a-5
$[0]: note 1 0x7FFF s:a-4
wait s
;bar 8
$[0]: note 0 0x7FFF 3s:g-5
$[0]: note 1 0x7FFF 3s:g-4
wait 3s
$[0]: note 0 0x7FFF 3s:a#5
$[0]: note 1 0x7FFF 3s:a#4
wait 3s
$[0]: note 0 0x7FFF 3s:e-5
$[0]: note 1 0x7FFF 3s:e-4
wait 3s
$[0]: note 0 0x7FFF 3s:g-5
$[0]: note 1 0x7FFF 3s:g-4
wait 3s
$[0]: note 0 0x7FFF 3s:a#5
$[0]: note 1 0x7FFF 3s:a#4
wait 3s
$[0]: note 0 0x7FFF 3s:e-5
$[0]: note 1 0x7FFF 3s:e-4
wait 3s
$[0]: note 0 0x7FFF 3s:f-5
$[0]: note 1 0x7FFF 3s:f-4
wait 3s
$[0]: note 0 0x7FFF 3s:a-5
$[0]: note 1 0x7FFF 3s:a-4
wait 3s
$[0]: note 0 0x7FFF 3s:d-5
$[0]: note 1 0x7FFF 3s:d-4
wait 3s
$[0]: note 0 0x7FFF 3s:f-5
$[0]: note 1 0x7FFF 3s:f-4
wait 3s
$[0]: note 0 0x7FFF 3s:a-5
$[0]: note 1 0x7FFF 3s:a-4
wait 3s
$[0]: note 0 0x7FFF 3s:d-5
$[0]: note 1 0x7FFF 3s:d-4
wait 3s
$[0]: note 0 0x7FFF 3s:e-5
$[0]: note 1 0x7FFF 3s:e-4
wait 3s
$[0]: note 0 0x7FFF 3s:g-5
$[0]: note 1 0x7FFF 3s:g-4
wait 3s
$[0]: note 0 0x7FFF 3s:c-5
$[0]: note 1 0x7FFF 3s:c-4
wait 3s
$[0]: note 0 0x7FFF 3s:e-5
$[0]: note 1 0x7FFF 3s:e-4
wait 3s
$[0]: note 0 0x7FFF 3s:g-5
$[0]: note 1 0x7FFF 3s:g-4
wait 3s
$[0]: note 0 0x7FFF 3s:c-5
$[0]: note 1 0x7FFF 3s:c-4
wait 3s
$[0]: note 0 0x7FFF 3s:d-5
$[0]: note 1 0x7FFF 3s:d-4
wait 3s
$[0]: note 0 0x7FFF 3s:f-5
$[0]: note 1 0x7FFF 3s:f-4
wait 3s
$[0]: note 0 0x7FFF 3s:a#4
$[0]: note 1 0x7FFF 3s:a#3
wait 3s
$[0]: note 0 0x7FFF 3s:d-5
$[0]: note 1 0x7FFF 3s:d-4
wait 3s
$[0]: note 0 0x7FFF 3s:f-5
$[0]: note 1 0x7FFF 3s:f-4
wait 3s
$[0]: note 0 0x7FFF 3s:a#4
$[0]: note 1 0x7FFF 3s:a#3
wait 3s
;bar 9
$[0]: note 0 0x7FFF 3s:c-5
$[0]: note 1 0x7FFF 3s:c-4
wait 3s
$[0]: note 0 0x7FFF 3s:e-5
$[0]: note 1 0x7FFF 3s:e-4
wait 3s
$[0]: note 0 0x7FFF 3s:a-4
$[0]: note 1 0x7FFF 3s:a-3
wait 3s
$[0]: note 0 0x7FFF 3s:c-5
$[0]: note 1 0x7FFF 3s:c-4
wait 3s
$[0]: note 0 0x7FFF 3s:e-5
$[0]: note 1 0x7FFF 3s:e-4
wait 3s
$[0]: note 0 0x7FFF 3s:a-4
$[0]: note 1 0x7FFF 3s:a-3
wait 3s
$[0]: note 0 0x7FFF 3s:a#4
$[0]: note 1 0x7FFF 3s:a#3
wait 3s
$[0]: note 0 0x7FFF 3s:d-5
$[0]: note 1 0x7FFF 3s:d-4
wait 3s
$[0]: note 0 0x7FFF 3s:g-4
$[0]: note 1 0x7FFF 3s:g-3
wait 3s
$[0]: note 0 0x7FFF 3s:a#4
$[0]: note 1 0x7FFF 3s:a#3
wait 3s
$[0]: note 0 0x7FFF 3s:d-5
$[0]: note 1 0x7FFF 3s:d-4
wait 3s
$[0]: note 0 0x7FFF 3s:g-4
$[0]: note 1 0x7FFF 3s:g-3
wait 3s
$[0]: note 0 0x7FFF 3s:a-4
$[0]: note 1 0x7FFF 3s:a-3
wait 3s
$[0]: note 0 0x7FFF 3s:c-5
$[0]: note 1 0x7FFF 3s:c-4
wait 3s
$[0]: note 0 0x7FFF 3s:f-4
$[0]: note 1 0x7FFF 3s:f-3
wait 3s
$[0]: note 0 0x7FFF 3s:a-4
$[0]: note 1 0x7FFF 3s:a-3
wait 3s
$[0]: note 0 0x7FFF 3s:c-5
$[0]: note 1 0x7FFF 3s:c-4
wait 3s
$[0]: note 0 0x7FFF 3s:f-4
$[0]: note 1 0x7FFF 3s:f-3
wait 3s
$[0]: note 0 0x7FFF 3s:g-4
$[0]: note 1 0x7FFF 3s:g-3
wait 3s
$[0]: note 0 0x7FFF 3s:a#4
$[0]: note 1 0x7FFF 3s:a#3
wait 3s
$[0]: note 0 0x7FFF 3s:e-4
$[0]: note 1 0x7FFF 3s:e-3
wait 3s
$[0]: note 0 0x7FFF 3s:g-4
$[0]: note 1 0x7FFF 3s:g-3
wait 3s
$[0]: note 0 0x7FFF 3s:a#4
$[0]: note 1 0x7FFF 3s:a#3
wait 3s
$[0]: note 0 0x7FFF 3s:e-4
$[0]: note 1 0x7FFF 3s:e-3
wait 3s
;bar 10
wait w
$[0]: nf 1 0xFFFF 
END