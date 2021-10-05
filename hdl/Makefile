MODS1	= xe_host_tb xe_host busMonitor aperture priority xio_bus
SRCS1	= $(addsuffix .v, $(MODS1))
PROG1	= /tmp/pixl.bin

MODS2	= priority_tb priority
SRCS2	= $(addsuffix .v, $(MODS2))
PROG2	= /tmp/priority.bin

all: testbench

testbench: $(SRCS1)
	iverilog -o $(PROG1) $(SRCS1)
	$(PROG1)

top: testbench
	gtkwave /tmp/wave.vcd `pwd`/xe_host.gtkw


priority: $(SRCS2)
	iverilog -o $(PROG2) $(SRCS2)
	$(PROG2)

