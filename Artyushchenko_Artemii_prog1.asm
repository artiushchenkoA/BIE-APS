.text
j main

# function takes one arg (a0) ptr to number
log:
lw  t1, 0(a0)     # load data from a0[0]
addi t4, zero, 23
srl  t1, t1, t4    # sift it by 23 places  
addi   t1, t1, -127  # sub 127 
sw  t1, 0(a0)
ret


main:

lw     a0, 0x8(zero)     # ptr
lw     t3, 0x4(zero)     # size
#lw   t4, 0(t3)      # n
addi   t2, zero, 0 # i  
for:
beq  t2, t3, end
jal  log
addi   t2,t2, 1
addi  a0, a0, 4
j   for
end:
j end