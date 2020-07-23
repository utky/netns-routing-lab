ASNETNS := sudo ip netns exec 
BINPATH := $(HOME)/.local/bin
#SERVICEDIR := $(HOME)/.config/systemd/user
CONFIGDIR := $(HOME)/.config/gobgp
GOBGP := $(BINPATH)/gobgp
GOBGPD := $(BINPATH)/gobgpd

.PHONY: status
status:
	ip netns list
	$(ASNETNS) r1 $(GOBGP) neighbor
	$(ASNETNS) r2 $(GOBGP) neighbor
	$(ASNETNS) r3 $(GOBGP) neighbor

.PHONY: setup
setup:
	sudo ip netns add r1
	sudo ip netns add r2
	sudo ip netns add r3
	# r1
	sudo ip link  add veth1 type veth peer name br-veth1
	sudo ip link  set br-veth1 up
	sudo ip link  set veth1 netns r1
	$(ASNETNS) r1 ip address add 192.168.0.1/24 dev veth1
	$(ASNETNS) r1 ip link set veth1 up
	$(ASNETNS) r1 ip link  add dummy1 type dummy
	$(ASNETNS) r1 ip link  set dummy1 netns r1
	$(ASNETNS) r1 ip address add 192.168.1.1/24 dev dummy1
	$(ASNETNS) r1 ip link  set dummy1 up
	$(ASNETNS) r1 ip link  set lo up
	# r2
	sudo ip link  add veth2 type veth peer name br-veth2
	sudo ip link  set br-veth2 up
	sudo ip link  set veth2 netns r2
	$(ASNETNS) r2 ip address add 192.168.0.2/24 dev veth2
	$(ASNETNS) r2 ip link set veth2 up
	$(ASNETNS) r2 ip link  add dummy2 type dummy
	$(ASNETNS) r2 ip link  set dummy2 netns r2
	$(ASNETNS) r2 ip address add 192.168.1.2/24 dev dummy2
	$(ASNETNS) r2 ip link  set dummy2 up
	$(ASNETNS) r2 ip link  set lo up
	# r3
	sudo ip link  add veth3 type veth peer name br-veth3
	sudo ip link  set br-veth3 up
	sudo ip link  set veth3 netns r3
	$(ASNETNS) r3 ip address add 192.168.0.3/24 dev veth3
	$(ASNETNS) r3 ip link set veth3 up
	$(ASNETNS) r3 ip link  add dummy3 type dummy
	$(ASNETNS) r3 ip link  set dummy3 netns r3
	$(ASNETNS) r3 ip address add 192.168.1.3/24 dev dummy3
	$(ASNETNS) r3 ip link  set dummy3 up
	$(ASNETNS) r3 ip link  set lo up
	# s1
	sudo ip link  add br1 type bridge
	sudo ip link  set br1 up
	sudo ip link  set br-veth1 master br1
	sudo ip link  set br-veth2 master br1
	sudo ip link  set br-veth3 master br1

.PHONY: teardown
teardown:
	$(ASNETNS) r3 ip link set dummy3 down
	$(ASNETNS) r3 ip link del dummy3
	$(ASNETNS) r2 ip link set dummy2 down
	$(ASNETNS) r2 ip link del dummy2
	$(ASNETNS) r1 ip link set dummy1 down
	$(ASNETNS) r1 ip link del dummy1
	#
	$(ASNETNS) r3 ip link set veth3 down
	$(ASNETNS) r3 ip link del veth3
	$(ASNETNS) r2 ip link set veth2 down
	$(ASNETNS) r2 ip link del veth2
	$(ASNETNS) r1 ip link set veth1 down
	$(ASNETNS) r1 ip link del veth1
	#
	sudo ip netns del r3
	sudo ip netns del r2
	sudo ip netns del r1
	sudo ip link  del br1

.PHONY: install
install: $(BINPATH)/gobgp

$(BINPATH)/gobgp:
	curl -LO https://github.com/osrg/gobgp/releases/download/v2.18.0/gobgp_2.18.0_linux_amd64.tar.gz
	tar xzf gobgp_2.18.0_linux_amd64.tar.gz
	rm gobgp_2.18.0_linux_amd64.tar.gz
	mkdir -p $(BINPATH)
	mv gobgp $(BINPATH)
	mv gobgpd $(BINPATH)

#.PHONY: install_service
#install_service: $(SERVICEDIR)/r1.service $(SERVICEDIR)/r2.service $(SERVICEDIR)/r3.service

#$(SERVICEDIR)/r1.service:
#	mkdir -p $(SERVICEDIR)
#	cp -p r1.service $@
#$(SERVICEDIR)/r2.service:
#	mkdir -p $(SERVICEDIR)
#	cp -p r2.service $@
#$(SERVICEDIR)/r3.service:
#	mkdir -p $(SERVICEDIR)
#	cp -p r3.service $@

.PHONY: clean_config
clean_config:
	rm $(CONFIGDIR)/r1.toml
	rm $(CONFIGDIR)/r2.toml
	rm $(CONFIGDIR)/r3.toml

.PHONY: install_config
install_config: $(CONFIGDIR)/r1.toml $(CONFIGDIR)/r2.toml $(CONFIGDIR)/r3.toml

$(CONFIGDIR)/r1.toml:
	mkdir -p $(CONFIGDIR)
	cp -p r1.toml $@
$(CONFIGDIR)/r2.toml:
	mkdir -p $(CONFIGDIR)
	cp -p r2.toml $@
$(CONFIGDIR)/r3.toml:
	mkdir -p $(CONFIGDIR)
	cp -p r3.toml $@

.PHONY: start start_r1 start_r2 start_r3
start: start_r1 start_r2 start_r3
start_r1:
	$(ASNETNS) r1 $(GOBGPD) -f $(CONFIGDIR)/r1.toml 2>&1 >> r1.log & echo $$? > $@
start_r2:
	$(ASNETNS) r2 $(GOBGPD) -f $(CONFIGDIR)/r2.toml 2>&1 >> r2.log & echo $$? > $@
start_r3:
	$(ASNETNS) r3 $(GOBGPD) -f $(CONFIGDIR)/r3.toml 2>&1 >> r3.log & echo $$? > $@

.PHONY: stop stop_r1 stop_r2 stop_r3
stop: stop_r1 stop_r2 stop_r3
stop_r1:
	$(ASNETNS) r1 pkill gobgpd
stop_r2:
	$(ASNETNS) r2 pkill gobgpd
stop_r3:
	$(ASNETNS) r3 pkill gobgpd
