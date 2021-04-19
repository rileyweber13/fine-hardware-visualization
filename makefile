### DO NOT EDIT THIS FILE

# edits should not be necessary. Any changes you need to make may be done in
# config.mk 

include ./config.mk

###### rules intended for CLI use

# both these rules build everything
all: _build
build: _build

# this rule builds only the fhv executable
fhv: _fhv

# this rule only builds the performance monitoring shared library
perfmon_lib: _perfmon_lib

# this rule copies built things to FHV_PERFMON_PREFIX specified in config.mk
install: _install
uninstall: _uninstall

# these rules make examples
build-examples: _build-examples

# this rule makes assembly
assembly: _assembly

# this rule copies perfgroups from this project to the likwid perfgroup 
# directory
perfgroups: _perfgroups

# this rule removes objects and executables
clean: _clean

# this rule shows some of the makefile variables
debug: _debug

# this rule prints 'LD_LIBRARY_PATH' and 'PATH' wht the locations
# where fhv is included. Intended to be used as follows:
# `export $(make exports)`
exports: _exports

# same as above, but points to local build dir, not install dir
devexports: _devexports

###### END OF rules intended for CLI use


### constants

#### Directories 
SRC_DIR=src

#### exec
EXEC=$(EXEC_DIR)/$(EXEC_NAME)

#### Files
#HEADERS=$(wildcard $(SRC_DIR)/*.hpp)

SOURCES=$(SRC_DIR)/computation_measurements.cpp $(SRC_DIR)/fhv_main.cpp \
	$(SRC_DIR)/saturation_diagram.cpp
OBJS=$(SOURCES:$(SRC_DIR)/%.cpp=$(OBJ_DIR)/%.o)

SOURCES_SHARED_LIB=$(SRC_DIR)/fhv_perfmon.cpp $(SRC_DIR)/types.cpp \
	$(SRC_DIR)/utils.cpp
OBJS_SHARED_LIB=$(SOURCES_SHARED_LIB:$(SRC_DIR)/%.cpp=$(OBJ_DIR)/%.o)
HEADERS_SHARED_LIB_SHORT=fhv_perfmon.hpp architecture.hpp likwid_defines.hpp \
	performance_monitor_defines.hpp types.hpp utils.hpp
HEADERS_SHARED_LIB=$(addprefix $(SRC_DIR)/, $(HEADERS_SHARED_LIB_SHORT))

NLOHMANN_JSON_HEADER_SHORT=nlohmann/json.hpp
NLOHMANN_JSON_HEADER=$(SRC_DIR)/$(NLOHMANN_JSON_HEADER_SHORT)

ASM=$(SOURCES:$(SRC_DIR)/%.cpp=$(ASM_DIR)/%.s) \
	$(SOURCES_SHARED_LIB:$(SRC_DIR)/%.cpp=$(ASM_DIR)/%.s)

