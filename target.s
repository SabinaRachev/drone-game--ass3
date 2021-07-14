BOARD_SIZE EQU 100

section .data
    global is_called_by_scheduler
    global x_coordinate_target
    x_coordinate_target: dd 0
    global y_coordinate_target
    y_coordinate_target: dd 0

    is_called_by_scheduler: dd 1
    temp_x: dd 0
    temp_y: dd 0

section .rodata
    ten: dd 10
    oneHundred: dd 100
    zero: dd 0


%macro moveTarget 2
  push 20
  call get_random_number
  add esp,4
  mov dword[%1],eax
  fld dword[%1]
  fisub word[ten]  ;sub 10 to get the [-10,10] range
  fstp dword[%1]
  fld dword[%2]
  fadd dword[%1]  ;add to current  coordiante the randomize number coordinate
  fild dword[oneHundred] ;load 100
  fcomip   ;check if result is bigger than 100
  ja %%smaller
  fisub dword[oneHundred] ;if bigger than 100 sub 100
  jmp %%store
  %%smaller:
  fild dword[zero]
  fcomip  ;check if result is smaller than 0
  jb %%store
  fiadd dword[oneHundred]
  %%store:
  fstp dword[%2]  ;store result
%endmacro  
section .text
    align 16
    extern get_random_number
     global create_target
     global target
     extern scheduler_pos
     extern resume



target:
  cmp dword[is_called_by_scheduler],0
  je called_by_drone
  ;move target
  moveTarget temp_x,x_coordinate_target
  moveTarget temp_y,y_coordinate_target
  jmp done_target

  called_by_drone:
    call create_target
    mov dword[is_called_by_scheduler],1
  done_target:  
  mov ebx, dword[scheduler_pos]
  call resume
  jmp target







create_target:
    push ebp
    mov ebp,esp
    pushad
    push BOARD_SIZE
    call get_random_number
    mov dword[x_coordinate_target],eax
    add esp,4
    push BOARD_SIZE
    call get_random_number
    mov dword[y_coordinate_target],eax
    add esp,4
    popad
    mov esp,ebp
    pop ebp
    ret

   