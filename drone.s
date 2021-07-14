BOARD_SIZE EQU 100

section .rodata
   droneAttackDebug : db "Drone ID - %d is within the distance! Destroying..",10,0     ;printing the drone attack
  

%macro changeAngle 0
  push 120
  call get_random_number
  add esp,4
  mov dword[angle],eax
  fld dword[angle]
  fisub dword[sixty]  ;sub 60 to get the [-60,60] range
  fstp dword[angle]
  fld dword[ecx+8] ;load current angle
  fadd dword[angle]  ;add to current  angel the randomize angel
  fild dword[threeSixty] ;load 360
  fcomip   ;check if result is bigger than 360
  ja %%smaller1
  fisub dword[threeSixty] ;if bigger than 360 sub 360
  jmp %%store1
  %%smaller1:
  fild dword[zero]
  fcomip  ;check if result is smaller than 0
  jbe %%store1
  fiadd dword[threeSixty]
  %%store1:
  fstp dword[angle]  ;store result
%endmacro  

%macro moveX 0
  fldpi  ;load pi
  fidiv dword[oneEighty]
  fmul dword[ecx+8] ;get angel in radians
  fsin ;sin angel
  fmul dword[ecx+12] ;mul by speed
  fadd dword[ecx] ;add x current location
%endmacro 


%macro moveY 0
  fldpi  ;load pi
  fidiv dword[oneEighty]
  fmul dword[ecx+8] ;get angel in radians
  fcos ;sin angel
  fmul dword[ecx+12] ;mul by speed
  fadd dword[ecx+4] ;add y current location
%endmacro 

%macro checkVaildAndStore 1
    fild dword [oneHundred]    
    fcomip   
    jae %%not_bigger  ;check if result is bigger than 100
    fisub dword [oneHundred]    ;if bigger sub 100
    jmp %%store2     ;now new x is less than 100 
    %%not_bigger:     
    fild dword [zero]    ;if new x<0
    fcomip  
    jbe  %%store2 
    fiadd dword [oneHundred]    ;if x<0 add 100
    %%store2:
     fstp dword[%1]
%endmacro    

%macro generateNewValuesForDrone 0
  mov eax,20
  mov ebx, dword[roundRobinCounter]
  mul ebx 
  add eax, dword[drones_info]
  mov ecx,eax
  changeAngle  ;change the angle
  moveX 
  checkVaildAndStore ecx ;store in x_coordinate in drone_info
  moveY
  checkVaildAndStore ecx+4 ;store in y_coordinate in drone_info
  mov eax, dword[angle]
  mov dword[ecx+8],eax ;store new angle
%endmacro
 %macro checkIfCanDestroy 0
     finit ; just to make sure we reset it
           ;let's calculate the difference between target and our drone
      fld dword[x_target_temp]
      fsub dword[x_temp] 
      fstp dword[differenceX] ;(x_target-x_drone)

      fld dword[y_target_temp]
      fsub dword[y_temp]
      fstp dword[differenceY] ;(y_target-y_drone)

      fld dword[differenceY]
      fmul dword[differenceY] ; (y_target-y_drone)^2
      fstp dword[differencePowerY]
     
      fld dword[differenceX]
      fmul dword[differenceX] ; (x_target-x_drone)^2
      fstp dword[differencePowerX]

      fld dword[differencePowerY]
      fadd dword[differencePowerX] ; (y_target-y_drone)^2 + (x_target-x_drone)^2
      fsqrt ; stack top has sqrt((y_target-y_drone)^2 + (x_target-x_drone)^2)
      fld dword [distance] ; load the distance for destroying
      fcomip  
      jae canDestroy  ;max Distance >= our calculated distance 
%endmacro      
section .rodata
    sixty: dd 60
    threeSixty: dd 360
    oneEighty: dd 180
    zero: dd 0
    oneHundred: dd 100
    

section .data
    temp: dd 0

    angle: dd 0

    differenceX : dd 0
   
    differenceY : dd 0
    
    differencePowerY : dd 0
    
    differencePowerX : dd 0
    distanceFromTarget:dd 0
    x_temp: dd 0
    y_temp: dd 0
    x_target_temp: dd 0
    y_target_temp: dd 0




section .text
   global drone
   extern scheduler_pos
   extern resume
   extern distance
   extern drones_info
   extern printf
   extern roundRobinCounter
   extern get_random_number
   extern target_pos
   extern x_coordinate_target
   extern y_coordinate_target
   extern is_called_by_scheduler



drone:
    generateNewValuesForDrone
  drone_loop:
     ;to wrap around we look at a new board with size 300X300 build out of 9 boards of size 100
     ; the the drone is in board 5  and we have copy of the traget in each board
     ;| 1 | 2 | 3 |
     ;| 4 | 5 | 6 |
     ;| 7 | 8 | 9 |
      mov eax, dword[ecx]
      mov dword[x_temp],eax 
      mov eax, dword[ecx+4]
      mov dword[y_temp],eax 
      mov eax, dword[x_coordinate_target]
      mov dword[x_target_temp],eax
      mov eax, dword[y_coordinate_target]
      mov dword[y_coordinate_target],eax
      checkIfCanDestroy ;check if can destroy in board 5 (actual board without wrap around)
      ;wrap around check
      add dword[x_temp],BOARD_SIZE
      add dword[y_temp],BOARD_SIZE
      checkIfCanDestroy ;check if can destroy in board 7
      add dword[x_target_temp],BOARD_SIZE
      checkIfCanDestroy ;check if can destroy in board 8
      add dword[x_target_temp],BOARD_SIZE
      checkIfCanDestroy ;check if can destroy in board 9
      add dword[y_target_temp],BOARD_SIZE
      checkIfCanDestroy ;check if can destroy in board 6
      add dword[y_target_temp],BOARD_SIZE
      checkIfCanDestroy ;check if can destroy in board 3
      sub dword[x_target_temp],BOARD_SIZE
      checkIfCanDestroy ;check if can destroy in board 2
      sub dword[x_target_temp],BOARD_SIZE
      checkIfCanDestroy ;check if can destroy in board 1
      sub dword[y_target_temp],BOARD_SIZE
      checkIfCanDestroy ;check if can destroy in board 4
      jmp cantDestroy
     canDestroy:
      inc dword[ecx+16] ;inc number of drones destroyed
      mov dword[is_called_by_scheduler],0 ;Target is being called by drone! 
      mov  ebx, dword[target_pos]
      call resume
      cantDestroy:
      generateNewValuesForDrone 
      mov ebx, dword[scheduler_pos]
      mov dword[is_called_by_scheduler],1
      call resume
      jmp drone_loop












