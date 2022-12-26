//x86架构 主引导内存地址 为什么是0x7C00 这个根据我学习的内容是bios工程师随便定义的 如果你是这个工程师你定义 0x8C00也是一样的
.equ MagicAddress, 0x7C00

.equ RELOCATED_ADDRESS, 0x0600 //mbr重新复制到这个位置

.equ SECTOR_SIZE, 512 //512字节 446=引导 64=分区表 2=结束码55AA

.equ PARTITION_TABLE_ADDRESS, (RELOCATED_ADDRESS + 0x1BE) //真搞不懂为啥一定要用16进制看着这个费劲 0x1BE=446

.equ PARTITION_ENTRY_COUNT,  4

.equ PARTITION_ENTRY_SIZE, 0x10

.equ DISK_RETRY_COUNT, 0x06

.equ PARTITION_START_HEAD, 0x1
.equ PARTITION_START_SECTOR, 0x2
.equ PARTITION_START_CYLINDER, 0x3
.equ PARTITION_LBA_OFFSET, 0x8

.equ BOOT_SIGNATURE_ADDRESS, (MagicAddress + 0x1FE)

.text 
.code16

.section .init

.globl _start

_start:
    jmp SkipBiosParameterBlock
    nop

.org 0x40

SkipBiosParameterBlock:
    xorw %ax,%ax
    movw %ax,%ds
    movw %ax,%es
    movw %ax,%ss
    movw $MagicAddress,%si
    movw $MagicAddress,%sp
    movw $RELOCATED_ADDRESS,%di
    movw $SECTOR_SIZE,%cx
    cld
    rep movsb

    push %ax
    push $AfterMove
    retf

AfterMove:
    sti
    movw $PARTITION_ENTRY_COUNT,%cx
    movw $PARTITION_TABLE_ADDRESS,%bp

BootPartitionLoop:
    cmpb    $0, (%bp)
    jl      DriveReadLoop
    jnz     InvalidPartitionTable
    addw    $PARTITION_ENTRY_SIZE, %bp
    loop    BootPartitionLoop

    int    $0x18

DriveReadLoop:
    movb    %dl, 0x12(%bp)
    pushw   %bp
    movb    $DISK_RETRY_COUNT, 0x11(%bp)
    movb    $0, 0x10(%bp)

    movb    $0x41, %ah
    movw    $0x55AA, %bx
    int     $0x13
    popw    %bp
    jb      AfterInt13ExtensionsCheck
    cmpw    $0xAA55, %bx
    jnz     AfterInt13ExtensionsCheck
    test    $0x0001, %cx
    jz      AfterInt13ExtensionsCheck
    incb    0x10(%bp)

AfterInt13ExtensionsCheck:
    pushal
    cmpb    $0, 0x10(%bp)
    jz      ReadWithoutExtensions

    pushl   $0
    pushl   PARTITION_LBA_OFFSET(%bp)
    pushl   $MagicAddress
    pushw   $1
    pushw   $0x0010
    movb    $0x42, %ah
    movb    0x12(%bp), %dl
    movw    %sp, %si
    int     $0x13

    lahf
    addw    $0x10, %sp
    sahf
    jmp     AfterDiskRead

ReadWithoutExtensions:
    movw    $0x0201, %ax
    movw    $MagicAddress, %bx
    movb    0x12(%bp), %dl
    movb    PARTITION_START_HEAD(%bp), %dh
    movb    PARTITION_START_SECTOR(%bp), %cl
    movb    PARTITION_START_CYLINDER(%bp), %ch
    int     $0x13

AfterDiskRead:
    popal
    jnb     DiskReadSuccess

    decb    0x11(%bp)
    jnz     ResetDrive

    cmpb    $0x80, 0x12(%bp)
    jz      DiskReadError
    movb    $0x80, %dl
    jmp     DriveReadLoop

ResetDrive:
    pushw   %bp
    xorb    %ah, %ah
    movb    0x12(%bp), %dl
    int     $0x13
    popw    %bp
    jmp     AfterInt13ExtensionsCheck

DiskReadSuccess:
    movw    $HelloWorld, %si
    jmp     PrintStringAndDie

    cmpw     $0xAA55, BOOT_SIGNATURE_ADDRESS
    jnz     PartitionNotBootable

    pushw   0x12(%bp)

    call    WaitForKeyboardController
    jnz     AfterA20Line
    cli
    movb    $0xD1, %al
    outb    %al, $0x64
    call    WaitForKeyboardController
    movb    $0xDF, %al
    outb    %al, $0x60
    call    WaitForKeyboardController
    movb    $0xFF, %al
    outb    %al, $0x64
    call    WaitForKeyboardController
    sti

AfterA20Line:
    popw    %dx
    xorb    %dh, %dh
    movw    %bp, %si
    jmp     $0, $MagicAddress

DiskReadError:
    movw    $ReadFailureMessage, %si
    jmp     PrintStringAndDie

InvalidPartitionTable:
    movw    $InvalidPartitionTableMessage, %si
    jmp     PrintStringAndDie

PartitionNotBootable:
    movw    $NoOsMessage, %si
    jmp     PrintStringAndDie

PrintStringAndDie:
    cld
    lodsb
    cmp     $0, %al
    jz      Die
    movw    $0x0007, %bx
    movb    $0x0E, %ah
    int     $0x10
    jmp     PrintStringAndDie

Die:
    hlt
    jmp     Die

WaitForKeyboardController:
    xorw    %cx, %cx

WaitForKeyboardControllerLoop:
    inb     $0x64, %al
    jmp     WaitForKeyboardControllerDelay

WaitForKeyboardControllerDelay:
    and     $0x2, %al
    loopne  WaitForKeyboardControllerLoop
    and     $0x2, %al
    ret

ReadFailureMessage:
    .asciz "MBR Read Error"

HelloWorld:
    .asciz "Mbr Start,Shihao Comming..."

NoOsMessage:
    .asciz "Not Found PengOS"

InvalidPartitionTableMessage:
    .asciz "Invalid partition table"

//打印字符串
PrintCharacter:
    movw $0x0007, %bx //黑底白字 16位
    movb $0x0E, %ah   //输出字符的方法
    int $0x10         //中断10 输出字符串

//主引导记录一共是512个字节，0x1FE 0x1FF是最后两个字节 根据要求必须存入 0x55AA
.org 0x1FE
    .byte 0x55
    .byte 0xAA