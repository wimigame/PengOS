###########################################
## @Author: 陈小鹏
## @Date: 2022-12-26 16:29:50
## @LastEditors: Please set LastEditors
## @LastEditTime: 2022-12-26 16:36:19
## @FilePath: /peng/PengOS
###########################################

##
## Define the default target.
##

all:

##
## Don't let make use any builtin rules.
##

.SUFFIXES:

##
## Define the architecture and object of the build machine.
##

OS ?= $(shell uname -s)
ifneq ($(findstring CYGWIN,$(shell uname -s)),)
OS := cygwin
endif

BUILD_ARCH = $(shell uname -m)
ifeq ($(BUILD_ARCH), $(filter i686 i586,$(BUILD_ARCH)))
BUILD_ARCH := x86

else ifeq ($(BUILD_ARCH), $(filter armv7 armv6,$(BUILD_ARCH)))

else ifeq ($(BUILD_ARCH), $(filter x86_64 amd64,$(BUILD_ARCH)))
BUILD_ARCH := x64
else
$(error Unknown architecture $(BUILD_ARCH))
endif

##
## Define build locations.
##
OUTROOT := $(SRoot)/peng/build/x86
TOOLROOT := $(OUTROOT)/tools
TOOLBIN := $(TOOLROOT)/bin
BINROOT := $(OUTROOT)/bin
TESTBIN := $(OUTROOT)/testbin
OBJROOT := $(OUTROOT)/obj
STRIPPED_DIR := $(BINROOT)/stripped


CURDIR := $(subst \,/,$(CURDIR))

##
## If the current directory is not in the object root, then change to the
## object directory and re-run make from there. The condition is "if removing
## OBJROOT makes no change".
##

ifeq ($(CURDIR), $(subst $(OBJROOT),,$(CURDIR)))

THISDIR := $(subst $(SRoot)/,,$(CURDIR))
OBJDIR := $(OBJROOT)/$(THISDIR)
MAKETARGET = $(MAKE) --no-print-directory -C $@ -f $(CURDIR)/Makefile \
    -I$(CURDIR) $(MAKECMDGOALS) SRCDIR=$(CURDIR)

.PHONY: $(OBJDIR) clean wipe

$(OBJDIR):
	+@[ -d $@ ] || mkdir -p $@
	+@$(MAKETARGET)

clean:
	rm -rf $(OBJROOT)

wipe:
	rm -rf $(OBJROOT)
	rm -rf $(BINROOT)
	rm -rf $(TESTBIN)
	rm -rf $(TOOLROOT)

Makefile: ;
%.mk :: ;
% :: $(OBJDIR) ; @:

##
## If the current directory appears to be outside of SRoot, then there's a
## problem. Having a symlink somewhere in SRoot causes this.
##

ifeq ($(CURDIR), $(subst $(SRoot),,$(CURDIR)))
$(error The current directory $(CURDIR) does not appear to be a subdirectory \
of SRoot=$(SRoot). Do you have a symlink in SRoot?)
endif

else

THISDIR := $(subst $(OBJROOT)/,,$(CURDIR))

##
## VPATH specifies which directories make should look in to find all files.
## Paths are separated by colons.
##

VPATH += :$(SRCDIR):

##
## Executable variables
##

CC_FOR_BUILD ?= gcc
AR_FOR_BUILD ?= ar
STRIP_FOR_BUILD ?= strip

ifeq ($(OS), $(filter Windows_NT Minoca,$(OS)))
CECHO_CYAN ?= cecho -fC
else
CECHO_CYAN ?= echo
endif

RCC := windres

CC := i686-pc-minoca-gcc
AR := i686-pc-minoca-ar
OBJCOPY := i686-pc-minoca-objcopy
STRIP := i686-pc-minoca-strip

##
## These define versioning information for the code.
##

GEN_VERSION := @echo "Creating - version.h" && $(SRoot)/peng/tasks/build/print_version.sh

##
## Define a file that gets touched to indicate that something has changed and
## images need to be rebuilt.
##

LAST_UPDATE_FILE := $(OBJROOT)/peng/last-update
UPDATE_LAST_UPDATE := date > $(LAST_UPDATE_FILE)

