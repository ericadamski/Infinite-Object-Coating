breed [particles particle]
breed [amoebots amoebot]
breed [components component]

undirected-link-breed [bodies body]
undirected-link-breed [edges edge]

particles-own [ occupied? 
                occupier ]

components-own [ current-particle neighbours ]

amoebots-own [
              direction
              head               ;; head breed
              tail               ;; tail breed
              my-body            ;; undirected link between head and tail
              phase              ;; inactive, follower, leader
              incident-edges     ;; a list of all incident edges at the current location, held as a list of destinations
              neighbours         ;; Two particles occupying adjacent nodes are defined to be connected and we refer to such particles as neighbors
              movement           ;; movment can be idle, expanded, contracted, handoverContracted ...;;
             ]

to setup 
  clear-all
  reset-ticks
  no-display
  
  ask patches [ set pcolor white ]
  
  setup-graph
  setup-amoebots
  
  display
end 

to go
  ask amoebots [ calculate-incident-edges move ]
  tick
end

;;SETUP;;

to setup-graph
  setup-particles
  setup-edges
end

to setup-particles
  set-default-shape particles "circle"
  ;; world-width, world-height
  let number-of-particles ceiling world-height * (world-width / (turtle-size + seperation))
  let ycounter 1
  let xcounter 1
  let modifier 0
  
  while [ycounter < (world-height mod number-of-particles) ]
  [ 
    
    ifelse (ycounter mod 2 = 0) [ set modifier 1 set xcounter xcounter + seperation / 2 ]
                                [ set modifier 0 set xcounter xcounter + seperation ]
      
    while [ xcounter < (world-width mod (number-of-particles - modifier)) ]
    [                     
      create-particles 1 [
        set size turtle-size
        set occupied? false
        set color gray
        setxy ((world-width mod (number-of-particles - modifier)) - xcounter) ((world-height mod number-of-particles) - ycounter)
      ]
      set xcounter xcounter + seperation
    ]
    set ycounter ycounter + seperation 
    set xcounter 1
  ]
end

to setup-edges
  ;; every second row
  ;; every second particle in that row will have 6 edges
  foreach [self] of particles [
   if ( [ycor] of ? mod 2 = 0 or [xcor] of ? mod 2 != 0 )[
     ask ? [
       ;;set color yellow
       let me ?
       foreach filter [ distance ? < ((2 * turtle-size) + seperation) and not member? ? link-neighbors ] [self] of particles [
        if ( ? != me ) [ ask ? [ create-edge-with me [ set color green ] ] ]
       ]
     ]
   ] 
  ]
end

to setup-amoebots
  set-default-shape components "circle"
  let counter 0
  
  while [ counter < population-size ]
  [
    let tmp-head 0
    let tmp-tail 0
    let tmp-body 0
    let part 0
    
    ask particle counter [ set occupied? true 
                           set part self ]
    
    create-components 1 [
      set color black
      set size 0.1 + turtle-size
      set current-particle part
      set neighbours []
      set tmp-head self
      setxy [xcor] of part [ycor] of part
    ]
    create-components 1 [
      set color black
      set size 0.1 + turtle-size
      set current-particle part
      set neighbours []
      create-body-with tmp-head [ 
        set tmp-body self
        set thickness 0.25
        set color black   
      ]
      set tmp-tail self
      setxy [xcor] of part [ycor] of part
    ]
    create-amoebots 1 [
      let me self
      ask part [ set occupier me ]
      set phase "inactive"
      set head tmp-head
      set tail tmp-tail
      set my-body tmp-body
      set incident-edges []
      set neighbours []
      set phase "inactive"
      set movement "contracted"
      setxy [xcor] of part [ycor] of part;;
      ;;hide-turtle
    ]
    set counter increment counter
  ]
end

to move
  span-forest
end

;; HELPERS ;;

to-report next-move
  ;; leader only
  calculate-incident-edges
  let me [current-particle] of tail
  let free-edges filter [ [who] of last ? >= [who] of me ] filter [ is-particle? last ? ] incident-edges
  if (not empty? free-edges) [ report first one-of free-edges ]
  report direction
end

