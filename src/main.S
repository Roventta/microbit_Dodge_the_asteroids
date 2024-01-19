.syntax unified
.global main
.global SysTick_Handler

.set SYST_CSR, 0xE000E010
.set SYST_RVR, 0xE000E014
.set SYST_CVR, 0xE000E018

.set RNGbase, 0x4000D000
.set RNGStart, 0x000
.set RNGValue, 0x508

.set GPIO_DIRCLR, 0x51C 
.set GPIO_OUTCLR, 0x50C

@ GPIOTE Constants
.set GPIOTE_EVENTS_IN0, 0x40006100
.set GPIOTE_INTENSET, 0x40006304
.set GPIOTE_CONFIG0, 0x40006510

@ NVIC Constants
.set NVIC_ISER0, 0xE000E100

.type main, %function
main:
  bl StartTimer
  bl StartRNGTask
  bl ButtonInit

mainLooper:

mainGraphicLooper:
  ldr r0, =GraphicSysticCycle
  ldr r0, [r0]
@ Check for time counter, when it is one, do one looper
  cmp r0, 1
  bne mainGapLooper

  bl rowLooper
  
@ clear the timer now
  ldr r0, =GraphicSysticCycle
  mov r1, 0
  str r1, [r0]

@ great, now add one to row memory counter
@ but before adding it, I need to know which row I am, if I am currently at row 4 reaching this step
@ that means I exhaust all the rows, and need to refreash it back into zero.
  ldr r1, =whichRow
  ldr r2, [r1]
  subs r2, 4
  bne OkayNotFinished 
  str r2, [r1]
  b mainGapLooper

  OkayNotFinished:
  add r2, 4
  add r2, 1
  str r2, [r1]

  b mainGapLooper

mainGapLooper:  
  bl PetIllustrator

  @ game on? if so okay, if not go to next looper
  ldr r0, =isGameRunning
  ldr r0, [r0]
  cmp r0, 1
  beq GameRunning
  b mainScoreLooper

  GameRunning:
  ldr r0, =GapSysticCycle
  ldr r0, [r0]
  @ Check for time counter, when it is eqaul to delay, change one row
  ldr r1, =RowTickDelay
  ldr r1, [r1]
  cmp r0, r1
  bne mainScoreLooper

  @ clear the timer
  ldr r0, =GapSysticCycle
  mov r1, 0
  str r1, [r0]

  @ first clear the current row
  ldr r0, =GapLocation
  ldr r0, [r0]
  ldr r1, =BlankRow
  bl MatrixRowModifier
  @ check for gap location, if it is four then start checking weather pet passed this level, after that, change it into zero
  ldr r0, =GapLocation
  ldr r1, [r0]

  cmp r1, 4
  bne startChangeGap
  
  @ it is four, start checking level success

  ldr r4, =GapOpenLocation
  ldr r4, [r4]
  ldr r5, =PetLocation
  ldr r5, [r5]
  cmp r4, r5
  beq GapSuccess
  
  GapFailed:
  bl GameOver
  b mainLooper

  GapSuccess:
  @ add one to score
  ldr r0, =GameScore
  ldr r1, [r0]
  add r1, 1
  str r1, [r0]
  @ add one to difficulty counter
  ldr r0, =DifficultyCounter
  ldr r1, [r0]
  add r1, 1
  str r1, [r0]

  @ clear the GapLocation
  ldr r0, =GapLocation
  mov r1, -1
  str r1, [r0]

  @ at this point, a new Gap needed to be generated
  bl GenerateNewGap

  startChangeGap:
  @ now add one to the row location
  ldr r0, =GapLocation
  ldr r1, [r0]
  add r1, 1
  str r1, [r0]
  @ now change the next row
  ldr r0, =GapLocation
  ldr r0, [r0]
  ldr r1, =Gap
  bl MatrixRowModifier

  b mainScoreLooper
  
  
mainScoreLooper:
  ldr r0, =DifficultyCounter
  ldr r1, [r0]
  cmp r1, 5
  bne LeaveDelayAlone
  mov r1, 0 @ clear the difficulty counter
  str r1, [r0]

  @ sub delay 10 if it is not zero
  ldr r0, =RowTickDelay
  ldr r1, [r0]
  cmp r1, 55
  ble LeaveDelayAlone
  sub r1, 4
  str r1, [r0]

  LeaveDelayAlone:
  @ first check weather game on, if on, b mainLooper, if not, visualise GameScore
  ldr r0, =isGameRunning
  ldr r0, [r0]
  cmp r0, 1
  beq mainLooper

  ldr r0, =GameScore
  ldr r0, [r0]
  bl NumberVisuliser

  b mainLooper


rowLooper:
  push {lr}
@ blank before
  bl Blank
  bl displayOneRow
  pop {lr}
  bx lr