##
## Includes directory.
##

INCLUDES += $(SRoot)/peng/include

##
## Define default CFLAGS if none were specified elsewhere.
##

# LTO_OPT ?= -flto
CFLAGS ?= -Wall -Werror
ifeq ($(DEBUG),rel)
CFLAGS += -O2 $(LTO_OPT) -Wno-unused-but-set-variable
else
CFLAGS += -O1 $(LTO_OPT)
endif

##
## Compiler flags
##

EXTRA_CPPFLAGS += -I $(subst ;, -I ,$(INCLUDES))

ifeq ($(DEBUG),rel)
EXTRA_CPPFLAGS += -DNDEBUG=1
else
EXTRA_CPPFLAGS += -DDEBUG=1
endif

EXTRA_CPPFLAGS_FOR_BUILD := $(EXTRA_CPPFLAGS)

EXTRA_CFLAGS += -fno-builtin -fno-omit-frame-pointer -g -save-temps=obj \
                -ffunction-sections -fdata-sections -fvisibility=hidden

ifeq ($(ARCH),x64)
KERNEL_CFLAGS += -mno-sse -mno-red-zone
endif

EXTRA_CFLAGS_FOR_BUILD := $(EXTRA_CFLAGS)

ifneq (,$(filter klibrary driver staticapp,$(BINARYTYPE)))
EXTRA_CFLAGS += $(KERNEL_CFLAGS)
endif

EXTRA_CFLAGS += -fpic
ifneq ($(OS),$(filter Windows_NT cygwin,$(OS)))
EXTRA_CFLAGS_FOR_BUILD += -fpic
endif

PIE := -pie
ifeq ($(OS),Darwin)
EXTRA_CFLAGS_FOR_BUILD += -Wno-tautological-compare -Wno-parentheses-equality
PIE := -Wl,-pie
endif

##
## Restrict ARMv6 to armv6zk instructions to support the arm1176jzf-s.
##

ifeq (armv6, $(ARCH))
ifneq ($(BINARYTYPE), build)
EXTRA_CPPFLAGS += -march=armv6zk -marm -mfpu=vfp
endif
endif

ifeq (x86, $(ARCH))
EXTRA_CFLAGS += -mno-ms-bitfields

##
## Quark has an errata that requires no LOCK prefixes on instructions.
##

ifeq ($(VARIANT),q)
ifneq ($(BINARYTYPE), build)
EXTRA_CPPFLAGS += -Wa,-momit-lock-prefix=yes -march=i586
endif
endif

ifeq ($(BINARYTYPE),app)
EXTRA_CFLAGS += -mno-stack-arg-probe
endif
endif

ifeq ($(OS),Darwin)
STRIP_FLAGS :=
else
STRIP_FLAGS := -p
endif

##
## Build binaries on windows need a .exe suffix.
##

ifeq ($(OS),Windows_NT)
ifeq (x86, $(BUILD_ARCH))
EXTRA_CFLAGS_FOR_BUILD += -mno-ms-bitfields
endif
ifeq (build,$(BINARYTYPE))
BINARY := $(BINARY).exe
endif
endif

##
## Linker flags
##

ifneq (,$(TEXT_ADDRESS))
EXTRA_LDFLAGS +=  -Wl,--section-start,.init=$(TEXT_ADDRESS) \
 -Wl,-Ttext-segment=$(TEXT_ADDRESS)

endif

ifneq (,$(LINKER_SCRIPT))
EXTRA_LDFLAGS += -T$(LINKER_SCRIPT)
endif

ifeq ($(BINARYTYPE),driver)
EXTRA_LDFLAGS += -nostdlib -Wl,--no-undefined
ENTRY ?= DriverEntry
BINARYTYPE := so
endif

ifneq ($(ENTRY),)
EXTRA_LDFLAGS += -Wl,-e,$(ENTRY)                            \
                 -Wl,-u,$(ENTRY)                            \

endif

##
## The Darwin linker can't handle -Map or --gc-sections.
##

EXTRA_LDFLAGS_FOR_BUILD := $(EXTRA_LDFLAGS)

EXTRA_LDFLAGS += -Wl,-Map=$(BINARY).map                     \
                 -Wl,--gc-sections                          \

