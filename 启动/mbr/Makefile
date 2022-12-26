###########################################
## @Author: 陈小鹏
## @Date: 2022-12-26 15:55:17
## @LastEditors: Please set LastEditors
## @LastEditTime: 2022-12-26 16:24:51
## @FilePath: /peng/启动/加载/mbr/Makefile
###########################################

BINARY = mbr
BINARYTYPE = staticapp
BINPLACE = bin

## 兼容多架构-当然现在只支持x86 未来将兼容 arvm risc-v 等cpu架构以及 x64
X86_OBJS = mbr.o

TEXT_ADDRESS = 0x0600

LDFLAGS += -Wl,-zmax-page-size=1 -nodefaultlibs -nostartfiles -nostdlib

include $(SRoot)/peng/PengOS.mk

postbuild: $(BINROOT)/$(BINARY).bin

$(BINROOT)/$(BINARY).bin: $(BINARY)
	@cd $(BINROOT) && $(OBJCOPY) -O binary $^ $@