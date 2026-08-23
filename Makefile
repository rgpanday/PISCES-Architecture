# ==============================================================================
# VERILATOR SIMULATION MAKEFILE FOR CORE OF PISCES  CPU
# ==============================================================================

# De hoofd-module van je hardware
TOP_MODULE = absolute_chip_top

VERILOG_SOURCES = rtl/absolute_chip_top.sv \
                  rtl/pisc_host_core.sv \
                  rtl/l3_cache_top.sv \
                  rtl/smart_dma.sv \
                  rtl/gpu_top.sv \
                  rtl/core.sv \
                  rtl/warp_scheduler_v2.sv \
                  rtl/hbm_memory_controller.sv \
                  rtl/register_file.sv \
                  rtl/decoder.sv \
                  rtl/flexible_cla_alu.sv

# Het C++ testbench bestand
CPP_SOURCES = sim_main.cpp

# Standaard actie als je typt: 'make'
all: compile



compile:
	@echo "[BUILD] Verilating SystemVerilog files into C++..."
	verilator -Wall -Wno-UNUSEDSIGNAL -Wno-CMPCONST -Wno-UNSIGNED -Wno-WIDTHEXPAND -Wno-UNUSEDPARAM -Wno-DECLFILENAME -Wno-SELRANGE --cc $(VERILOG_SOURCES) --top-module $(TOP_MODULE) --exe $(CPP_SOURCES)
	
	@echo "[BUILD] Compiling generated C++ into an executable binary..."
	make -C obj_dir -f V$(TOP_MODULE).mk V$(TOP_MODULE)






run: compile
	@echo "[RUN] Executing the simulated 4096-ALU architecture..."
	# Start de simulatie-app die we net hebben gebouwd
	./obj_dir/V$(TOP_MODULE)

clean:
	@echo "[CLEAN] Removing simulation build files..."
	rm -rf obj_dir

