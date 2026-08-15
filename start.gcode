;============================================================
;========= Start G-code for Bambu Lab P1S WITH AMS ==========
;======== Author: CaosMaker (Edited by roffiervalj)==========
;======================= Version: 2.7.1 =====================
;============ Please read readme.md for info ================
;============================================================

;===== Reset machine and prepare for startup ================
G90
M17 X1.2 Y1.2 Z0.75                          ; reset motor current
M220 S100                                    ; Reset Feedrate
M221 S100                                    ; Reset Flowrate
M73.2 R1.0                                   ; Reset left time magnitude
M204 S10000                                  ; init ACC set to 10m/s^2
G29.1 Z{+0.0}                                ; clear z-trim value

;===== Set fans initial state ===============================
M106 P1 S0                                   ; part
M106 P2 S0                                   ; aux
M106 P3 S0                                   ; chamber
M710 A1 S255                                 ; MC board fan auto


;===== Preheat bed and nozzle then home =====================
M1002 gcode_claim_action :2                  ; display: heating bed
M140 S[bed_temperature_initial_layer_single] ; set bed temp
M104 S140                                    ; set extruder temp to 140 to reduce oozing but melt any residue
M190 S[bed_temperature_initial_layer_single] ; wait for bed temp
M1002 gcode_claim_action : 7                 ; display: heating hotend
M109 S140                                    ; wait for extruder temp
G29.2 S1                                     ; turn on ABL

M1002 judge_flag g29_before_print_flag
M622 J1
    G29 A X{first_layer_print_min[0]} Y{first_layer_print_min[1]} I{first_layer_print_size[0]} J{first_layer_print_size[1]}
    M400                                       ; wait
    G1 X128 Y128 Z10 F20000                    ; Mech Mode Fast Check
    M970.3 Q1 A7 B30 C80 H15 K0
    M974 Q1 S2 P0
    M400 P200
    M970.3 Q0 A7 B30 C90 Q0 H15 K0
    M974 Q0 S2 P0
    M400                                       ; wait
    M500                                       ; save
M623

M1002 judge_flag g29_before_print_flag
M622 J0

    M1002 gcode_claim_action : 13
    G28

M623

;===== prepare AMS ==========================================
M1002 gcode_claim_action :4                  ; display: loading filament
G1 Z10                                       ; lift z
M620 M
M620 S[initial_extruder]A                    ; switch material if AMS exists
{if initial_tool != initial_extruder}        ; filament actually needs to change — full cut/reload
    M620 S[initial_extruder]A                ; switch material if AMS exists
        G1 X65 Y265 F12000                   ; go to park
        M109 S{nozzle_temperature_range_high[initial_extruder]}
        G92 E0                               ; zero the extruder
        G1 E-15 F200                         ; retract 15 mm
        ; Cutter sequence
        G1 X120 F12000
        G1 X20 Y50 F12000                    ; go to cut position
        G1 Y-3                               ; cut
        T[initial_extruder]
        G1 X65 Y265 F12000                   ; go to park
    M621 S[initial_extruder]A
{else}                                       ; same filament already loaded — skip the cut, light refresh only
    M620 S[initial_extruder]A
    G1 X65 Y265 F12000                       ; go to park
    M109 S{nozzle_temperature_range_high[initial_extruder]}
    G92 E0
    G1 E4 F300                               ; small refresh purge — no cut/reload needed
    M621 S[initial_extruder]A
{endif}
M620.1 E F{filament_max_volumetric_speed[initial_extruder]/2.4053*60} T{nozzle_temperature_range_high[initial_extruder]}

;===== purge extruder and nozzle ============================
M412 S1                                      ; turn on filament runout detection
G1 X65 Y265 F12000                           ; move to purge area
M106 P1 S0                                   ; Part fan off
M1002 gcode_claim_action : 7                 ; display: heating hotend
M109 S{nozzle_temperature_range_high[initial_extruder]} ; set and wait nozzle to common flush temp
M1002 gcode_claim_action : 14                ; display: cleaning nozzle
G92 E0
G1 E20 F200                                  ; purge 20mm
M400
{if initial_tool!=initial_extruder}          ; if the filament has been changed
  G92 E0
  G1 E60 F350                                ; extra purge only on change
  M400
{endif}
G92 E0
G1 E-1 F300                                  ; retract 1mm
M104 S{nozzle_temperature_initial_layer[initial_extruder]-20}   ; drop nozzle temp to make filament shrink
M106 P1 S255                                 ; Part fan full
M400 S5                                      ; wait 5 sec
M104 S[nozzle_temperature_initial_layer]     ; nozzle at print temperature
G92 E0
G1 E-1 F300                                  ; retract 1mm
M400                                         ; wait to finish

M106 P1 S125                                 ; Part fan mid power


;===== Shake sequence =======================================
G1 X70 F9000
G1 X76 F15000
G1 X65 F15000                                ; shake to put down garbage
G1 X80 F6000
G1 X165 F15000
M400

;===== Wipe sequence ========================================
G1 X65 Y230 F18000                           ; return to park
G1 Y264 F6000
G1 X100 F18000                               ; first wipe
G1 X60 Y265
G1 X100 F5000                                ; second wipe
G1 X70 Y263 F15000
G1 X100 F5000                                ; third wipe
G1 X65 Y264 F15000
M400

;===== nozzle load line =====================================
M975 S1
G90
M83
T1000
G1 X100 Y-3 Z0.8 F18000                      ;Move to start position much closer to front panel
M109 S{nozzle_temperature_initial_layer[initial_extruder]}
G1 Z0.2                                      ;same as stock code
G0 E2 F300                                   ;same as stock code
G0 X150 E15 F3000                            ;purges at 50mm per second
M400

;===== start print ==========================================

M106 P1 S0                                   ; Part fan off
M975 S1                                      ; turn on vibration suppression
M1002 gcode_claim_action : 7                 ; display: heating hotend
M109 S[nozzle_temperature_initial_layer]     ; wait for extruder temp
G28 X Y                                      ; home xy
G90                                          ; absolute positioning
M83                                          ; extruder to relative pos

{if curr_bed_type=="Textured PEI Plate"}     ; for texture PEI plate
    G29.1 Z{-0.04}                           ; lower z offset
{endif}

M106 P1 S0                                   ; part fan off
M106 P2 S0                                   ; aux fan off
M106 P3 S0                                   ; chamber fan off
M1002 gcode_claim_action : 0                 ; reset status

;===========================================================
;== Disclaimer: In any case the author cannot be held  =====
;==== responsible for any damage or unwanted effect as =====
;== result of using this code on any machine. Please read ==
;===== the readme.md file to properly test the code. =======
;===========================================================