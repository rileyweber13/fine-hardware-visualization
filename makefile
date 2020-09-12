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

# these rules make and run tests
tests: _tests
tests-run: _tests-run

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

###### END OF rules intended for CLI use


### constants

#### Directories 
SRC_DIR=src
TEST_DIR=tests

#### exec
EXEC=$(EXEC_DIR)/$(EXEC_NAME)

#### Files
HEADERS=$(wildcard $(SRC_DIR)/*.hpp)

SOURCES=$(SRC_DIR)/computation_measurements.cpp $(SRC_DIR)/fhv_main.cpp \
$(SRC_DIR)/saturation_diagram.cpp
OBJS=$(SOURCES:$(SRC_DIR)/%.cpp=$(OBJ_DIR)/%.o)

SOURCES_SHARED_LIB=$(SRC_DIR)/performance_monitor.cpp
OBJS_SHARED_LIB=$(SOURCES_SHARED_LIB:$(SRC_DIR)/%.cpp=$(OBJ_DIR)/%.o)

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
CXXFLAGS_BASE=$(INC_DIRS) -std=c++14 -fopenmp -DLIKWID_PERFMON
CXXFLAGS_DEBUG=$(CXXFLAGS_BASE) -Wall -g 

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
OPENMP_LIB_FLAG=-fopenmp
# combine everything above
LIBS=$(LIKWID_LIB_FLAG) $(PERFMON_LIB_FLAG) $(BOOST_PO_LIB_FLAG) \
$(PANGOCAIRO_LIB_FLAG) $(OPENMP_LIB_FLAG)

LDFLAGS=$(LIB_DIRS) $(LIBS) $(ADDITIONAL_LINKER_FLAGS)
# TODO: test if we need -fopenmp during linking
# LDFLAGS=$(LIB_DIRS) $(LIBS) -fopenmp

LDFLAGS_SHARED_LIB=$(LIKWID_LIB_DIR) $(LIKWID_LIB_FLAG) -shared \
$(ADDITIONAL_LINKER_FLAGS)


#### meta-rules: These are the rules designed for the user to call

_build: $(EXEC) $(PERFMON_LIB)

_install: $(EXEC) $(PERFMON_LIB)
	@cp $(EXEC) $(FHV_PERFMON_PREFIX)/bin/$(EXEC_NAME);
	@cp $(PERFMON_LIB) $(FHV_PERFMON_PREFIX)/lib/$(PERFMON_LIB_NAME);

_build-examples: 
	@cd examples/polynomial_expansion; make;
	@cd examples/convolution; make;

_assembly: $(ASM)

_fhv: $(EXEC)

_perfmon_lib: $(PERFMON_LIB)

_perfgroups: $(PERFGROUPS_DIRS)

_clean:
	rm -rf $(wildcard $(BUILD_DIR)/*)

#### utility rules
# TODO: what do we want this rule to do?
_debug:
	@echo "sources:              $(SOURCES)";
	@echo "objects:              $(OBJS)";
	@echo "sources (shared lib): $(SOURCES_SHARED_LIB)";
	@echo "objs (shared lib):    $(OBJS_SHARED_LIB)";
	@echo "exec:                 $(EXEC)";
	@echo "asm:                  $(ASM)"; 
_debug: LDFLAGS += -Q --help=target
# debug: clean build


### COMPILATION PROPER
$(OBJS): $(SOURCES) $(HEADERS) | $(OBJ_DIR)

define compile-command
$(CXX) $(CXXFLAGS) -c $< -o $@
endef

## compilation of sources
$(OBJ_DIR)/computation_measurements.o: $(SRC_DIR)/computation_measurements.cpp
	$(compile-command)

$(OBJ_DIR)/saturation_diagram.o: $(SRC_DIR)/saturation_diagram.cpp
	$(compile-command)

# main file
$(OBJ_DIR)/fhv_main.o: $(SRC_DIR)/fhv_main.cpp
	$(compile-command)

## compilation of performance_monitor lib
$(OBJS_SHARED_LIB): $(SOURCES_SHARED_LIB) $(HEADERS) | $(OBJ_DIR)

define compile-command-shared-lib
$(CXX) $(CXXFLAGS_SHARED_LIB) -c $< -o $@
endef

$(OBJ_DIR)/performance_monitor.o: $(SRC_DIR)/performance_monitor.cpp
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

$(ASM_DIR)/%.s: $(TEST_DIR)/%.cpp
	$(asm-command)

$(ASM_DIR)/%.s: $(TEST_DIR)/%.c
	$(asm-command)

### rules to create directories
define mkdir-command
mkdir -p $@
endef

$(BUILT_LIB_DIR):
	$(mkdir-command)

$(EXEC_DIR):
	$(mkdir-command)

$(TEST_EXEC_DIR):
	$(mkdir-command)

$(OBJ_DIR):
	$(mkdir-command)

$(TEST_OBJ_DIR):
	$(mkdir-command)

$(ASM_DIR):
	$(mkdir-command)

### rules to copy perfgroups
.PHONY: $(PERFGROUPS_DIRS)

define copy-perfgroups-command
sudo cp $(wildcard $@/*) $(SYSTEM_PERFGROUPS_DIR)$@/
endef

$(PERFGROUPS_DIRS):
	@echo sudo permission needed to copy to system directory. This will override
	@echo previously-copied groups but not groups shipped with likwid. The full
	@echo command to be issued is printed below:
	@echo
	@echo "$(copy-perfgroups-command)"
	@$(copy-perfgroups-command)

### Test rules
define test-ld-command
	$(CXX) $^ $(LDFLAGS) -o $@
endef

_tests: $(TEST_EXEC_DIR)/benchmark-likwid-vs-manual \
$(TEST_EXEC_DIR)/thread_migration $(TEST_EXEC_DIR)/likwid_minimal \
$(TEST_EXEC_DIR)/fhv-fhv_minimal

_tests-run: $(TEST_EXEC_DIR)/benchmark-likwid-vs-manual-run \
$(TEST_EXEC_DIR)/thread_migration-run $(TEST_EXEC_DIR)/likwid_minimal-run \
$(TEST_EXEC_DIR)/likwid_minimal-run-with-cli \
$(TEST_EXEC_DIR)/likwid_minimal-run-port-counter \
$(TEST_EXEC_DIR)/fhv-fhv_minimal-run

$(TEST_OBJ_DIR)/%.o: $(TEST_DIR)/%.cpp | $(TEST_OBJ_DIR)
	$(compile-command)

$(TEST_OBJ_DIR)/%.o: $(TEST_DIR)/%.c | $(TEST_OBJ_DIR)
	$(compile-command)

$(TEST_EXEC_DIR)/benchmark-likwid-vs-manual: $(TEST_OBJ_DIR)/benchmark-likwid-vs-manual.o | $(TEST_EXEC_DIR)
	$(test-ld-command)

$(TEST_EXEC_DIR)/benchmark-likwid-vs-manual-run: $(TEST_EXEC_DIR)/benchmark-likwid-vs-manual
	$(RUN_CMD_PREFIX) $(TEST_EXEC_DIR)/benchmark-likwid-vs-manual

$(TEST_EXEC_DIR)/thread_migration: $(TEST_OBJ_DIR)/thread_migration.o | $(TEST_EXEC_DIR)
	$(test-ld-command)

$(TEST_EXEC_DIR)/thread_migration-run: $(PERFMON_LIB) $(TEST_EXEC_DIR)
	$(RUN_CMD_PREFIX) $(TEST_EXEC_DIR)/thread_migration 0; \
	# $(TEST_EXEC_DIR)/thread_migration 1; \
	$(TEST_EXEC_DIR)/thread_migration 2;

$(TEST_EXEC_DIR)/likwid_minimal: $(TEST_DIR)/likwid_minimal.c | $(TEST_EXEC_DIR)
	gcc tests/likwid_minimal.c -I$(LIKWID_PREFIX)/include -L$(LIKWID_PREFIX)/lib -march=native -mtune=native -fopenmp -llikwid -o $@

$(TEST_EXEC_DIR)/likwid_minimal-run: $(TEST_EXEC_DIR)/likwid_minimal
	LD_LIBRARY_PATH=$(LIKWID_PREFIX)/lib $(TEST_EXEC_DIR)/likwid_minimal

$(TEST_EXEC_DIR)/likwid_minimal-run-with-cli: $(TEST_EXEC_DIR)/likwid_minimal
	# if this rule is to be used, the setenv stuff in likwid_minimal.c should be
	# commented out 
	LD_LIBRARY_PATH=$(LIKWID_PREFIX)/lib $(LIKWID_PREFIX)/bin/likwid-perfctr -C S0:0-3 -g MEM -g L2 -g L3 -g FLOPS_SP -g FLOPS_DP -g PORT_USAGE1 -g PORT_USAGE2 -g PORT_USAGE3 -M 1 -m $(TEST_EXEC_DIR)/likwid_minimal

$(TEST_EXEC_DIR)/likwid_minimal-run-port-counter: $(TEST_EXEC_DIR)/likwid_minimal
	# if this rule is to be used, the setenv stuff in likwid_minimal.c should be
	# commented out 
	LD_LIBRARY_PATH=$(LIKWID_PREFIX)/lib $(LIKWID_PREFIX)/bin/likwid-perfctr -C S0:0-3 -g PORT_USAGE1 -g PORT_USAGE2 -g PORT_USAGE3 -g PORT_USAGE_TEST -M 1 -m $(TEST_EXEC_DIR)/likwid_minimal

$(TEST_EXEC_DIR)/fhv_minimal: $(TEST_OBJ_DIR)/fhv_minimal.o | $(TEST_EXEC_DIR)
	$(test-ld-command)

$(TEST_EXEC_DIR)/fhv_minimal-run: $(PERFMON_LIB) $(TEST_EXEC_DIR)/fhv_minimal 
	$(RUN_CMD_PREFIX) $(TEST_EXEC_DIR)/fhv_minimal
