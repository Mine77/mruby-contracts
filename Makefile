TARGET := riscv64-unknown-elf
CC := $(TARGET)-gcc
LD := $(TARGET)-gcc
CFLAGS := -O2 -mcmodel=medlow -DCKB_NO_MMU -DSECP256K1_CUSTOM_FUNCS -D__riscv_soft_float -D__riscv_float_abi_soft
LDFLAGS := -Wl,-static -fdata-sections -ffunction-sections -Wl,--gc-sections -Wl,-s
MUSL_LIB := build/musl/lib/libc.a
MRUBY_LIB := mruby/build/riscv-gcc/lib/libmruby.a
NEWLIB_LIB := build/newlib/$(TARGET)/lib/libc.a
SECP256K1_LIB := secp256k1/.libs/libsecp256k1.a
FLATCC := flatcc/bin/flatcc
CURRENT_DIR := $(shell pwd)

all: build/argv_entry build/argv_source_entry

build/argv_entry: c/argv_entry.c $(MRUBY_LIB)
	NEWLIB=build/newlib/$(TARGET) $(CC) -specs newlib-gcc.specs $(CFLAGS) $(LDFLAGS) -Imruby/include $^ -o $@

build/argv_source_entry: c/argv_source_entry.c $(MRUBY_LIB)
	NEWLIB=build/newlib/$(TARGET) $(CC) -specs newlib-gcc.specs $(CFLAGS) $(LDFLAGS) -Imruby/include $^ -o $@

$(MUSL_LIB): musl
$(MRUBY_LIB): mruby
$(NEWLIB_LIB): newlib
$(SECP256K1_LIB): secp256k1

$(FLATCC):
	cd flatcc && scripts/build.sh

update_schema: $(FLATCC) mruby-ckb/src/protocol.fbs
	$(FLATCC) -c --reader -o mruby-ckb/src mruby-ckb/src/protocol.fbs

newlib:
	mkdir -p build/build-newlib && \
		cd build/build-newlib && \
		../../riscv-newlib/configure --target=$(TARGET) --prefix=$(CURRENT_DIR)/build/newlib --enable-newlib-io-long-double --enable-newlib-io-long-long --enable-newlib-io-c99-formats CFLAGS_FOR_TARGET="$(CFLAGS)" && \
		make && \
		make install

musl:
	cd riscv-musl && \
		CFLAGS="$(CFLAGS)" ./configure --prefix=../build/musl --target=$(TARGET) --disable-shared && \
		make && make install

mruby:
	cd mruby && \
		NEWLIB=../build/newlib/$(TARGET) MRUBY_CONFIG=../build_config.rb make

secp256k1:
	cd secp256k1 && \
		./autogen.sh && \
		CC=$(CC) LD=$(LD) ./configure --with-bignum=no --enable-ecmult-static-precomputation --enable-endomorphism --host=$(TARGET) && \
		make libsecp256k1.la

clean-newlib:
	rm -rf build/newlib build/build-newlib

clean-musl:
	cd riscv-musl && make clean
	rm -rf build/musl

clean-mruby:
	cd mruby && \
		MUSL=../build/musl MRUBY_CONFIG=../build_config.rb make clean

clean-secp256k1:
	cd secp256k1 && make clean

clean: clean-newlib clean-musl clean-mruby clean-secp256k1

.PHONY: update_schema clean clean-newlib clean-musl clean-mruby clean-secp256k1 newlib musl mruby secp256k1