ifneq ($(OS),Darwin)
EXTRA_LDFLAGS_FOR_BUILD := $(EXTRA_LDFLAGS)
endif

##
## Assembler flags
##

EXTRA_ASFLAGS += -Wa,-I$(SRCDIR)
EXTRA_ASFLAGS_FOR_BUILD := $(EXTRA_ASFLAGS)
EXTRA_ASFLAGS += -Wa,-g

##
## For build executables, override the names even if set on the command line.
##

ifneq (, $(BUILD))
override CC = $(CC_FOR_BUILD)
override AR = $(AR_FOR_BUILD)
override STRIP = $(STRIP_FOR_BUILD)
override CFLAGS = -Wall -Werror -O1
ifeq ($(DEBUG),rel)
override CFLAGS += -Wno-unused-but-set-variable
endif

override EXTRA_CFLAGS := $(EXTRA_CFLAGS_FOR_BUILD)
override EXTRA_CPPFLAGS := $(EXTRA_CPPFLAGS_FOR_BUILD)
override EXTRA_ASFLAGS := $(EXTRA_ASFLAGS_FOR_BUILD)
override CPPFLAGS :=
override LDFLAGS :=
override EXTRA_LDFLAGS := $(EXTRA_LDFLAGS_FOR_BUILD)
endif

##
## Makefile targets. .PHONY specifies that the following targets don't actually
## have files associated with them.
##

.PHONY: all clean wipe $(目录) $(TESTDIRS) prebuild postbuild

##
## prepend the current object directory to every extra directory.
##

EXTRA_OBJ_DIRS += $(EXTRA_SRC_DIRS:%=$(OBJROOT)/$(THISDIR)/%) $(STRIPPED_DIR)

all: $(目录) $(TESTDIRS) $(BINARY) $(echo $(BINARY)) postbuild

$(目录): $(OBJROOT)/$(THISDIR)
postbuild:$(BINARY) 

$(TESTDIRS): $(BINARY)
$(目录) $(TESTDIRS):
	@$(CECHO_CYAN) Entering Directory: $(SRoot)/$(THISDIR)/$@ && \
	[ -d $@ ] || mkdir -p $@ && \
	$(MAKE) --no-print-directory -C $@ -f $(SRCDIR)/$@/Makefile \
	    $(MAKECMDGOALS) SRCDIR=$(SRCDIR)/$@ && \
	$(CECHO_CYAN) Leaving Directory: $(SRoot)/$(THISDIR)/$@

##
## The dependencies of the binary object depend on the architecture and type of
## binary being built.
##

ifneq (, $(BUILD))
SAVED_ARCH := $(ARCH)
ARCH := $(BUILD_ARCH)
endif

ifeq (x86, $(ARCH))
ALLOBJS = $(X86_OBJS) $(OBJS)
endif

ifeq (x64, $(ARCH))
ALLOBJS = $(X64_OBJS) $(OBJS)
endif

ifeq (armv7, $(ARCH))
ALLOBJS = $(ARMV7_OBJS) $(OBJS)
endif

ifeq (armv6, $(ARCH))
ALLOBJS = $(ARMV6_OBJS) $(OBJS)
endif

ifneq (, $(BUILD))
ARCH := $(SAVED_ARCH)
endif

ifneq (, $(strip $(ALLOBJS)))

##
## The object files are dependent on the object directory, but the object
## directory being newer should not trigger a rebuild of the object files.
##

$(ALLOBJS): | $(OBJROOT)/$(THISDIR)