to span-forest
  ;; done := false
  ;; if inactive and not done
  ;;    if connected-to-surface?
  ;;        phase := leader
  ;;        movement := idle
  ;;        done := true
  ;;    if filter neighbours with phase leader or follower not empty
  ;;        direction := toward first of the filter statement above
  ;;        phase := follower
  ;;        done := true
  ;; if follower and not done
  ;;    if movement is contracted and connected-to-surface?
  ;;        phase := leader
  ;;        movement := idle
  ;;        done := true
  ;;    if movement is contracted and direction is expanded
  ;;        expand to direction (i.e. attempt-handover)
  ;;        direction := direction of direction
  ;;    if movement is expanded 
  ;;        if any neighbours of tail are followers
  ;;          move := handoverContraction
  ;;        if no neighbours of tail are followers and no inactive neighbours
  ;;          move := contract
  ;; if leader and not done
  ;;    if contracted
  ;;      move := expand
  ;;      direction := next-move
  ;;    if expanded
  ;;        if any neighbours of tail ar followers
  ;;          move := handoverContraction
  ;;        if no neighbours of tail are followers and no inactive neighbours
  ;;          move := contract
  let done false
  
  if (phase = "inactive" and not done)
  [
    let leader-follower-neighbours filter [ [phase] of last ? = "leader" or [phase] of last ? = "follower" ] filter [ is-amoebot? last ? ] incident-edges
    if (connected-to-surface?) 
    [
      set phase "leader"
      idle
    ]
    if (not empty? leader-follower-neighbours)
    [
      set direction one-of map [ first ? ] leader-follower-neighbours
      set phase "follower"
    ]
    set done true
  ]
  if (phase = "follower" and not done)
  [
    if (movement = "contracted" and connected-to-surface?)
    [
      set phase "leader"
      idle
      set done true
    ]
    if (movement = "contracted" and not done)
    [
      let d direction
      let leader last reduce sentence filter [ first ? = d ] incident-edges 
      if ([movement] of leader = "expanded")
      [
        set direction [direction] of leader 
        ask leader [ handover ]
        handover
      ]
      set done true
    ]
    if (movement = "expanded" and not done)
    [
      let tail-followers filter [ [phase] of ? = "follower" and [movement] of ? = "expanded" ] filter [ is-amoebot? ? ] [neighbours] of tail
      ifelse (not empty? tail-followers)
      [
        ask first tail-followers [ handover ]
      ]
      [ if (not empty? filter [ [phase] of ? = "inactive" ] filter [ is-amoebot? ? ] neighbours)[ contract ] ]
    ]
    set done true
  ]
  if (phase = "leader" and not done)
  [
    if (movement = "contracted")
    [
      set direction next-move
      expand
      set done true
    ] 
    if (movement = "expanded" and not done)
    [
      contract
    ]
  ]
end

to complain
  ;; if leader
  ;;   s := next-move
  ;;   if contracted and s = {} and any neighbours are followers or complaining
  ;;      send 'complaint' -> s
  ;;      idle
  ;;   endif
  ;;   if contracted and no neighbours are complaining
  ;;      idle
  ;;   end
  ;; endif
  ;;
  ;; do spanning-forest
end

;; Movement ;;
to idle
  set movement "contracted"
end

to expand
  set movement "expanded"
  ;; move head to direction
  move-amoebot
end

to contract
  set movement "contracted"
  move-amoebot
end

to handover
  ifelse (movement = "contracted" )
  [ expand ]
  [ contract ]
end

to move-amoebot
  calculate-incident-edges
  if ( movement = "expanded" )
  [ ;; move the head ;; 
    let leader get-leader
    let me self
    ask head [
      setxy [xcor] of leader [ycor] of leader
      ifelse ( is-amoebot? leader )
      [ set current-particle [current-particle] of [head] of leader ]
      [ set current-particle leader ]
      ask current-particle [
        set occupied? true
        set occupier me
      ]
    ]
    setxy [xcor] of head [ycor] of head
  ]
  if ( movement = "contracted" )
  [ ;; move the tail ;; 
    let h head
    ask tail [
      ask current-particle [ move-component ]
      set current-particle [current-particle] of h
      setxy [xcor] of h [ycor] of h 
    ]
  ]
end

