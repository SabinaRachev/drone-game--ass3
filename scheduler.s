%macro destroyDrone 0
   mov ecx, dword[drones_alive_array]
   mov edx, dword[drones_info]
   dec dword[num__of_drones]
   mov ebx,0
   %%find_first_active:
     cmp byte[ecx+ebx],0
     je %%found 
     inc ebx
     add edx,20
     jmp %%find_first_active
    %%found:
    mov esi , dword[edx+16]
    mov dword[min_targets_destroyed],esi ;save the first active drone number of targets destroyed
    mov dword[drone_to_destroy],ebx
   %%lowest_target_loop: ;find the drone with the smallest number of destroyed targets
      inc ebx
      add edx,20
      cmp byte[ecx+ebx],0  ;check the drone is alive
      jne %%next
      mov esi, dword[edx+16] 
      cmp dword[min_targets_destroyed],esi
      jle %%next
      mov dword[min_targets_destroyed],esi
      mov dword[drone_to_destroy],ebx
      %%next:
       cmp ebx, dword[num__of_drones]
       je %%done_search
       jmp %%lowest_target_loop
    %%done_search:
       dec dword[num_alive_drones]
       inc dword[num__of_drones]
       mov ebx, dword[drone_to_destroy]
       mov byte[ecx+ebx],1 ;deactivate the drone
%endmacro

section .bss  
    CURR: resd 1   ;Current struct of the current co -routine
    SPT: resd 1    ;Temp stack pointer  
    SPMAIN: resd 1; Pointer to main 

section .rodata
       decimal_string: db "winner is drone: %d",10,0   
       debug_string: db "number drones alive: %d",10,0  
 


section .data
    global roundRobinCounter
    roundRobinCounter: dd 0 
    count_drone_steps_k: dd 0
    count_drone_steps_T: dd 0
    count_rounds: dd 0


    drone_to_destroy:dd 0
    min_targets_destroyed:dd 0

section .text
    align 16
    extern CORS
    extern num__of_drones
    extern drones_stack
    extern drone_steps_printing
    extern drone_steps_target
    extern drones_alive_array
    extern num_alive_drones
    extern num_scheduler_cycles
    extern drones_info
    extern target_pos
    extern printer_pos
    extern scheduler_pos
    extern sscanf
    extern printf 
    extern malloc 
    extern free 
    extern exit 
    extern num_cors
    global scheduler
    global startCo 
    global resume
    global done_co_routines

startCo:
 pushad             ; save registers of main ()
 mov dword[SPMAIN], esp  ; save ESP of main ()
 mov ebx, dword[scheduler_pos] ; Get the schedular position to resume it which applies the actual round robin logic
 jmp do_resume

scheduler:
   mov ecx, dword[drones_alive_array]
   mov  ebx, dword[roundRobinCounter] ; ebx will hold the counter
   cmp dword[num_alive_drones],1
   je winner
   cmp byte[ecx+ebx],0
   jne continue 
   call resume
   continue:
   inc dword[count_drone_steps_k]
   mov eax, dword[count_drone_steps_k]
   cmp eax, dword[drone_steps_printing]
   jne check_target_count

   mov dword[count_drone_steps_k],0
   mov ebx, dword[printer_pos]
   call resume
   check_target_count:
   inc dword[count_drone_steps_T]
   mov eax, dword[count_drone_steps_T]
   cmp eax, dword[drone_steps_target]
   jne nextRoundRobin
   mov dword[count_drone_steps_T],0
   mov ebx, dword[target_pos]
   call resume   
  
   nextRoundRobin: 
   inc dword[roundRobinCounter]
   mov ebx, dword[roundRobinCounter]
   cmp ebx, dword[num__of_drones] ; if we have finished with the drones!
   jl scheduler   
   mov dword[roundRobinCounter],0
   inc dword[count_rounds]
   ;check rounds count
   mov eax, dword[count_rounds]
   cmp eax, dword[num_scheduler_cycles] ;check if we need to destrory a drone
   jne scheduler
   mov dword[count_rounds],0
   destroyDrone 
   cmp dword[num_alive_drones],1 ;if only one left
   je winner
   destroyDrone ;destroy 2 drones
   jmp scheduler

   winner:
     mov ebx,0
     winner_loop:
      cmp byte[ecx+ebx],0
      je found_winner
      inc ebx
      jmp winner_loop
     found_winner:
       inc ebx
       push ebx
       push decimal_string
       call printf
       add esp,8
       call exitGame
       
     

resume:
    pushfd
    pushad
    mov edx, dword[CURR] ; get current struct
    mov eax, dword [CORS] ; get the CORS array
    mov  dword[eax+8*edx+4], esp  ; update the COR array with the new ESP (After we pushed the flags from the finished routine)
do_resume: 
    mov eax, dword [CORS] ; get the CORS array
    mov esp, dword [ebx*8 + eax + 4] ; ebx holds the struct, we get the current stack pointer we want to resume to
    mov dword [CURR], ebx ; Let's point to the current structure of co routine that is being used
    popad ; restore the registers of the current resumed co routine
    popfd ; retore the current EFlags of the current resumed co routine
    ret 


exitGame:
   push dword[drones_stack] 
   call free
   add esp,4
   push dword [drones_info]
   call free
   add esp,4
   push dword [CORS]
   call free
   add esp,4
   push dword [drones_alive_array]
   call free
   push 0
   call exit
   add esp,4

done_co_routines:
    mov esp, dword[SPMAIN] 
    popad   