$(BINARY): $(ALLOBJS) $(TARGETLIBS)
    ifeq ($(BINARYTYPE),app)
	@echo Linking - $@
	@$(CC) $(CFLAGS) $(EXTRA_CFLAGS) $(LDFLAGS) $(EXTRA_LDFLAGS) $(PIE) -o $@ $^ -Bdynamic $(DYNLIBS)
    endif
    ifeq ($(BINARYTYPE),staticapp)
	@echo Linking - $@
	@$(CC) $(CFLAGS) $(EXTRA_CFLAGS) $(LDFLAGS) $(EXTRA_LDFLAGS) -static -o $@ -Wl,--start-group $^ -Wl,--end-group -Bdynamic $(DYNLIBS)
    endif
    ifneq (,$(filter library klibrary,$(BINARYTYPE)))
	@echo Building Library - $@
	@$(AR) rcs $@ $^ $(TARGETLIBS)
    endif
    ifeq ($(BINARYTYPE),so)
	@echo Linking - $@
    ifneq ($(BUILD),)
    ifeq ($(OS),Darwin)
    # Mac OS (Darwin)
	@$(CC) $(CFLAGS) $(EXTRA_CFLAGS) $(LDFLAGS) $(EXTRA_LDFLAGS) -undefined dynamic_lookup -dynamiclib -current_version $(SO_VERSION_MAJOR).$(SO_VERSION_MINOR) -compatibility_version $(SO_VERSION_MAJOR).0 -o $@ $^ $(DYNLIBS)
    else ifeq ($(OS),Windows_NT)
    # Windows
	@$(CC) $(CFLAGS) $(EXTRA_CFLAGS) $(LDFLAGS) $(EXTRA_LDFLAGS) -shared -o $@ $^ -Bdynamic $(DYNLIBS)
    else
    # Generic ELF
	@$(CC) $(CFLAGS) $(EXTRA_CFLAGS) $(LDFLAGS) $(EXTRA_LDFLAGS) -shared -Wl,-soname=$(BINARY) -o $@ $^ -Bdynamic $(DYNLIBS)
    endif
    else
    # Native build
	@$(CC) $(CFLAGS) $(EXTRA_CFLAGS) $(LDFLAGS) $(EXTRA_LDFLAGS) -shared -Wl,-soname=$(BINARY) -o $@ $^ -Bdynamic $(DYNLIBS)
    endif
    endif
    ifeq ($(BINARYTYPE),build)
	@echo Linking - $@
	@$(CC) $(CFLAGS) $(EXTRA_CFLAGS) $(LDFLAGS) $(EXTRA_LDFLAGS) -o $@ $^ $(TARGETLIBS) -Bdynamic $(DYNLIBS)
    endif
    ifeq ($(BINARYTYPE),custom)
	@echo Building - $@
	@$(BUILD_COMMAND)
    endif
    ifneq ($(BINPLACE),)
	@echo Binplacing - $(OUTROOT)/$(BINPLACE)/$(BINARY)
	@mkdir -p $(OUTROOT)/$(BINPLACE)
	@cp -fp $(BINARY) $(OUTROOT)/$(BINPLACE)/$(BINARY)
    ifeq ($(BINPLACE),bin)
	@$(STRIP) $(STRIP_FLAGS) -o $(STRIPPED_DIR)/$(BINARY) $(BINARY)
	@$(UPDATE_LAST_UPDATE)
    endif
    endif

else

.PHONY: $(BINARY)

endif

##
## Prebuild is an "order-only" dependency of this directory, meaning that
## prebuild getting rebuilt does not cause this directory to need to be
## rebuilt.
##

$(OBJROOT)/$(THISDIR): | prebuild $(BINROOT) $(TOOLBIN) $(TESTBIN) $(EXTRA_OBJ_DIRS)
	@mkdir -p $(OBJROOT)/$(THISDIR)

$(BINROOT) $(TOOLBIN) $(TESTBIN) $(EXTRA_OBJ_DIRS):
	@mkdir -p $@

##
## Generic target specifying how to compile a file.
##

%.o:%.c
	@echo Compiling - $(notdir $<)
	@$(CC) $(CPPFLAGS) $(EXTRA_CPPFLAGS) $(CFLAGS) $(EXTRA_CFLAGS) -c -o $@ $<

##
## Generic target specifying how to assemble a file.
##

%.o:%.S
	@echo Assembling - $(notdir $<)
	@$(CC) $(CPPFLAGS) $(EXTRA_CPPFLAGS) $(ASFLAGS) $(EXTRA_ASFLAGS) -c -o $@ $<

##
## Generic target specifying how to compile a resource.
##

%.rsc:%.rc
	@echo Compiling Resource - $(notdir $<)
	@$(RCC) -o $@ $<

##
## This ends the originated-in-source-directory make.
##

endif