#### perfgroup things
SYSTEM_PERFGROUPS_DIR=$(LIKWID_PREFIX)/share/likwid/
PERFGROUPS_ROOT_DIR_NAME=perfgroups
PERFGROUPS_DIRS=$(shell find $(wildcard $(PERFGROUPS_ROOT_DIR_NAME)/*) -type d)

#### perfmon lib
PERFMON_LIB=$(BUILT_LIB_DIR)/$(PERFMON_LIB_NAME)


#### Flags for compilation proper

LIKWID_INC_DIR=-I$(LIKWID_PREFIX)/include
FHV_INC_DIRS=-I./$(SRC_DIR)
PANGOCAIRO_INC_DIRS=$(shell pkg-config --cflags pangocairo)
# combine everything above
INC_DIRS=$(LIKWID_INC_DIR) $(FHV_INC_DIRS) $(PANGOCAIRO_INC_DIRS)

# used as parts of constants below
#CXXFLAGS_BASE=$(INC_DIRS) -std=c++14 -fopenmp -DLIKWID_PERFMON
# if desired, also use some debug flags
CXXFLAGS_BASE=$(INC_DIRS) -std=c++14 -fopenmp -DLIKWID_PERFMON -Wall -g 

# used in actual compilation
CXXFLAGS=$(CXXFLAGS_BASE) $(ADDITIONAL_COMPILER_FLAGS)
CXXFLAGS_SHARED_LIB=$(CXXFLAGS_BASE) $(ADDITIONAL_COMPILER_FLAGS) -fpic
CXXASSEMBLYFLAGS=$(CXXFLAGS_BASE) -S -g -fverbose-asm


#### Flags for linking
LIKWID_LIB_DIR=-L$(LIKWID_PREFIX)/lib
PERFMON_LIB_DIR=-L$(BUILT_LIB_DIR)
# combine everything above
LIB_DIRS=$(LIKWID_LIB_DIR) $(PERFMON_LIB_DIR)

LIKWID_LIB_FLAG=-llikwid
PERFMON_LIB_FLAG=-l$(PERFMON_LIB_NAME_SHORT)
BOOST_PO_LIB_FLAG=-lboost_program_options
PANGOCAIRO_LIB_FLAG=$(shell pkg-config --libs pangocairo)
FMT_LIB_FLAG=-lfmt
OPENMP_LIB_FLAG=-fopenmp
# combine everything above
LIBS=$(LIKWID_LIB_FLAG) $(PERFMON_LIB_FLAG) $(BOOST_PO_LIB_FLAG) \
	$(PANGOCAIRO_LIB_FLAG) $(OPENMP_LIB_FLAG) $(FMT_LIB_FLAG)

LDFLAGS=$(LIB_DIRS) $(LIBS) $(ADDITIONAL_LINKER_FLAGS)

LDFLAGS_SHARED_LIB=$(LIKWID_LIB_DIR) $(LIKWID_LIB_FLAG) -shared \
	$(ADDITIONAL_LINKER_FLAGS)



#### prefix used to ensure likwid libraries and access daemon are detected and 
# used at runtime. 

RUN_CMD_PREFIX=LD_LIBRARY_PATH=$(LIKWID_PREFIX)/lib:$(FHV_PERFMON_PREFIX)/lib:$$LD_LIBRARY_PATH \
	PATH="$(LIKWID_PREFIX)/sbin:$(LIKWID_PREFIX)/bin:$(FHV_PERFMON_PREFIX)/bin:$$PATH"

RUN_CMD_PREFIX_DEV=LD_LIBRARY_PATH=$(LIKWID_PREFIX)/lib:$(BUILD_DIR)/lib:$$LD_LIBRARY_PATH \
	PATH="$(LIKWID_PREFIX)/sbin:$(LIKWID_PREFIX)/bin:$(BUILD_DIR)/bin:$$PATH"

#### meta-rules: These implement the functionality that users call 

_build: $(EXEC) $(PERFMON_LIB)

_install: $(EXEC) $(PERFMON_LIB) $(HEADERS_SHARED_LIB) $(FHV_PERFMON_PREFIX) perfgroups
	@cp $(EXEC) $(FHV_PERFMON_PREFIX)/bin/$(EXEC_NAME)
	@cp $(PERFMON_LIB) $(FHV_PERFMON_PREFIX)/lib/$(PERFMON_LIB_NAME)
	@cp $(HEADERS_SHARED_LIB) $(FHV_PERFMON_PREFIX)/include/
	@cp $(NLOHMANN_JSON_HEADER) $(FHV_PERFMON_PREFIX)/include/nlohmann/

_uninstall:
	@rm -f $(FHV_PERFMON_PREFIX)/bin/$(EXEC_NAME)
	@rm -f $(FHV_PERFMON_PREFIX)/lib/$(PERFMON_LIB_NAME)
	@rm -f $(addprefix $(FHV_PERFMON_PREFIX)/include/, $(HEADERS_SHARED_LIB_SHORT))
	@rm -f $(FHV_PERFMON_PREFIX)/include/$(NLOHMANN_JSON_HEADER_SHORT)

_build-examples: 
	@cd examples/polynomial_expansion; make;
	@cd examples/convolution; make;

_assembly: $(ASM)

_fhv: $(EXEC)

_perfmon_lib: $(PERFMON_LIB)

_perfgroups: $(PERFGROUPS_DIRS)

_clean:
	rm -rf $(wildcard $(BUILD_DIR)/*)

_exports:
	@echo $(RUN_CMD_PREFIX)

_devexports:
	@echo $(RUN_CMD_PREFIX_DEV)

#### utility rules
# TODO: what do we want this rule to do?
_debug:
	@echo "sources:              $(SOURCES)";
	@echo "objects:              $(OBJS)";
	@echo "sources (shared lib): $(SOURCES_SHARED_LIB)";
	@echo "objs (shared lib):    $(OBJS_SHARED_LIB)";
	@echo "exec:                 $(EXEC)";
	@echo "asm:                  $(ASM)"; 
	@echo "compile command:      $(compile-command)"; 
	@echo "ldflags:              $(LDFLAGS)"; 
	@echo "ld flags, shared lib: $(LDFLAGS_SHARED_LIB)"; 
_debug: LDFLAGS += -Q --help=target
# debug: clean build


### COMPILATION PROPER
#$(OBJS): | $(OBJ_DIR)

define compile-command
$(CXX) $(CXXFLAGS) -c $< -o $@
endef

## compilation of sources
$(OBJ_DIR)/computation_measurements.o: $(SRC_DIR)/computation_measurements.cpp $(SRC_DIR)/computation_measurements.hpp
	$(compile-command)

$(OBJ_DIR)/saturation_diagram.o: $(SRC_DIR)/saturation_diagram.cpp $(SRC_DIR)/saturation_diagram.hpp
	$(compile-command)

# main file
$(OBJ_DIR)/fhv_main.o: $(SRC_DIR)/fhv_main.cpp
	$(compile-command)

## compilation of fhv_perfmon lib
$(OBJS_SHARED_LIB): | $(OBJ_DIR)

define compile-command-shared-lib
$(CXX) $(CXXFLAGS_SHARED_LIB) -c $< -o $@
endef

$(OBJ_DIR)/fhv_perfmon.o: $(SRC_DIR)/fhv_perfmon.cpp $(SRC_DIR)/fhv_perfmon.hpp
	$(compile-command-shared-lib)


$(OBJ_DIR)/types.o: $(SRC_DIR)/types.cpp $(SRC_DIR)/types.hpp
	$(compile-command-shared-lib)

$(OBJ_DIR)/utils.o: $(SRC_DIR)/utils.cpp $(SRC_DIR)/utils.hpp
	$(compile-command-shared-lib)


### LINKING
## linking perfmon shared lib
$(PERFMON_LIB): $(OBJS_SHARED_LIB) | $(BUILT_LIB_DIR)
	$(CXX) $^ $(LDFLAGS_SHARED_LIB) -o $@ 

## linking executable
$(EXEC): $(PERFMON_LIB) $(OBJS) | $(EXEC_DIR)
	$(CXX) $(OBJS) $(LDFLAGS) -o $@

### CREATING ASSEMBLY
$(ASM): | $(ASM_DIR)

define asm-command
$(CXX) $(CXXFLAGS) $(CXXASSEMBLYFLAGS) $< -o $@
endef

$(ASM_DIR)/%.s: $(SRC_DIR)/%.cpp 
	$(asm-command)

### rules to create directories
define mkdir-command
mkdir -p $@
endef

$(BUILT_LIB_DIR):
	$(mkdir-command)

$(EXEC_DIR):
	$(mkdir-command)

$(OBJ_DIR):
	$(mkdir-command)

$(ASM_DIR):
	$(mkdir-command)

$(FHV_PERFMON_PREFIX): $(FHV_PERFMON_PREFIX)/bin $(FHV_PERFMON_PREFIX)/lib $(FHV_PERFMON_PREFIX)/include $(FHV_PERFMON_PREFIX)/include/nlohmann
$(FHV_PERFMON_PREFIX)/bin:
	$(mkdir-command)

$(FHV_PERFMON_PREFIX)/lib:
	$(mkdir-command)

$(FHV_PERFMON_PREFIX)/include:
	$(mkdir-command)

$(FHV_PERFMON_PREFIX)/include/nlohmann:
	$(mkdir-command)

### rules to copy perfgroups
.PHONY: $(PERFGROUPS_DIRS)

define copy-perfgroups-command
sudo cp $(wildcard $@/*) $(SYSTEM_PERFGROUPS_DIR)$@/
endef

$(PERFGROUPS_DIRS):
	@$(copy-perfgroups-command)