@read which row in r12, no input
.type displayOneRow, %function
displayOneRow:
   push {lr}

   ldr r12, =whichRow
   ldr r12, [r12]

   @get the row ARM digit
   lsl r12, r12, 2
   ldr r11, =RowIndex
   add r11, r11, r12
   ldr r11, [r11]
   bl rowPrepare

   @light the row up
   bl RowLighterCapsul

   @when the function reach this step, they would want to refreash the Col counter

   mov r0, 0
   ldr r1, =whichCol
   str r0, [r1]

   b stackOut



   

@input r11: row ARM digit
@this function prepare the row OUT, DIR
.type rowPrepare, %function
rowPrepare:
   push {lr}
  @ DIR
   ldr r1, =0x50000000
   ldr r2, [r1, 0x514]
   mov r3, 0b1
   lsl r3, r3, r11
   orr r2, r2, r3
   str r2, [r1, 0x514]
  @ OUT
   ldr r2, [r1, 0x504]
   mov r3, 0b1
   lsl r3, r3, r11
   orr r2, r2, r3
   str r2, [r1, 0x504]  
   pop {lr}
bx lr

RowLighterCapsul:
  push {lr}
  @input r12: which row
.type RowLighter, %function
RowLighter:

  ldr r10, =whichCol
  ldr r10, [r10]

  ldr r12, =whichRow
  ldr r12, [r12]

  @check weather col is exhausted, if not, do the looper again, if yes, break out
  subs r10, #5
  beq stackOut
  adds r10, #5
  b ColLooper

@input r10: which col I am looking at
@input r12: which row
ColLooper:

@find the pattern of led from memory address
@times 20 for row
mov r9, 20
mul r12, r12, r9
lsl r10, r10, 2
add r10, r10, r12

@ is this Led on? if on, find its digit and do shift, save the result into memory
ldr r12, =matrix
ldr r12, [r12, r10]

subs r12, 1

@ if not, step out the looper and keep rolling, and add a one to Col counter
ldr r10, =whichCol
ldr r11, [r10]
add r11, 1
str r11, [r10]
bne RowLighter

@ find digit
ldr r10, =whichCol
ldr r10, [r10]
sub r10, 1
lsl r10, r10, 2
ldr r9, =ColIndex
ldr r10, [r9, r10]

@save the result to memory
mov r9, 1
lsl r9, r9, r10
bl storeLEDinfo

b RowLighter 


stackOut:
pop {lr}
bx lr
   

@r9, info
storeLEDinfo:
push {lr}

ldr r10, =whichCol
ldr r10, [r10]
sub r10, 1
subs r10, 3
beq itisThree
ldr r1, =0x50000000
ldr r2, [r1, 0x514]
orr r2, r2, r9
str r2, [r1, 0x514]

b stackOut

itisThree:
ldr r1, =0x50000300
ldr r2, [r1, 0x514]
orr r2, r2, r9
str r2, [r1, 0x514]

b stackOut

@turn off the hole led array, both DIR and OUT
Blank:
mov r0, 0x0
mov r1, 0x50000000
str r0, [r1, 0x514]
# for that stupid p1, 8 is 5+3, since P1 is 0x50000300
str r0, [r1, 0x814]
str r0, [r1, 0x504]
mov r0, 0b1
bx lr

StartTimer:
  push {lr}
  ldr r0, =SYST_CSR
  
  ldr r1, [r0]
  mov r2, 0x7 
  orr r1, r2
  str r1, [r0]
  ldr r0, =SYST_RVR
  @ set one timer period as 30D400 ticks, 50ms
  ldr r1, =0x30D40
  str r1, [r0]
  pop {lr}
  bx lr 

.type SysTick_Handler, %function
SysTick_Handler:
  nop
  push {lr}

  @ add one to counter
  ldr r0, =GraphicSysticCycle
  ldr r1, [r0]
  add r1, #1
  str r1, [r0]

  ldr r0, =GapSysticCycle
  ldr r1, [r0]
  add r1, #1
  str r1, [r0]

  ldr r0, =PetMoveDelay
  ldr r1, [r0]
  add r1, #1
  str r1, [r0]
  
  pop {lr}
  bx lr
.size SysTick_Handler, .-SysTick_Handler  


@r0: which row in the matrix to modify
@r1: the memory address that the row specified are gonna be modified into
MatrixRowModifier:
 push {lr}
 push {r0}
  MRMLooperCapsule:
  pop {r0}
  push {r0}
   ldr r6, =MRMColCounter
   ldr r2, [r6]
   @ check weather r2 is five, if it is five, break out, if not, keep going
   cmp r2, 5
   bne MRMLooper
   mov r2, 0
   str r2, [r6]
   pop {r0}
   bl stackOut
  @r2: which col
  MRMLooper:
   @ get the digit that gonna replace matrx in r4, the index of it will be saved in r2, after that, add four to that digit and save it into memory
   push {r2}
   lsl r2, r2, 2
   ldr r4, [r1, r2]
   
   @ get the index of the digit that gonna be replaced in matrix
   mov r6, 20
   mul r0, r0, r6
   add r2, r0, r2
   
   ldr r0, =matrix
   str r4, [r0, r2]

   MRMLooperNext:
   ldr r3, =MRMColCounter
   pop {r2}
   add r2, r2, 1
   str r2, [r3]

   b MRMLooperCapsule



