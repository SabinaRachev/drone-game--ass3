
BOARD_SIZE EQU 100

section .rodata
  decimal_string: db "%d",0
  float_string: db "%f",0
   max_int: dd 0xFFFF
   STKSZ: dd 16384

section .bss
   global CORS
   global num_cors
   global drones_stack
   global drones_info
   global scheduler_stack
   global printer_stack
   global printer_pos
   global distance
   global scheduler_pos
   global num__of_drones
   global drone_steps_printing
   global drones_alive_array
   global num_alive_drones
   global drone_steps_target
   global target_pos
   global num_scheduler_cycles

   num__of_drones:resd 1
   num_scheduler_cycles:resd 1
   max_distance: resd 1
   drone_steps_printing: resd 1
   drone_steps_target: resd 1
   distance:resd 1

   drones_stack:resd 1

   drones_info:resd 1

   drones_alive_array:resd 1

   num_alive_drones:resd 1

   temp_value:resd 1

   scheduler_pos:resd 1

   scheduler_stack:resb 16384

   printer_pos:resd 1

   printer_stack:resb 16384
   target_pos:resd 1

   target_stack:resb 16384

   CORS:resd 1
   num_cors:resd 1
   
   seed: resw 1 





section .data
    random_number:dd 0
    SPT: dd 0x0 ; Temp holder for stack pointer 

    extern x_coordinate_target
    extern y_coordinate_target
 
%macro scanArgument 3
    pushad
    push %1 
    push %2
    push %3
    call sscanf     
    add esp,12
    popad 

%endmacro 

%macro initializeCors 3
   mov eax,%1  ;pointer to start address of co-routine
   mov dword[%2],edx  ;save to position in the co-routine array
   mov esi,%3          ;pointer to the co-routine stack
   add esi, dword[STKSZ]  ;now pointes to top of the co-routine stack
   mov dword[ecx+edx*8],eax    ;add the pointer to start address of co-routine to CORS 
   mov dword[ecx+edx*8+4],esi    ;pointer to the stack
%endmacro 

%macro allocateMallocMul 3
  mov eax, dword[%1]
  mov ebx, %2
  mul ebx
  push eax
  call malloc
  mov dword[%3],eax ;save the pointer
  add esp, 4
%endmacro 

    
section .text
    align 16
    extern drone
    extern printer
    extern target
    extern startCo
    extern scheduler
    extern sscanf
    extern printf 
    extern malloc 
    extern calloc
    extern free 
    extern stdin
    global main
    global get_random_number
    extern create_target
  
   


main:
   push ebp
   mov ebp,esp
   ;initialize argumnets 
   mov  ecx, [esp+12] ; get argv
    ;scanArgument %argVar,%format,%char* 
    
   scanArgument num__of_drones,decimal_string, dword [ecx+4]
   scanArgument num_scheduler_cycles,decimal_string, dword [ecx+8]
   scanArgument drone_steps_target,decimal_string, dword [ecx+12]
   scanArgument drone_steps_printing,decimal_string, dword [ecx+16] 
   scanArgument distance,float_string, dword [ecx+20] 
   scanArgument seed,decimal_string, dword[ecx+24]

   mov ebx, dword[num__of_drones]
   mov dword[num_alive_drones],ebx

   pushad 
   call create_target ;create first target
   ;create a stack for each one of the  drones
   popad 
   allocateMallocMul num__of_drones, dword[STKSZ],drones_stack
   ;create a pointer that point to all the drones information
   ;each drone has the next 5 parameter: x,y,degree,speed and number of target destroyed
    
   allocateMallocMul num__of_drones, 20,drones_info
   call initialize_drones

   
   ;intialize number of co-routines 
   mov edx, dword[num__of_drones]
   add edx,3  
   mov dword[num_cors], edx
   allocateMallocMul num_cors, 8,CORS
   dec dword[num_cors]

   push dword[num__of_drones]
   call malloc
   add esp,4
   mov dword[drones_alive_array],eax ;0 bit mines the drone is alive 1 means is "dead"
   
   mov ebx,0
   initDronesAlive:
    mov byte[eax+ebx],0
    inc ebx
    cmp ebx, dword[num__of_drones]
    jl initDronesAlive
  
   mov ecx, dword[CORS]
   mov edx, dword[num_cors]
   initializeCors scheduler,scheduler_pos ,scheduler_stack
   dec edx
   initializeCors printer,printer_pos,printer_stack
   dec edx 
   initializeCors  target,target_pos,target_stack
   dec edx


   ;now we would like to initialize all the co-routines for all the drones
    mov eax, dword[num__of_drones]
    mov ebx, dword[STKSZ]
    mul ebx
    mov ebx, dword[drones_stack]
    add eax,ebx   ;eax points to the top of the drones stack
    mov ecx, dword[CORS]
    mov edx, dword[num__of_drones]
    dec edx


    drone_initilize_loop:
      mov dword[ecx+edx*8],drone
      mov dword[ecx+edx*8+4],eax
      sub eax, dword[STKSZ]
      dec edx
      cmp edx,0
      jnl drone_initilize_loop
      
       ;setup stacks with registers & flags for all the co routines
      mov  ecx, dword[num_cors]
     initateCorsForAll: 
     pushad
     push ecx
     call initateCor
     add  esp,4
     popad
     dec  ecx
     cmp  ecx,0
     jge  initateCorsForAll

    call startCo
 
   
    



    ;Param - Co Routine ID
