
section .rodata
    drone_data_string: db "%d,%.2lf,%.2lf,%.2lf,%.2lf,%d",10,0     ;printing the target data
   target_data_string: db "%.2lf %.2lf",10,0         ;printing drone dtata




%macro pushFloatToStack 1
    fld dword[%1]
    sub esp,8
    fstp qword[esp]
%endmacro    
  




section .text
  global printer
  extern y_coordinate_target
  extern x_coordinate_target
  extern printf
  extern drones_info
  extern num__of_drones
  extern resume
  extern scheduler_pos
  extern drones_alive_array









printer:
    pushad
    pushFloatToStack y_coordinate_target
    pushFloatToStack x_coordinate_target
    push target_data_string
    call printf
    add esp,20
    popad


    mov ebx,0
    mov eax, dword[drones_info] ;eax points to the drones info
    mov ecx, dword[drones_alive_array] ;to check if a drone is alive

    printer_loop:
       cmp ebx, dword[num__of_drones]
       je done
       inc ebx
       cmp byte[ecx+ebx-1],1 ;check if the drone is dead
       je next_drone
       pushad
       push dword[eax+16] ;push number targets destroyes
       pushFloatToStack eax+12 ;speed
       pushFloatToStack eax+8 ;degree
       pushFloatToStack eax+4 ;y coordinate
       pushFloatToStack eax  ;x coordinate
       push ebx   ;id
       push drone_data_string
       call printf
       add esp,44
       popad
       next_drone:
       add eax,20 ;points to next drone info
       jmp printer_loop

       done:
        mov ebx, dword[scheduler_pos]
        call resume
        jmp printer











