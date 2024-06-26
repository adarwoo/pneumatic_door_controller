.PHONY: clean all

# By default, build for the AVR target. Export sim to build a simulator
ifdef ToolchainDir
target := studio
else
target := $(if $(SIM),sim,avr)
endif

include $(TOP)/make/$(target).mak

build_type ?= $(if $(NDEBUG),Release,Debug)
MUTE  ?= $(if $(VERBOSE),@set -x;,@)

# Default tools
CC    ?= gcc
CXX   ?= g++
RC    ?= make/rc.py
SIZE  ?= size
ECHO  ?= echo
MKDIR ?=	mkdir -p
SREC_CAT ?= srec_cat

BUILD_DIR       ?= $(build_type)

# Work out the size of the flash using make functions only
FLASH_END := \
	$(if $(findstring attiny32,$(ARCH)),0x7FFE, \
		$(if $(findstring attiny16,$(ARCH)),0x3FFE, \
			$(if $(findstring attiny8,$(ARCH)),0x1FFE, \
				$(if $(findstring attiny4,$(ARCH)),0x0FFE, \
					$(if $(findstring attiny2,$(ARCH)),0x07FE, \
						$(error Unknown arch $(ARCH)))))))

# Pre-processor flags for C, C++ and assembly
CPPFLAGS        += $(foreach p, $(INCLUDE_DIRS), -I$(p)) -D$(if $(NDEBUG),NDEBUG,DEBUG)=1 -DCRC_AT=$(strip $(FLASH_END))

# Flags for the compilation of C files
CFLAGS          += -ggdb3 -Wall

# Flags for the compilation of C++ files
CXXFLAGS        += $(CFLAGS) -std=c++17 -fno-exceptions

# Assembler flags
ASFLAGS         += -Wa,-gdwarf2 -x assembler-with-cpp -Wa,-g

# Flag for the linker
LDFLAGS         += -ggdb3

# Dependencies creation flags
DEPFLAGS         = -MT $@ -MMD -MP -MF $(BUILD_DIR)/$*.d
POSTCOMPILE      = mv -f $(BUILD_DIR)/$*.Td $(BUILD_DIR)/$*.d && touch $@

DEP_FILES        = $(OBJS:%.o=%.d)

RCDEP_FILES      = $(foreach rc, $(SRCS.resources:%.json=%.rcd), $(BUILD_DIR)/$(rc))

COMPILE.c        = $(CC) $(DEPFLAGS) $(CFLAGS) $(CPPFLAGS) $(ARCHFLAGS) -c
COMPILE.cxx      = $(CXX) $(DEPFLAGS) $(CXXFLAGS) $(CPPFLAGS) $(ARCHFLAGS) -c
COMPILE.rc       = $(RC) -E
COMPILE.as       = $(CC) $(ASFLAGS) $(CPPFLAGS) $(ARCHFLAGS) -c
LINK.cxx         = $(CXX) $(ARCHFLAGS)
LINK.c           = $(CC) $(ARCHFLAGS)

OBJS             = $(foreach file, $(SRCS), $(BUILD_DIR)/$(basename $(file)).o)

LIBS            += m

LD               = $(if $(findstring .cpp,$(suffix $(SRCS))),$(LINK.cxx),$(LINK.c))

# Allow the source to be in sub-directories
BUILDDIRS        = $(sort $(dir $(OBJS)))

all : $(BUILDDIRS) $(BIN)$(BIN_EXT)

sim :
	$(MUTE)$(MAKE) --no-print-directory $(MAKEFLAGS) SIM=1 all

-include $(RCDEP_FILES)

# Create the build directory
$(BUILD_DIR): ; @-mkdir -p $@

$(BIN)$(BIN_EXT) : $(BUILD_DIR)/$(BIN)$(BIN_EXT)
	@echo Copying $^ to $@
	@cp $^ $@

$(BUILD_DIR)/$(BIN)$(BIN_EXT) : $(OBJS)
	@echo Linking to $@
	$(MUTE)$(LD) -Wl,--start-group $^ $(foreach lib,$(LIBS),-l$(lib)) -Wl,--end-group ${LDFLAGS} -o $@
	$(POST_LINK)
	$(DIAG)

$(BUILD_DIR)/%.o : %.c
	@echo Compiling $<
	$(MUTE)$(COMPILE.c) $< -o $@

${BUILD_DIR}/%.o : %.cpp
	@echo Compiling C++ $<
	$(MUTE)$(COMPILE.cxx) $< -o $@

$(BUILD_DIR)/%.o : %.s
	@echo Assembling $<
	$(MUTE)$(COMPILE.as) $< -o $@

$(BUILD_DIR)/%.rcd : %.json
	@echo Generating the resources from $<
	$(MUTE)[ -d $(@D) ] || mkdir -p $(@D)
	$(MUTE)$(COMPILE.rc) $@ $<

# Add the CRC of the code to enable integrity check of the code
# $(BUILD_DIR)/$(BIN)_crc$(BIN_EXT) : $(BUILD_DIR)/$(BIN)$(BIN_EXT)

#-----------------------------------------------------------------------------
# Create directory $$dir if it doesn't already exist.
#
define CreateDir
  if [ ! -d $$dir ]; then \
    (umask 002; mkdir -p $$dir); \
  fi
endef

#-----------------------------------------------------------------------------
# Build directory creation
#
$(BUILDDIRS) :
	$(MKDIR) "$@"

# Include the .d if they exists
-include $(DEP_FILES)

#-----------------------------------------------------------------------------
# Clean rules
#
clean:
	rm -rf $(BUILD_DIR)
