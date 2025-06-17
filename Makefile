QEMU = qemu-system-riscv32
CC = riscv64-elf-gcc
OBJCOPY = riscv64-elf-objcopy

CFLAGS = -std=c11 -O2 -g3 -Wall -Wextra -march=rv32ima_zicsr -mabi=ilp32 -fno-stack-protector -ffreestanding -nostdlib -Iinclude

.PHONY: all clean run

all: kernel.elf disk.tar

shell.elf: src/shell.c src/user.c src/common.c ld/user.ld
	$(CC) $(CFLAGS) -Wl,-Tld/user.ld -Wl,-Map=shell.map -o shell.elf src/shell.c src/user.c src/common.c

shell.bin: shell.elf
	$(OBJCOPY) --set-section-flags .bss=alloc,contents -O binary shell.elf shell.bin

shell.bin.o: shell.bin
	$(OBJCOPY) -Ibinary -Oelf32-littleriscv shell.bin shell.bin.o

kernel.elf: src/kernel.c src/common.c shell.bin.o ld/kernel.ld
	$(CC) $(CFLAGS) -Wl,-Tld/kernel.ld -Wl,-Map=kernel.map -o kernel.elf src/kernel.c src/common.c shell.bin.o

disk.tar: disk/*.txt
	cd disk && tar cf ../disk.tar --format=ustar *.txt

run: kernel.elf disk.tar
	$(QEMU) -machine virt -bios default -nographic -serial mon:stdio --no-reboot \
		-d unimp,guest_errors,int,cpu_reset -D qemu.log \
		-drive id=drive0,file=disk.tar,format=raw,if=none \
		-device virtio-blk-device,drive=drive0,bus=virtio-mmio-bus.0 \
		-kernel kernel.elf

clean:
	rm -f *.elf *.bin *.o *.map *.tar qemu.log