StartRNGTask:
 push {lr}
 ldr r0, =RNGbase
 ldr r1, =RNGStart
 mov r2, 0b1
 str r2, [r0, r1]
 pop {lr}
 bx lr

ReadRNGValue:
 push {lr}
 ldr r0, =RNGbase
 ldr r1, =RNGValue
 mov r2, 0b1
 ldr r2, [r0, r1]
 pop {lr}
 bx lr   
  

@ r0 is RNG value
@ r0 output as scale in Five
RNGScaletoFive:
 push {lr}
 cmp r0, 51
 bgt notZero
 mov r0, 0
 b stackOut
 notZero:
 cmp r0, 102
 bgt notOne
 mov r0, 1
 b stackOut
 notOne:
 cmp r0, 153
 bgt notTwo
 mov r0, 2
 b stackOut
 notTwo:
 cmp r0, 204
 bgt notThree
 mov r0, 3
 b stackOut
 notThree:
 mov r0, 4
 b stackOut


@manipulate gap open location base on memory
GapManipulation:
  push {lr}
  ldr r0, =GapOpenLocation
  ldr r0, [r0]
  ldr r1, =Gap
  mov r2, 0
  @ r2 is the loop counter

  GMLooper:
  @ if r2 is five, then stack out
  cmp r2, 5
  bne GMLooperKeepGoing
  b stackOut
  GMLooperKeepGoing:
  @ if it is the location to open gate, ldr that gap to 0
  cmp r2, r0   
  bne GMLooperLDRone
  mov r3, 0
  push {r2}
  lsl r2, r2, 2
  str r3, [r1, r2]
  b GMLooperStackOut
  GMLooperLDRone:
  mov r3, 1
  push {r2}
  lsl r2, r2, 2
  str r3, [r1, r2]

  GMLooperStackOut:
  pop {r2}
  add r2, r2, 1
  b GMLooper  


GenerateNewGap:
  push {lr}
  bl ReadRNGValue
  mov r0, r2
  bl RNGScaletoFive
  mov r2, r0
  ldr r0, =GapOpenLocation
  str r2, [r0]
  bl GapManipulation
  b stackOut


ButtonInit:
  push {lr}
 @ 1: Configure GPIOTE_CONFIG[0]
  @ Need to setup: mode, pin, port, polarity in the configuration register for GPIOTE[0]
  @ Section 6.9.4.8 in nRF52833 reference manual
  @ mode = 1 (event), pin = 14 and port = 0 (P0.14 = Button A), polarity = 1 (LoToHi)
  ldr r0, =GPIOTE_CONFIG0
  ldr r1, =(1 | 14 << 8 | 0 << 13 | 1 << 16)
  str r1, [r0]

  @ now p0.23 on channel 1
  ldr r1, =(1 | 23 << 8 | 0 << 13 | 1 << 16)
  str r1, [r0,0x4]

@ 2: Enable Interrupt for GPIOTE[0] and [1] (id = 6)
  ldr r0, =GPIOTE_INTENSET
  mov r1, 3
  str r1, [r0]

