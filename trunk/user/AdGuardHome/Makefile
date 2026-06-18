THISDIR = $(shell pwd)

clean:
	rm -rf install
	rm -rf AdGuardHome.tar.gz

romfs:
	wget -O AdGuardHome.tar.gz https://static.adguard.com/adguardhome/release/AdGuardHome_linux_mipsle_softfloat.tar.gz
	tar xvf AdGuardHome.tar.gz
	mv AdGuardHome install
	$(ROMFSINST) $(THISDIR)/install/AdGuardHome /usr/bin/AdGuardHome
	$(ROMFSINST) -p +x /usr/bin/adguardhome.sh