to move-component
  ;; set occupied to false
  set occupied? false
  ;; change occupier
  set occupier ""
end
;;;;;;;;;;;;;;

to-report connected-to-surface?
  report not empty? filter [ is-particle? last ? ] incident-edges  
end

to calculate-incident-edges
  let me self
  set neighbours []
  set incident-edges []
  ask head [ set neighbours [] ]
  ask tail [ set neighbours [] ]
  let counter 0
  if (movement = "expanded")
  [
    ask particles [ set color grey ]
    ;;expanded
    ask [current-particle] of tail [
      ;;show link-neighbors
      ask link-neighbors [ set color red ]
      foreach [self] of link-neighbors[
        let amoeba ?
        let occupied [occupied?] of ?
        if (occupied) [ set amoeba [occupier] of ? ]
        if (not occupied)
        [
          let add list counter amoeba
          ask me [
            ask tail [ set neighbours union (list amoeba) neighbours ]
            set incident-edges fput add incident-edges
          ]
          set counter increment counter
        ]
      ]
    ]
  ]
  ;;contracted
  ask [current-particle] of head [
    ;;show [self] of link-neighbors
    ask link-neighbors [ set color red ]
    foreach [self] of link-neighbors [
      let amoeba ?
      let occupied [occupied?] of ?
      if (not occupied)
      [
        let add list counter amoeba
        ask me [
          ask head [ set neighbours union (list amoeba) neighbours ]
          set incident-edges fput add incident-edges
        ]
        set counter increment counter
      ]
    ]
  ]
  ;;show [neighbours] of head
  ;;show [neighbours] of tail
  ;;show neighbours
  set neighbours union [neighbours] of tail [neighbours] of head
end

to-report get-leader
  let d direction
  let leaders filter [ first ? = d ] incident-edges
  ifelse ( not empty? leaders )
  [ report last reduce sentence leaders ]
  [ report self ]
end

to-report increment [counter]
  report counter + 1
end

to-report middle [triple]
  report first but-first triple
end

to-report intersection [list1 list2]
  report filter [ member? ? list1 ] list2
end

to-report union [list1 list2]
  if empty? list1 [ report list2 ]
  if empty? list2 [ report list1 ]
  let intersect intersection list1 list2
  let not-intersect2 filter [ not member? ? intersect ] list2
  let not-intersect1 filter [ not member? ? intersect ] list1
  report sentence sentence not-intersect1 not-intersect2 intersect
end
@#$#@#$#@
GRAPHICS-WINDOW
243
10
1057
845
-1
-1
12.0
1
10
1
1
1
0
0
0
1
0
66
0
66
0
0
1
ticks
30.0

BUTTON
10
118
172
151
Setup
setup
NIL
1
T
OBSERVER
NIL
NIL
NIL
NIL
1

SLIDER
9
80
234
113
turtle-size
turtle-size
0.25
0.95
0.5
0.05
1
NIL
HORIZONTAL

SLIDER
9
41
234
74
seperation
seperation
1
7
3
2
1
NIL
HORIZONTAL

CHOOSER
9
156
232
201
population-size-5
population-size-5
196 64 39 27
0

BUTTON
178
118
233
151
Go
go
T
1
T
OBSERVER
NIL
NIL
NIL
NIL
1

BUTTON
11
205
232
238
Slow Go
go
NIL
1
T
OBSERVER
NIL
NIL
NIL
NIL
1

SLIDER
13
242
230
275
population-size
population-size
1
1000
64
1
1
NIL
HORIZONTAL

@#$#@#$#@
## WHAT IS IT?

(a general understanding of what the model is trying to show or explain)

## HOW IT WORKS

(what rules the agents use to create the overall behavior of the model)

## HOW TO USE IT

(how to use the model, including a description of each of the items in the Interface tab)

## THINGS TO NOTICE

(suggested things for the user to notice while running the model)

## THINGS TO TRY

(suggested things for the user to try to do (move sliders, switches, etc.) with the model)

## EXTENDING THE MODEL

(suggested things to add or change in the Code tab to make the model more complicated, detailed, accurate, etc.)

## NETLOGO FEATURES

