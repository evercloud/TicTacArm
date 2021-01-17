bin = kernel.img
elf = kernel.elf
obj = kernel.o					#@store object filename in variable obj
code = BareTicTacArm.s     		#@store src code in code variable
		

$(bin) : $(elf)
	arm-none-eabi-objcopy $(elf) -O binary $(bin)

$(elf) : $(obj)
	arm-none-eabi-ld $(obj) -o $(elf) 


$(obj) : $(code)
	arm-none-eabi-as -g -o $(obj) $(code)



clean:						#@clean tool
	rm *.o#@will remove all files with .o extension