;Output - Setups stacks for each co routine
initateCor: 
  push ebp
  mov  ebp,esp
  mov  ecx, dword[ebp+8]
  mov  eax, dword[CORS] ;Grab our CO routine array
  mov  ebx, dword[ecx*8+eax] ; Get the CodeP
  mov  dword [SPT], esp ; save current ESP value into SP temp
  mov  esp, dword[ecx*8+eax+4] ; get pointer to the stack
  push ebx ; Push retn addy to the co routine stack
  pushfd ; push all flags into the stack of the co routine
  pushad ; push all other registers into the stack of the co routine
  mov dword[8*ecx+eax+4], esp ; save new SPi after we have pushed all the info needed for the coroutines
  mov esp, dword[SPT] ; restore ESP value 
  mov esp,ebp
  pop ebp
  ret

 ;So basically after initation each cor on the stack looks like this:
 ;registers
 ;flagsfd
 ;retn addy
   
initialize_drones:
   push ebp
   mov ebp,esp
   pushad
   mov ebx, dword[drones_info]
   mov edx,1
   init_loop:
   push BOARD_SIZE  ;x
   call get_random_number
   add esp,4
   mov dword[ebx],eax
   push BOARD_SIZE  ;y
   call get_random_number
   add esp,4
   mov dword[ebx+4],eax
   push BOARD_SIZE ;speed
   call get_random_number
   add esp,4
   mov dword[ebx+12],eax
   push 360     ;angel
   call get_random_number
   add esp,4
   mov dword[ebx+8],eax 
   mov dword[ebx+16],0
   cmp edx, dword[num__of_drones]
   je done_init 
   inc edx
   add ebx,20
   jmp init_loop

   done_init:
   popad
   mov esp,ebp
   pop ebp
   ret




get_random_number:
   push ebp
   mov ebp,esp
   call fibonacci_LFSR
   mov dword[temp_value],eax
   fild dword[temp_value]
   fidiv dword[max_int] 
   fimul dword[ebp+8] ;scaling  
   fstp dword[temp_value] ;store the result of (random number /maxint)*100 in eax
   finit   
   mov eax, dword[temp_value]            
   mov esp,ebp
   pop ebp
   ret






fibonacci_LFSR:
    push ebp              		; save Base Pointer (bp) original value
    mov ebp, esp         		; use Base Pointer to access stack contents (do_Str(...) activation frame)
    pushad      
    mov ecx, 16
    mov eax,0
   loop:
    mov ax, word[seed]
    and ax,1                        ;ax hold byte 16
    mov bx, word[seed]
    shr bx,2                         
    and bx,1                         ;bx hold byte 14   
    xor ax, bx                       ;xor byte 14 and 16   
    mov bx, word[seed]
    shr bx,3                         
    and bx,1                         ;bx now hold byte 13
    xor ax,bx                          ;xor bytes 13 with the result of xor 14 and 16
    mov  bx, word[seed]
    shr bx,5                         
    and bx,1                         ;bx now hold byte 11
    xor ax,bx                        ;xor byte 11 with 13,14,16 bytes
    mov bx, word[seed]                
    shr bx,15                         ;bx now hold the MSB byte
    xor ax,bx                        ;xor MSB byte with 11,13,14,16 bytes
    shl word[seed],1
    add word [seed],ax                ;save in lsb byte
    dec ecx
    cmp ecx,0
    jne loop
   
    popad
    mov ax, word[seed]
    movzx eax,ax
    mov esp, ebp	
   	pop ebp
	ret