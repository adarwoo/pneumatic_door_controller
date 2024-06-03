# Change the compiler
CXX := avr-g++
CC := avr-gcc
SIZE := avr-size

# Pack for the toolchain
PACK_VERSION = 2.0.368
PACK_PATH = /opt/ATtiny_DFP.${PACK_VERSION}
SPEC_PATH = ${PACK_PATH}/gcc/dev/$(ARCH)

# Target type for this build (cross-compilation)
BIN_EXT :=.elf

# Remove all logs
CPPFLAGS += -DFORCE_NODEBUG
ARCHFLAGS :=-mmcu=$(ARCH) -B $(SPEC_PATH) -isystem $(PACK_PATH)/include
CFLAGS += -funsigned-char -funsigned-bitfields -ffunction-sections -fdata-sections -fshort-enums $(ARCHFLAGS)
CFLAGS += -O$(if $(DEBUG),g,s)
ASFLAGS += $(CPPFLAGS) $(ARCHFLAGS)
CXXFLAGS += $(CFLAGS) -fno-threadsafe-statics -fno-exceptions
LDFLAGS += $(ARCHFLAGS) -Wl,-Map="$(BIN).map" -Wl,--start-group -Wl,-lm  -Wl,--end-group -Wl,--gc-sections -mmcu=$(ARCH) -Wl,--demangle -Wl,-flto

define DIAG
$(mute)$(SIZE) $@ | awk 'NR!=1 {print "Flash: [" $$1 "]" " - RAM: [" $$2 "+" $$3 "]" }'

endef

define POST_LINK
	$(mute)avr-objcopy -O ihex -R .eeprom -R .fuse -R .lock -R .signature -R .user_signatures  "$@" "${@:.elf=.hex}"
	$(mute)avr-objcopy -j .eeprom  --set-section-flags=.eeprom=alloc,load --change-section-lma .eeprom=0  --no-change-warnings -O ihex "$@" "${@:.elf=.eep}" || exit 0
	$(mute)avr-objdump -h -S "$@" > "${@:.elf=.lss}"
	$(mute)avr-objcopy -O srec -R .eeprom -R .fuse -R .lock -R .signature -R .user_signatures "$@" "${@:.elf=.lss}"
endef