(interesting or unusual features of NetLogo that the model uses, particularly in the Code tab; or where workarounds were needed for missing features)

## RELATED MODELS

(models in the NetLogo Models Library and elsewhere which are of related interest)

## CREDITS AND REFERENCES

(a reference to the model's URL on the web if it has one, as well as any other necessary credits, citations, and links)
@#$#@#$#@
default
true
0
Polygon -7500403 true true 150 5 40 250 150 205 260 250

airplane
true
0
Polygon -7500403 true true 150 0 135 15 120 60 120 105 15 165 15 195 120 180 135 240 105 270 120 285 150 270 180 285 210 270 165 240 180 180 285 195 285 165 180 105 180 60 165 15

arrow
true
0
Polygon -7500403 true true 150 0 0 150 105 150 105 293 195 293 195 150 300 150

box
false
0
Polygon -7500403 true true 150 285 285 225 285 75 150 135
Polygon -7500403 true true 150 135 15 75 150 15 285 75
Polygon -7500403 true true 15 75 15 225 150 285 150 135
Line -16777216 false 150 285 150 135
Line -16777216 false 150 135 15 75
Line -16777216 false 150 135 285 75

bug
true
0
Circle -7500403 true true 96 182 108
Circle -7500403 true true 110 127 80
Circle -7500403 true true 110 75 80
Line -7500403 true 150 100 80 30
Line -7500403 true 150 100 220 30

butterfly
true
0
Polygon -7500403 true true 150 165 209 199 225 225 225 255 195 270 165 255 150 240
Polygon -7500403 true true 150 165 89 198 75 225 75 255 105 270 135 255 150 240
Polygon -7500403 true true 139 148 100 105 55 90 25 90 10 105 10 135 25 180 40 195 85 194 139 163
Polygon -7500403 true true 162 150 200 105 245 90 275 90 290 105 290 135 275 180 260 195 215 195 162 165
Polygon -16777216 true false 150 255 135 225 120 150 135 120 150 105 165 120 180 150 165 225
Circle -16777216 true false 135 90 30
Line -16777216 false 150 105 195 60
Line -16777216 false 150 105 105 60

car
false
0
Polygon -7500403 true true 300 180 279 164 261 144 240 135 226 132 213 106 203 84 185 63 159 50 135 50 75 60 0 150 0 165 0 225 300 225 300 180
Circle -16777216 true false 180 180 90
Circle -16777216 true false 30 180 90
Polygon -16777216 true false 162 80 132 78 134 135 209 135 194 105 189 96 180 89
Circle -7500403 true true 47 195 58
Circle -7500403 true true 195 195 58

circle
false
0
Circle -7500403 true true 0 0 300

circle 2
false
0
Circle -7500403 true true 0 0 300
Circle -16777216 true false 30 30 240

cow
false
0
Polygon -7500403 true true 200 193 197 249 179 249 177 196 166 187 140 189 93 191 78 179 72 211 49 209 48 181 37 149 25 120 25 89 45 72 103 84 179 75 198 76 252 64 272 81 293 103 285 121 255 121 242 118 224 167
Polygon -7500403 true true 73 210 86 251 62 249 48 208
Polygon -7500403 true true 25 114 16 195 9 204 23 213 25 200 39 123

cylinder
false
0
Circle -7500403 true true 0 0 300

dot
false
0
Circle -7500403 true true 90 90 120

face happy
false
0
Circle -7500403 true true 8 8 285
Circle -16777216 true false 60 75 60
Circle -16777216 true false 180 75 60
Polygon -16777216 true false 150 255 90 239 62 213 47 191 67 179 90 203 109 218 150 225 192 218 210 203 227 181 251 194 236 217 212 240

face neutral
false
0
Circle -7500403 true true 8 7 285
Circle -16777216 true false 60 75 60
Circle -16777216 true false 180 75 60
Rectangle -16777216 true false 60 195 240 225

face sad
false
0
Circle -7500403 true true 8 8 285
Circle -16777216 true false 60 75 60
Circle -16777216 true false 180 75 60
Polygon -16777216 true false 150 168 90 184 62 210 47 232 67 244 90 220 109 205 150 198 192 205 210 220 227 242 251 229 236 206 212 183

fish
false
0
Polygon -1 true false 44 131 21 87 15 86 0 120 15 150 0 180 13 214 20 212 45 166
Polygon -1 true false 135 195 119 235 95 218 76 210 46 204 60 165
Polygon -1 true false 75 45 83 77 71 103 86 114 166 78 135 60
Polygon -7500403 true true 30 136 151 77 226 81 280 119 292 146 292 160 287 170 270 195 195 210 151 212 30 166
Circle -16777216 true false 215 106 30

flag
false
0
Rectangle -7500403 true true 60 15 75 300
Polygon -7500403 true true 90 150 270 90 90 30
Line -7500403 true 75 135 90 135
Line -7500403 true 75 45 90 45

flower
false
0
Polygon -10899396 true false 135 120 165 165 180 210 180 240 150 300 165 300 195 240 195 195 165 135
Circle -7500403 true true 85 132 38
Circle -7500403 true true 130 147 38
Circle -7500403 true true 192 85 38
Circle -7500403 true true 85 40 38
Circle -7500403 true true 177 40 38
Circle -7500403 true true 177 132 38
Circle -7500403 true true 70 85 38
Circle -7500403 true true 130 25 38
Circle -7500403 true true 96 51 108
Circle -16777216 true false 113 68 74
Polygon -10899396 true false 189 233 219 188 249 173 279 188 234 218
Polygon -10899396 true false 180 255 150 210 105 210 75 240 135 240

house
false
0
Rectangle -7500403 true true 45 120 255 285
Rectangle -16777216 true false 120 210 180 285
Polygon -7500403 true true 15 120 150 15 285 120
Line -16777216 false 30 120 270 120

leaf
false
0
Polygon -7500403 true true 150 210 135 195 120 210 60 210 30 195 60 180 60 165 15 135 30 120 15 105 40 104 45 90 60 90 90 105 105 120 120 120 105 60 120 60 135 30 150 15 165 30 180 60 195 60 180 120 195 120 210 105 240 90 255 90 263 104 285 105 270 120 285 135 240 165 240 180 270 195 240 210 180 210 165 195
Polygon -7500403 true true 135 195 135 240 120 255 105 255 105 285 135 285 165 240 165 195

line
true
0
Line -7500403 true 150 0 150 300

line half
true
0
Line -7500403 true 150 0 150 150

pentagon
false
0
Polygon -7500403 true true 150 15 15 120 60 285 240 285 285 120

person
false
0
Circle -7500403 true true 110 5 80
Polygon -7500403 true true 105 90 120 195 90 285 105 300 135 300 150 225 165 300 195 300 210 285 180 195 195 90
Rectangle -7500403 true true 127 79 172 94
Polygon -7500403 true true 195 90 240 150 225 180 165 105
Polygon -7500403 true true 105 90 60 150 75 180 135 105

plant
false
0
Rectangle -7500403 true true 135 90 165 300
Polygon -7500403 true true 135 255 90 210 45 195 75 255 135 285
Polygon -7500403 true true 165 255 210 210 255 195 225 255 165 285
Polygon -7500403 true true 135 180 90 135 45 120 75 180 135 210
Polygon -7500403 true true 165 180 165 210 225 180 255 120 210 135
Polygon -7500403 true true 135 105 90 60 45 45 75 105 135 135
Polygon -7500403 true true 165 105 165 135 225 105 255 45 210 60
Polygon -7500403 true true 135 90 120 45 150 15 180 45 165 90

sheep
false
15
Circle -1 true true 203 65 88
Circle -1 true true 70 65 162
Circle -1 true true 150 105 120
Polygon -7500403 true false 218 120 240 165 255 165 278 120
Circle -7500403 true false 214 72 67
Rectangle -1 true true 164 223 179 298
Polygon -1 true true 45 285 30 285 30 240 15 195 45 210
Circle -1 true true 3 83 150
Rectangle -1 true true 65 221 80 296
Polygon -1 true true 195 285 210 285 210 240 240 210 195 210
Polygon -7500403 true false 276 85 285 105 302 99 294 83
Polygon -7500403 true false 219 85 210 105 193 99 201 83

square
false
0
Rectangle -7500403 true true 30 30 270 270

square 2
false
0
Rectangle -7500403 true true 30 30 270 270
Rectangle -16777216 true false 60 60 240 240

star
false
0
Polygon -7500403 true true 151 1 185 108 298 108 207 175 242 282 151 216 59 282 94 175 3 108 116 108

target
false
0
Circle -7500403 true true 0 0 300
Circle -16777216 true false 30 30 240
Circle -7500403 true true 60 60 180
Circle -16777216 true false 90 90 120
Circle -7500403 true true 120 120 60

tree
false
0
Circle -7500403 true true 118 3 94
Rectangle -6459832 true false 120 195 180 300
Circle -7500403 true true 65 21 108
Circle -7500403 true true 116 41 127
Circle -7500403 true true 45 90 120
Circle -7500403 true true 104 74 152

triangle
false
0
Polygon -7500403 true true 150 30 15 255 285 255

triangle 2
false
0
Polygon -7500403 true true 150 30 15 255 285 255
Polygon -16777216 true false 151 99 225 223 75 224

truck
false
0
Rectangle -7500403 true true 4 45 195 187
Polygon -7500403 true true 296 193 296 150 259 134 244 104 208 104 207 194
Rectangle -1 true false 195 60 195 105
Polygon -16777216 true false 238 112 252 141 219 141 218 112
Circle -16777216 true false 234 174 42
Rectangle -7500403 true true 181 185 214 194
Circle -16777216 true false 144 174 42
Circle -16777216 true false 24 174 42
Circle -7500403 false true 24 174 42
Circle -7500403 false true 144 174 42
Circle -7500403 false true 234 174 42

turtle
true
0
Polygon -10899396 true false 215 204 240 233 246 254 228 266 215 252 193 210
Polygon -10899396 true false 195 90 225 75 245 75 260 89 269 108 261 124 240 105 225 105 210 105
Polygon -10899396 true false 105 90 75 75 55 75 40 89 31 108 39 124 60 105 75 105 90 105
Polygon -10899396 true false 132 85 134 64 107 51 108 17 150 2 192 18 192 52 169 65 172 87
Polygon -10899396 true false 85 204 60 233 54 254 72 266 85 252 107 210
Polygon -7500403 true true 119 75 179 75 209 101 224 135 220 225 175 261 128 261 81 224 74 135 88 99

wheel
false
0
Circle -7500403 true true 3 3 294
Circle -16777216 true false 30 30 240
Line -7500403 true 150 285 150 15
Line -7500403 true 15 150 285 150
Circle -7500403 true true 120 120 60
Line -7500403 true 216 40 79 269
Line -7500403 true 40 84 269 221
Line -7500403 true 40 216 269 79
Line -7500403 true 84 40 221 269

wolf
false
0
Polygon -16777216 true false 253 133 245 131 245 133
Polygon -7500403 true true 2 194 13 197 30 191 38 193 38 205 20 226 20 257 27 265 38 266 40 260 31 253 31 230 60 206 68 198 75 209 66 228 65 243 82 261 84 268 100 267 103 261 77 239 79 231 100 207 98 196 119 201 143 202 160 195 166 210 172 213 173 238 167 251 160 248 154 265 169 264 178 247 186 240 198 260 200 271 217 271 219 262 207 258 195 230 192 198 210 184 227 164 242 144 259 145 284 151 277 141 293 140 299 134 297 127 273 119 270 105
Polygon -7500403 true true -1 195 14 180 36 166 40 153 53 140 82 131 134 133 159 126 188 115 227 108 236 102 238 98 268 86 269 92 281 87 269 103 269 113

x
false
0
Polygon -7500403 true true 270 75 225 30 30 225 75 270
Polygon -7500403 true true 30 75 75 30 270 225 225 270

@#$#@#$#@
NetLogo 5.1.0
@#$#@#$#@
@#$#@#$#@
@#$#@#$#@
@#$#@#$#@
@#$#@#$#@
default
0.0
-0.2 0 0.0 1.0
0.0 1 1.0 0.0
0.2 0 0.0 1.0
link direction
true
0
Line -7500403 true 150 150 90 180
Line -7500403 true 150 150 210 180

@#$#@#$#@
0
@#$#@#$#@