@ 3: enable GPIOTE (interrupt #6 = NVIC_GPIOTE_ID) in NVIC_ISER0
  
  ldr r0, =NVIC_ISER0
  ldr r1, =(1 << 6) @ set the 6th bit since NVIC_GPIOTE_ID = 6
  str r1, [r0]

b stackOut 


.global GPIOTE_IRQHandler
.type GPIOTE_IRQHandler, %function
GPIOTE_IRQHandler:
  push {lr}
  
  @delay passed? not passed then branch out, if passed then refreash it
  ldr r0, =PetMoveDelay
  ldr r1, [r0]
  cmp r1, 10
  ble INClear
  @ refreash
  mov r1, 0
  str r1, [r0]

  ldr r0, =GPIOTE_EVENTS_IN0
  ldr r1, [r0]
  @ button A pushed?
  cmp r1, 1
  bne NotLeft
  ldr r1, =PetLocation
  ldr r2, [r1]
  @ location being zero?, branch out inmmediatly
  cmp r2, 0
  beq INClear

  sub r2, 1
  str r2, [r1]
  b INClear

  NotLeft:
  ldr r1, =PetLocation
  ldr r2, [r1]
  @ location being four? branch out inmmediatly
  cmp r2, 4
  beq INClear
  add r2, 1
  str r2, [r1]
  b INClear

  @clear IN
  INClear:
  ldr r0, =GPIOTE_EVENTS_IN0
  ldr r1, =0
  str r1, [r0]
  str r1, [r0,4]

  pop {lr}
  bx lr
.size GPIOTE_IRQHandler, .-GPIOTE_IRQHandler

@ blank the last row
@ read pet location from the memory
@ change matrix last row by the memory
PetIllustrator:
  push {lr}
  mov r0, 4
  ldr r1, =BlankRow
  bl MatrixRowModifier

  ldr r0, =matrix
  ldr r1, =PetLocation
  ldr r1, [r1]
  mov r2, r1
  lsl r2, r2, 2
  add r2, r2, 80
  mov r1, 1
  str r1, [r0, r2]
  pop {lr}
  bx lr


GapFullOn:
 push {lr}
 
 ldr r0, =Gap
 mov r1, 1
 str r1, [r0]
 str r1, [r0,4]
 str r1, [r0,8]
 str r1, [r0,12]
 str r1, [r0,16]
 
 b stackOut  


GameOver:
  push {lr}
  ldr r0, =isGameRunning
  mov r1, 0
  str r1, [r0]
  pop {lr}
  bx lr


@ r0 is the number
NumberVisuliser:
 push {lr}
 mov r2, 1 
 ldr r1, =matrix
 cmp r0, 10 
 blt LessTen
 @ greater than ten? minus it ten, light a left led
 sub r0, r0, 10
 
 
 str r2, [r1]

 cmp r0, 10
 blt LessTen
 @ greater than ten? minus it ten, light a left led
 sub r0, r0, 10
 str r2, [r1, 4]
 cmp r0, 10
 blt LessTen
 @ greater than ten? minus it ten, light a left led
 sub r0, r0, 10
 str r2, [r1, 20]

 cmp r0, 10
 blt LessTen
 @ greater than ten? minus it ten, light a left led
 sub r0, r0, 10
 str r2, [r1, 24]

 cmp r0, 10
 blt LessTen
 @ greater than ten? minus it ten, light a left led
 sub r0, r0, 10
 str r2, [r1, 40]

 cmp r0, 10
 blt LessTen
 @ greater than ten? minus it ten, light a left led
 sub r0, r0, 10
 str r2, [r1, 44]

 cmp r0, 10
 blt LessTen
 @ greater than ten? minus it ten, light a left led
 sub r0, r0, 10
 str r2, [r1, 60]
 cmp r0, 10
 blt LessTen
 @ greater than ten? minus it ten, light a left led
 sub r0, r0, 10
 str r2, [r1, 64]
 cmp r0, 10
 blt LessTen
 @ greater than ten? minus it ten, light a left led
 sub r0, r0, 10
 str r2, [r1, 80]

 LessTen:
 cmp r0, 0
 beq EqualZero
 sub r0, r0, 1
 str r2, [r1, 12]

 cmp r0, 0
 beq EqualZero
 sub r0, r0, 1
 str r2, [r1, 16]
 
 cmp r0, 0
 beq EqualZero
 sub r0, r0, 1
 str r2, [r1, 32]

 cmp r0, 0
 beq EqualZero
 sub r0, r0, 1
 str r2, [r1, 36]

 cmp r0, 0
 beq EqualZero
 sub r0, r0, 1
 str r2, [r1, 52]

 cmp r0, 0
 beq EqualZero
 sub r0, r0, 1
 str r2, [r1, 56]

 cmp r0, 0
 beq EqualZero
 sub r0, r0, 1
 str r2, [r1, 72]

 cmp r0, 0
 beq EqualZero
 sub r0, r0, 1
 str r2, [r1, 76]

 cmp r0, 0
 beq EqualZero
 sub r0, r0, 1
 str r2, [r1, 92]
 EqualZero:
bl stackOut



.data
matrix:
  @ row one
  .word 0,0,0,0,0
  .word 0,0,0,0,0  
  .word 0,0,0,0,0 
  .word 0,0,0,0,0  
  .word 0,0,0,0,0  

whichRow:
  .word 0

whichCol:
  .word 0  

RowIndex:
  .word 21, 22, 15, 24, 19
ColIndex:  
  .word 28, 11, 31, 05, 30  

GraphicSysticCycle:
  .word 0 

GapSysticCycle:
  .word 0     

GapLocation:
  .word 0

GapOpenLocation:
  .word 2  

Gap:
  .word 1,1,0,1,1  

BlankRow:
  .word 0,0,0,0,0  

MRMColCounter:
  .word 0    

DifficultyCounter:
  .word 0

RowTickDelay:
  .word 80  

PetLocation:
.word 2      

PetMoveDelay:
.word 1

isGameRunning:
.word 1

GameScore:
.word 0




