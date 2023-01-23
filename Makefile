############################# Basics of Makefile rules
# PHONY has dependancies but no rules so no files by these names
# however, phonies shouldn't be prerequisites of real target files,
# otherwise its recipe will be run every time make considers that file
.PHONY: all apes bin/example.fake example.second example.first example.third \
       clean distclean mrproper fast veryfast slow veryslow newpm newxs \
       step1 step2 step3 step4

# PRECIOUS files are not deleted if make is interrupted during their recipes
.PRECIOUS: com/sxs_perl.com

# Other rules use constraint propagation, where each rule is:
#
#target: prerequisite1 prerequisite2 | prerequisite3_existance_only
#	do this and if it worked
#	then do that
#
# The prerequisites are done in order, which can be explained with make -d
#
# The "doing" part *MUST* start with a *REQUIRED* tab, and may use:
#  $$    -> just the dollar sign
#  $@    -> the target
#  $(@D) -> the directory part of $@ (the same D also works on $< etc)
#  $(@F) -> the file part of $@      (the same F also works on $< etc)
#  $<    -> the first prerequisite
#  $^    -> all the deduplicated prerequisites
#  $+    -> all the prerequisites as-is
#
# To not require starting with a tab, change the default .RECIPEPREFIX
#
# The first rule is the default one unless using .DEFAULT_GOAL
all: bin/example.fake $(redbeans:%=com/%) com/small_perl.com perlplebean.com

# Use this to showcase the syntax with a duplicate 1st + a order-only 3rd
bin/example.fake: example.first example.second example.first example.first | example.first example.third
ifeq ($(MAKELEVEL),0)
	@echo "First explaining the syntax with a phony (no such file will be created) $@"
	@echo
	@echo "bin/example.fake: example.first example.second example.first example.first | example.first example.third"
	@echo
	@echo There is a duplicated 1st prerequisite around the 2nd, and an order-only 3rd
	@echo Lines starting with tab are the recipe and may use special symbols
	@echo But notice how the 3rd is missing below since it is order-only due to pipe:
	@echo "\t\$$\$$" is the dollar sign: $$
	@echo "\t\$$@" is the target: $@
	@echo "\t\$$(@D)" is the directory part of the target: $(@D)
	@echo "\t\$$(@F)" is the file part of the target: $(@F)
	@echo "\t\$$<" is the first prerequisite: $<
	@echo "\t\$$^" is all the deduplicated prerequisites: $^
	@echo "\t\$$+" is all the regular prerequisites as-is: $+
	@echo "\t\$$|" is all the order-only prerequisites as-is: $!
	@echo "\t\$$%" is the archve target member name: $%
	@echo
	@echo "Then running a simulation with 'make -n' to check what must be done"
	@echo "Here example.second is phony so not listed"
	@echo
	@make -n -d |grep "Must remake"
	@make -n
	@echo
	@echo "End of the simulation, will now do that unless you hit Ctrl-C within the next second"
	@echo
	@sleep 1
else
	@echo "This is just a simulation"
endif

############################# APE binaries
# TODO: replace wget not just by wget.com or curl.com but by a perl script to facilitate bootstrap
# can't use pcurl which depends on openssl https://github.com/sebkirche/pcurl
# try https://metacpan.org/pod/Protocol::TLS to do TLSv1.2 if possible
# SSLv1: so broken it wasn't even released publicly.
# SSLv2: old and buried.
# SSLv3: broken, don't use unless you have an ancient device that you can't upgrade and that is on a well-protected network, not Internet-facing.
# TLSv1.0: deprecated but can still be used safely.
# TLSv1.1: deprecated but can still be used safely.
# TLSv1.2: recommended.
# TLSv1.3: coming soon.
# but without certificate checking: instead, use md5 and rely on git clone using https

# TODO: redbean is missing wget.com or curl.com, contributing them would benefit both projects
redbeans=zip.com unzip.com assimilate.com blackholed.com sqlite3.com # wget.com curl.com touch.com
redbean_site=https://redbean.dev
justine_site=https://justine.lol
justine_make=/make/landlockmake-1.3.com # FIXME: url changed
perl_git_url=https://github.com/G4Vi/Perl-Dist-APPerl/releases/download/v0.2.1/perl.com

# Get most binaries from redbean.dev
com/%:
	@wget -O com/$(@F) $(redbean_site)/$(@F)
	@touch $@

# TODO: try to make pledge work on WSL2
# in the meantime, test limits not like https://stackoverflow.com/questions/63960859/how-can-i-raise-the-limit-for-open-files-in-ubuntu-20-04-on-wsl2
# but more like https://github.com/microsoft/WSL/issues/4575:
# $ mylimit=8000
# $ sudo prlimit --nofile=$mylimit --pid $$; ulimit -n $mylimit
#com/pledge.com:
#	@wget $(justine_site)/$(@F) -O $(@D)/$(@F)
#	@touch $@

# TODO: should use pure perl solution perl.com make.pl zip.pl unzip.pl instead of make.com etc.
# consider https://metacpan.org/pod/Archive::Zip
# https://metacpan.org/pod/Makefile::Parser https://metacpan.org/pod/Make
# https://metacpan.org/pod/ExtUtils::MakeMaker
# then make the make step multiplatform: consider removing unixisms like touch
com/make.com:
	@wget $(justine_site)/$(justine_make) -O  $(@D)/$(@F)
	@touch $@

# Get perl.com from github, check new releases on https://github.com/G4Vi/Perl-Dist-APPerl/releases/
com/small_perl.com:
	@wget $(perl_git_url) -O $(@D)/$(@F)
	@touch $@

############################# Building
# Order:
#  first src.xs,
#  then sxs_perl.com using src.xs
#  then cpan using sxs_perl.com version,
#  then com/perplebean.com using cpan
#  then perlebean.com using bin/ tsv/ html/
#  FIXME: use variables for XS
# WONTFIX: The XS prerequisites are order-only as this step is slow, warn about this above, and below for fast
#com/sxs_perl.com: | src.xs/.done/IO-Socket-Multicast src.xs/.done/DBD-SQLite src.xs/.done/DBI src.xs/.done/Clone src.xs/.done/Devel-Gladiator src.xs/.done/PPI-XS src/Temp.pm .apperl/o/sxs_perl.com/perl.com
com/sxs_perl.com: | src.xs/.done/IO-Socket-Multicast src.xs/.done/Clone src.xs/.done/Devel-Gladiator src.xs/.done/PPI-XS src/Temp.pm .apperl/o/sxs_perl.com/perl.com
	PPB=`pwd` ; PERL5LIB="$$PPB/cpan/lib/perl5" PERL_MB_OPT="--install_base \"$$PPB/cpan\"" PERL_MM_OPT="INSTALL_BASE=$$PPB/cpan" PERL_LOCAL_LIB_ROOT="$$PPB/cpan" PATH="$$PATH:$$PPB/cpan/bin" ; env |grep perl
	@echo "Checking if APPerlm can install modules" 
	perl -e 'print join("\n",@INC);'|xargs find |grep APPerl.pm$ |xargs grep "itemconfig->{install_modules" || exit 1

# remove the build artefacts, but keep the build output to do make fast
clean:
	rm -fr .apperl cpan/lib cpan/bin cpan/.done

# also remove the build outputs
distclean: clean
	rm -f com/*

# also the output, remove cosmopolitan and cpan downloads
mrproper: distclean
	rm -fr perlplebean.com ~/.config/apperl/site.json ~/.local/share/apperl

# To go fast, update the payloads using the retained building artefact (not order only, will never be stale)
fast: perlplebean.com
	@echo "Only checking for pm: Date.pm MediaTypes.pm and XS: Clone Gladiator PPI::XS"
	@echo "If a new XS module is added (rare), remove com/sxs_perl.com or do:\tmake newxs"
	@com/unzip.com -vl com/$< | grep Date.pm$       || (rm -f com/$< ; exit 1)
	@com/unzip.com -vl com/$< | grep MediaTypes.pm$ || (rm -f com/$< ; exit 2)
	# Using $< as the lack of | (used for order-only prerequisites) makes it possible
	@com/unzip.com -vl com/$< | grep -i Clone.a$     || exit 1
	@com/unzip.com -vl com/$< | grep -i Gladiator.a$ || exit 2
	@com/unzip.com -vl com/$< | grep -i PPI/XS/XS.a$ || exit 3
	cp com/$< $<
	@com/unzip.com -vl $< | grep -A9999 bin/zipdetails |grep -v zipdetails || echo "No extra assets found inside $< "
	@com/zip.com -r $< lib/ bin/ cgi/ html/ tsv/

# To go very fast, just update the payloads of perlplebean.com
# if the required core modules or XS are abset, remove the current binary
# (also done automatically by the perlplebean.com rule, this is in case the binary was mangled by something)
veryfast: perlplebean.com
	@echo "Not even checking for pm: Date.pm MediaTypes.pm and XS: Clone Gladiator PPI::XS"
	@echo "If any pm is missing, remove perlplebean.com or do:\tmake newpm"
	@com/zip.com -r perlplebean.com lib/ bin/ cgi/ html/ tsv/
	@com/unzip.com -vl perlplebean.com | grep -A9999 bin/zipdetails |grep -v zipdetails || echo "No extra assets found inside perlplebean.com"
# The above show all the extra files included

# This is slow, so sxs_perl.com is kept as is and loaded with the assets by this Makefile
slow: apperl/o/sxs_perl.com/perl.com

# This blind remake is worse, and be be forced by a mrproper ("step0")
veryslow: | mrproper apperl/o/sxs_perl.com/perl.com

# Shortcuts to remove as needed for a new pm or XS
newxs:
	rm -f com/sxs_perl.com
	$(MAKE) com/sxs_perl.com

newpm:
	rm -f perlplebean.com com/perlplebean.com
	$(MAKE) perlplebean.com

############################# Building dependancies
# These are used to build sxs_perl

# Future proofing in case we need to use the version within the path for some patches
ifneq (,$(wildcard com/sxs_perl.com))
PERL_VERSION != com/sxs_perl.com -e '{ my $$v=$$^V; $$v=~s/^v//; print $$v }'
else ifneq (,$(wildcard com/small_perl.com))
PERL_VERSION != com/small_perl.com -e '{ my $$v=$$^V; $$v=~s/^v//; print $$v }'
endif

# To be safe, the core File::Temp needs to know about cosmo, so force install then patch it
src/Temp.pm: cpan/.done/File-Temp

cpan/.done/File-Temp:
	@mkdir -p $(@D)
	PPB=`pwd` ; PERL5LIB="$$PPB/cpan/lib/perl5" PERL_MB_OPT="--install_base \"$$PPB/cpan\"" PERL_MM_OPT="INSTALL_BASE=$$PPB/cpan" PERL_LOCAL_LIB_ROOT="$$PPB/cpan" PATH="$$PATH:$$PPB/cpan/bin" cpan install -f $(subst -,::,$(@F))
	cat cpan/lib/perl5/File/Temp.pm | sed -e 's/qw\/MSWin32 os2 VMS dos MacOS haiku\//qw\/MSWin32 os2 VMS dos MacOS haiku cosmo\//g' > src/Temp.pm
	touch $@


# The XS are much simpler
# FIXME: use a variable like for the PM as DBI-DBD should just be DBD
#src.xs/.done/IO-Socket-Multicast src.xs/.done/DBD-SQLite src.xs/.done/DBI src.xs/.done/Clone src.xs/.done/Devel-Gladiator src.xs/.done/PPI-XS:
src.xs/.done/IO-Socket-Multicast src.xs/.done/Clone src.xs/.done/Devel-Gladiator src.xs/.done/PPI-XS:
	@mkdir -p $(@D)

ifneq (,$(wildcard src.xs/$(@F).tar.gz))
	@echo "Downloading src.xs/$(@F).tar.gz"
	@./download_package.pl $(subst -,::,$(@F)) src.xs
else
	@echo "Already got src.xs/$(@F).tar.gz"
endif
	# -C changes to the directory to extract there
	@tar zxvf src.xs/$(@F).tar.gz -C src.xs/
	@touch $@

############################# new APPerl building approach to link some XS modules
## Used to be all-on-one:
#.apperl/user-project.json:
#         PPB=`pwd` ; PERL5LIB="$$PPB/cpan/perl5/lib/perl5" PERL_MB_OPT="--install_base \"$$PPB/cpan/perl5\"" PERL_MM_OPT="INSTALL_BASE=$$PPB/cpan/perl5" PERL_LOCAL_LIB_ROOT="$$PPB/cpan/perl5" PATH="$$PATH:$$PPB/cpan/perl5/bin" ; env |grep perl && cpan install Perl::Dist::APPerl
#         apperlm install-build-deps
#         apperlm checkout PerlPleBean
##         apperlm configure
##         apperlm build

# Now the slow and complicated json process is limited to sxs_perl.com and broken down in 4 steps
# (Step 0: rm -fr ~/.config/apperl/site.json ~/.local/share/apperl)
# (= optional clean to avoid problems by starting from scratch)
# Step 1: apperlm install-build-deps
# = download perl5 fork and cosmopolitan source, save config to ~/.config/apperl/site.json
# Step 2: apperlm checkout sxs_perl.com
# = use apperl-project.json to copy things to perl, reset git head etc
# Step 3: apperlm configure
# = build cosmopolitan and prepare perl bootstrapping
# Step 4: apperlm build
# = bootstrap perl, include the XS etc

# Download Cosmopolitan, install APPerl to the default cpan destination
# FIXME: may also need ExtUtils::MakeMaker ExtUtils::Manifest + force install File::Copy File::Copy::Recursive
# if going on with the multiplatform bootstrap plan
$${HOME}/.config/apperl/site.json:
	apperlm help || cpan install Perl::Dist::APPerl
# TODO: could install cpan CPAN/bin and then replace `cpan install` by `"$PPB/lib/perl5/5.36.0/cpan/bin/cpan" install`
# but the current version of APPerl on cpan doesn't have install_modules??
#	PPB=`pwd` ; PERL5LIB="$$PPB/cpan/lib/perl5" PERL_MB_OPT="--install_base \"$$PPB/cpan\"" PERL_MM_OPT="INSTALL_BASE=$$PPB/cpan" PERL_LOCAL_LIB_ROOT="$$PPB/cpan" PATH="$$PATH:$$PPB/cpan/bin" ; env |grep perl && cpan install Perl::Dist::APPerl
	apperlm install-build-deps
	touch $${HOME}/.config/apperl/site.json

# FIXME: investigate why using $${HOME} above vs ${HOME} here, and if it's right for multiplatform bootstrap
# Download APPerl
.apperl: | ${HOME}/.config/apperl/site.json
	#@mkdir -p $@
	apperlm checkout sxs_perl.com
# WARNING: doing an assimilate here seems overkill
#	for i in ~/.local/share/apperl/cosmopolitan/build/bootstrap/*com ; do com/assimilate.com $i ; done

# Step3: Configure perl and compile cosmopolitan : order only to avoid needless configure
.apperl/user-project.json: | .apperl
	apperlm configure

# Step4: Compile perl : order only to avoid needless recompilations
#src.xs/.done/IO-Socket-Multicast src.xs/.done/DBD-SQLite src.xs/.done/DBI src.xs/.done/Clone src.xs/.done/Devel-Gladiator src.xs/.done/PPI-XS | .apperl/user-project.json
.apperl/o/sxs_perl.com/perl.com: | .apperl/user-project.json
	apperlm build

############################# Dependencies
# We start by reading the version like 5.36.0 as it's used in the path, and hardcoding it would be brittle
ifneq (,$(wildcard com/sxs_perl.com))
PERL_VERSION != com/sxs_perl.com -e '{ my $$v=$$^V; $$v=~s/^v//; print $$v }'
else ifneq (,$(wildcard com/small_perl.com))
PERL_VERSION != com/small_perl.com -e '{ my $$v=$$^V; $$v=~s/^v//; print $$v }'
endif

# For now, apperl-project.json directly uses:
#  - some pm files from /usr/share/perl5/ and src/
# While the apps also expect:
#  - some pm files from cpan
#  which are installed by default in cpan/lib/perl5
#  while are expected to be in cpan/lib/perl5/5.36.0
#
# Given how cumbersome the paths are, like:
#  cpan/lib/perl5/5.36.0/Statistics/Descriptive/Smoother/Exponential.pm
# could try automate the Makefile update a little more!
# It could be done by populating variables from scripts or includes:
#  - input would be the cpan module name: could extract the "use" from bin/*
#  - output would come from the .packlist after a cpan install of the module
#  like `cat cpan/lib/perl5/x86_64-linux-gnu-thread-multi/auto/HTTP/Message/.packlist |grep -v 3pm|grep -v pod |sed -e 's/.*perlplebean\///g'`
#  or by downloading and exploring the source using $file( make function
#
# However, the path are still too big, for no good reason: could be
# cpan/HTTP/Daemon.pm instead of cpan/lib/perl5/5.36.0/HTTP/Daemon.pm
#
# lib/perl5/5.36.0 is there because of traditions:
#  - on the head, lib/perl5 is how cpan traditionally work
# as binaries need a place to go (cpan/bin) and perl7 may happen
#  - on the tail, 5.36.0 is needed as part of the zip destination prefix
# but APerl build could use different default installprivlib and installarchlib

############################# Dependencies requiring core modules from the system

# FIXME: decide if that should be handled by the json file instead by including right
# next to the XSs: LWP, HTTP::Date HTTP::Request::Common
# or if it's better to keep the json as simple as required (only the XSs + Temp.pm)
# since the apperlm build process using the json is brittle and a little slow
# FIXME: even then, could fold local_cpan into force_cpan with cpan install -f
# like below, which would also be better for multiplatform bootstrap
# The current separation between local_cpan and force_cpan dates from when local_cpan
# was included in the json, like src/Temp.pm
# TODO: better in the long run: currently no prerequisite or either com/small_perl.com or com/sxs_perl.com

# HTTP::Daemon depends on a few core pm that should already be available (could force install them if needed)
# Variables avoid phonies and will facilitate automation, like by reading the .packlist
CPAN_HTTP_Request := cpan/lib/perl5/HTTP/Request.pm
CPAN_HTTP_Request_Common := cpan/lib/perl5/HTTP/Request/Common.pm
CPAN_HTTP_Response := cpan/lib/perl5/HTTP/Response.pm
CPAN_HTTP_Status := cpan/lib/perl5/HTTP/Status.pm
CPAN_HTTP_Date := cpan/lib/perl5/HTTP/Date.pm
CPAN_LWP_MediaTypes := cpan/lib/perl5/LWP/MediaTypes.pm
CPAN_URI_DIR := cpan/lib/perl5/URI/
CPAN_URI := cpan/lib/perl5/URI.pm

# FIXME: custom one, to be moved to a patch
CPAN_Net_DNS_Nameserver := src/Nameserver.pm

# Variable for the recipe rule
LOCAL_CPAN := ${CPAN_HTTP_Request} ${CPAN_HTTP_Request_Common} ${CPAN_HTTP_Response} ${CPAN_HTTP_Status} ${CPAN_HTTP_Date} ${CPAN_LWP_MediaTypes} ${CPAN_URI} ${CPAN_URI_DIR} ${CPAN_Net_DNS_Nameserver}
# Variable to use as a prerequiste
LOCAL_CPAN_VERSIONNED := $(subst cpan/lib/perl5/,cpan/lib/perl5/${CPAN_VERSION}/, ${LOCAL_CPAN})

# For our reference
cpan/.done/from_local_install: ${LOCAL_CPAN}
	@touch $@

# No dependancy means we assume core modules are done well enought that version is irrelevant
${LOCAL_CPAN}:
	@mkdir -p $(@D)
	@cp -fpr $(subst cpan/lib/perl5,/usr/share/perl5,$@) $@
	@mkdir -p cpan/lib/perl5/${PERL_VERSION}
	@cp -fpr $@ $(subst cpan/lib/perl5,cpan/lib/perl5/${PERL_VERSION},$@)
	# Touch is required to update the timestamp as cp preserves the original one of the system file
	@touch $@
	# Separately mark as done just for reference
	@touch $(subst cpan/lib/perl5/,cpan/.done/, $@)

############################# Dependencies requiring forced cpan install
# These must be forced installed as they are core but not on APPerl
# TODO: could find a way to make the -f flag a conditional instead of having 2 sections for normal vs force

CPAN_Eval_Safe := cpan/lib/perl5/Eval/Safe.pm cpan/lib/perl5/Eval/Safe/Eval.pm cpan/lib/perl5/Eval/Safe/ForkedSafe.pm cpan/lib/perl5/Eval/Safe/Safe.pm
CPAN_MIME_Types := cpan/lib/perl5/MIME/Types.pm cpan/lib/perl5/MIME/Type.pm cpan/lib/perl5/MIME/types.db

# FIXME FIXME: wtf is types.db not copied?

# Variable for the recipe rule
FORCE_CPAN := ${CPAN_Eval_Safe} ${CPAN_MIME_Types}
# Variable to use as a prerequiste
FORCE_CPAN_VERSIONNED := $(subst cpan/lib/perl5/,cpan/lib/perl5/${CPAN_VERSION}/, ${FORCE_CPAN})

# For our reference, could be used to remove the files and force a cpan reinstall
cpan/.done/forced_cpan_install: ${FORCED_CPAN}
	@touch $@

# Depends on com_sxs_perl, to know the version
${FORCE_CPAN}: | com/sxs_perl.com
	# Can't remove the marker anymore, to avoid cpan install returning an error if already installed
	#$(if $(subst .pm,,$(suffix $(@F))),,\
	#@rm -f $(subst |,/, $(subst /,-,$(subst cpan/lib/perl5/,cpan|.done|,$(subst .pm,,$@))))\
	#)
	@mkdir -p $(@D)
	# Will only cpan install names like Mo/Du/le.pm that can be used to make a Mo::Du::le
	#@echo $(subst cpan/lib/perl5/,,$@)
	#@echo $(subst cpan/lib/perl5/,,$(subst .pm,,$@))
	#@echo $(subst /,::,$(subst cpan/lib/perl5/,,$(subst .pm,,$@)))
ifeq (,$(wildcard $(subst |,/, $(subst /,-,$(subst cpan/lib/perl5/,cpan|.done|,$(subst .pm,,$@))))))
	$(if $(subst .pm,,$(suffix $(@F))),\
	@echo skipping cpan install of $@,\
	PPB=`pwd` ; PERL5LIB="$$PPB/cpan/lib/perl5" PERL_MB_OPT="--install_base \"$$PPB/cpan\"" PERL_MM_OPT="INSTALL_BASE=$$PPB/cpan" PERL_LOCAL_LIB_ROOT="$$PPB/cpan" PATH="$$PATH:$$PPB/cpan/bin" cpan install -f $(subst /,::,$(subst cpan/lib/perl5/,,$(subst .pm,,$@)))\
	)
else
	@echo "not reinstalling $(subst /,::,$(subst cpan/lib/perl5/,,$(subst .pm,,$@))) due to $(wildcard $(subst |,/, $(subst /,-,$(subst cpan/lib/perl5/,cpan|.done|,$(subst .pm,,$@)))))"
endif
	mkdir -p cpan/lib/perl5/${PERL_VERSION}
	mkdir -p $(dir $(subst cpan/lib/perl5,cpan/lib/perl5/${PERL_VERSION},$@))
	cp -fpr $@ $(subst cpan/lib/perl5,cpan/lib/perl5/${PERL_VERSION},$@)
	# Touch should not be required, it's just handy
	#@touch $@
	# Separately mark as done to avoid reinstalls and to catch files not matching .pm
	$(if $(subst .pm,,$(suffix $(@F))),,\
	@touch $(subst |,/, $(subst /,-,$(subst cpan/lib/perl5/,cpan|.done|,$(subst .pm,,$@))))\
	)

############################# Dependencies: cpan modules

# cpan = force|normal cpan install + core modules not present in APPerl or that require patching

############################# Dependencies only requiring a normal install
# TODO: could find a way to make the -f flag a conditional instead of having 2 sections for normal vs force

# NET::DNS::Nameserver Depends on Digest::HMAC for some functions not used here
CPAN_Net_DNS := cpan/lib/perl5/Net/DNS.pm cpan/lib/perl5/Net/DNS/Domain.pm cpan/lib/perl5/Net/DNS/DomainName.pm cpan/lib/perl5/Net/DNS/Header.pm cpan/lib/perl5/Net/DNS/Mailbox.pm cpan/lib/perl5/Net/DNS/Nameserver.pm cpan/lib/perl5/Net/DNS/Packet.pm cpan/lib/perl5/Net/DNS/Parameters.pm cpan/lib/perl5/Net/DNS/Question.pm cpan/lib/perl5/Net/DNS/RR.pm cpan/lib/perl5/Net/DNS/RR/A.pm cpan/lib/perl5/Net/DNS/RR/AAAA.pm cpan/lib/perl5/Net/DNS/RR/AFSDB.pm cpan/lib/perl5/Net/DNS/RR/AMTRELAY.pm cpan/lib/perl5/Net/DNS/RR/APL.pm cpan/lib/perl5/Net/DNS/RR/CAA.pm cpan/lib/perl5/Net/DNS/RR/CDNSKEY.pm cpan/lib/perl5/Net/DNS/RR/CDS.pm cpan/lib/perl5/Net/DNS/RR/CERT.pm cpan/lib/perl5/Net/DNS/RR/CNAME.pm cpan/lib/perl5/Net/DNS/RR/CSYNC.pm cpan/lib/perl5/Net/DNS/RR/DHCID.pm cpan/lib/perl5/Net/DNS/RR/DNAME.pm cpan/lib/perl5/Net/DNS/RR/DNSKEY.pm cpan/lib/perl5/Net/DNS/RR/DS.pm cpan/lib/perl5/Net/DNS/RR/EUI48.pm cpan/lib/perl5/Net/DNS/RR/EUI64.pm cpan/lib/perl5/Net/DNS/RR/GPOS.pm cpan/lib/perl5/Net/DNS/RR/HINFO.pm cpan/lib/perl5/Net/DNS/RR/HIP.pm cpan/lib/perl5/Net/DNS/RR/HTTPS.pm cpan/lib/perl5/Net/DNS/RR/IPSECKEY.pm cpan/lib/perl5/Net/DNS/RR/ISDN.pm cpan/lib/perl5/Net/DNS/RR/KEY.pm cpan/lib/perl5/Net/DNS/RR/KX.pm cpan/lib/perl5/Net/DNS/RR/L32.pm cpan/lib/perl5/Net/DNS/RR/L64.pm cpan/lib/perl5/Net/DNS/RR/LOC.pm cpan/lib/perl5/Net/DNS/RR/LP.pm cpan/lib/perl5/Net/DNS/RR/MB.pm cpan/lib/perl5/Net/DNS/RR/MG.pm cpan/lib/perl5/Net/DNS/RR/MINFO.pm cpan/lib/perl5/Net/DNS/RR/MR.pm cpan/lib/perl5/Net/DNS/RR/MX.pm cpan/lib/perl5/Net/DNS/RR/NAPTR.pm cpan/lib/perl5/Net/DNS/RR/NID.pm cpan/lib/perl5/Net/DNS/RR/NS.pm cpan/lib/perl5/Net/DNS/RR/NSEC.pm cpan/lib/perl5/Net/DNS/RR/NSEC3.pm cpan/lib/perl5/Net/DNS/RR/NSEC3PARAM.pm cpan/lib/perl5/Net/DNS/RR/NULL.pm cpan/lib/perl5/Net/DNS/RR/OPENPGPKEY.pm cpan/lib/perl5/Net/DNS/RR/OPT.pm cpan/lib/perl5/Net/DNS/RR/PTR.pm cpan/lib/perl5/Net/DNS/RR/PX.pm cpan/lib/perl5/Net/DNS/RR/RP.pm cpan/lib/perl5/Net/DNS/RR/RRSIG.pm cpan/lib/perl5/Net/DNS/RR/RT.pm cpan/lib/perl5/Net/DNS/RR/SIG.pm cpan/lib/perl5/Net/DNS/RR/SMIMEA.pm cpan/lib/perl5/Net/DNS/RR/SOA.pm cpan/lib/perl5/Net/DNS/RR/SPF.pm cpan/lib/perl5/Net/DNS/RR/SRV.pm cpan/lib/perl5/Net/DNS/RR/SSHFP.pm cpan/lib/perl5/Net/DNS/RR/SVCB.pm cpan/lib/perl5/Net/DNS/RR/TKEY.pm cpan/lib/perl5/Net/DNS/RR/TLSA.pm cpan/lib/perl5/Net/DNS/RR/TSIG.pm cpan/lib/perl5/Net/DNS/RR/TXT.pm cpan/lib/perl5/Net/DNS/RR/URI.pm cpan/lib/perl5/Net/DNS/RR/X25.pm cpan/lib/perl5/Net/DNS/RR/ZONEMD.pm cpan/lib/perl5/Net/DNS/Resolver.pm cpan/lib/perl5/Net/DNS/Resolver/Base.pm cpan/lib/perl5/Net/DNS/Resolver/MSWin32.pm cpan/lib/perl5/Net/DNS/Resolver/Recurse.pm cpan/lib/perl5/Net/DNS/Resolver/UNIX.pm cpan/lib/perl5/Net/DNS/Resolver/android.pm cpan/lib/perl5/Net/DNS/Resolver/cygwin.pm cpan/lib/perl5/Net/DNS/Resolver/os2.pm cpan/lib/perl5/Net/DNS/Resolver/os390.pm cpan/lib/perl5/Net/DNS/Text.pm cpan/lib/perl5/Net/DNS/Update.pm cpan/lib/perl5/Net/DNS/ZoneFile.pm
# WARNING: Net::DNS::Nameserver depends on a XS: either Net::LibIDN or Net::LibIDN2
CPAN_List_MoreUtils := cpan/lib/perl5/List/MoreUtils/PP.pm
CPAN_HTTP_Daemon := cpan/lib/perl5/HTTP/Daemon.pm cpan/lib/perl5/HTTP/Config.pm cpan/lib/perl5/HTTP/Headers.pm cpan/lib/perl5/HTTP/Message.pm
# HTTP::Message provides many others and some XS, but only this pm seems required for HTTP::Daemon
CPAN_Tree_Treap := cpan/lib/perl5/Tree/Treap.pm
CPAN_MIME_Base64 := cpan/lib/perl5/MIME/Decoder/Base64.pm
CPAN_Statistics_Descriptive := cpan/lib/perl5/Statistics/Descriptive.pm cpan/lib/perl5/Statistics/Descriptive/Full.pm cpan/lib/perl5/Statistics/Descriptive/Sparse.pm
CPAN_Statistics_Smoother_Exponential := cpan/lib/perl5/Statistics/Descriptive/Smoother/Exponential.pm cpan/lib/perl5/Statistics/Descriptive/Smoother/Weightedexponential.pm
CPAN_Statistics_Descriptive_Weighted := cpan/lib/perl5/Statistics/Descriptive/Weighted.pm

# Variable for the recipe rule
NORMAL_CPAN := ${CPAN_Net_DNS} ${CPAN_List_MoreUtils} ${CPAN_HTTP_Daemon} ${CPAN_HTTP_Message} ${CPAN_Tree_Treap} ${CPAN_MIME_Base64} ${CPAN_Statistics_Descriptive} ${CPAN_Statistics_Smoother_Exponential} ${CPAN_Statistics_Descriptive_Weighted}
# Variable to use as a prerequiste
NORMAL_CPAN_VERSIONNED := $(subst cpan/lib/perl5/,cpan/lib/perl5/${CPAN_VERSION}/, ${FORCE_CPAN})

# For our reference, could be used to remove the files and force a cpan reinstall
cpan/.done/local_cpan_install: ${LOCAL_CPAN}
	@touch $@

# FIXME FIXME: WTF not working even with the full list?
# Depends on com/sxs_perl.com as an order-only prerequisite, only to know the version
${NORMAL_CPAN}: | com/sxs_perl.com
	# Can't remove the marker anymore, to avoid cpan install returning an error if already installed
	#$(if $(subst .pm,,$(suffix $(@F))),,\
	#@rm -f $(subst |,/, $(subst /,-,$(subst cpan/lib/perl5/,cpan|.done|,$(subst .pm,,$@))))\
	#)
	@mkdir -p $(@D)
	# Will only cpan install names like Mo/Du/le.pm that can be used to make a Mo::Du::le
	#@echo $(subst cpan/lib/perl5/,,$@)
	#@echo $(subst cpan/lib/perl5/,,$(subst .pm,,$@))
	#@echo $(subst /,::,$(subst cpan/lib/perl5/,,$(subst .pm,,$@)))
	# FIXME: should do notest if part of Net::DNS with a pragma, not not working even if pragma present like:
	# cpan notest install 
	@echo notest?= $(subst Net-DNS,notest,$(subst /,-,$(subst cpan/lib/perl5/,,$(findstring cpan/lib/perl5/Net/DNS,$(subst .pm,,$@)))))
ifeq (,$(wildcard $(subst |,/, $(subst /,-,$(subst cpan/lib/perl5/,cpan|.done|,$(subst .pm,,$@))))))
	$(if $(subst .pm,,$(suffix $(@F))),\
	@echo skipping cpan install of $@,\
	PPB=`pwd` ; PERL5LIB="$$PPB/cpan/lib/perl5" PERL_MB_OPT="--install_base \"$$PPB/cpan\"" PERL_MM_OPT="INSTALL_BASE=$$PPB/cpan" PERL_LOCAL_LIB_ROOT="$$PPB/cpan" PATH="$$PATH:$$PPB/cpan/bin" cpan install $(subst /,::,$(subst cpan/lib/perl5/,,$(subst .pm,,$@)))\
	)
else
	@echo "not reinstalling $(subst /,::,$(subst cpan/lib/perl5/,,$(subst .pm,,$@))) due to $(wildcard $(subst |,/, $(subst /,-,$(subst cpan/lib/perl5/,cpan|.done|,$(subst .pm,,$@)))))"
endif
	mkdir -p cpan/lib/perl5/${PERL_VERSION}
	mkdir -p $(dir $(subst cpan/lib/perl5,cpan/lib/perl5/${PERL_VERSION},$@))
	cp -fpr $@ $(subst cpan/lib/perl5,cpan/lib/perl5/${PERL_VERSION},$@)
	# Touch should not be required, it's just handy
	#@touch $@
	# Separately mark as done to avoid reinstalls and to catch files not matching .pm
	#was: @touch $(subst |,/, $(subst /,-,$(subst cpan/lib/perl5/,cpan|.done|,$(subst .pm,,$@))))
	$(if $(subst .pm,,$(suffix $(@F))),,\
	@touch cpan/.done/$(subst /,-,$(subst cpan/lib/perl5/,,$(findstring cpan/lib/perl5/Net/DNS,$(subst .pm,,$@))))\
	)


############################# Dependencies: cpan modules

# cpan = force|normal cpan install + core modules not present in APPerl or that require patching
cpan: ${LOCAL_CPAN_VERSIONNED} ${FORCE_CPAN_VERSIONNED} ${NORMAL_CPAN_VERSIONNED}

############################# PerlPleBean
# Just refresh the assets if the json file is unchanged, then give a visual confirmation of what's inside the .com
# com/perlplebean.com is an order-only prerequisite, warn about that
perlplebean.com: bin/perlplebean cgi/stats.pl html/css/xspreadsheet.css html/spreadsheet.template.html html/js/glue.sheetjs.xspreadsheet.js html/js/sheetjs.shim.min.js html/js/sheetjs.xlsx.full.min.js html/js/xspreadsheet.js html/svg/xspreadsheet.svg | com/perlplebean.com com/zip.com com/unzip.com
	@echo "If a new XS module is added (rare), remove com/sxs_perl.com or do:\tmake newxs"
	@echo "If a new pm module is added, remove com/perlplebean.com or do:\tmake newpm"
	cp com/$@ $@
	# grep after pl2pm to only show the updated assets
	@com/zip.com -r $@ lib/ bin/ cgi/ html/ tsv/
	@echo "This last step only refreshed the assets of $@ using com/$@ made before"
	@touch $@

# Fully rebuild the APE container using ./com/sxs_perl.com and the cpan modules
# WONTFIX: if cpan is made PHONY but listed as a prerequisite for a real file like com/perlplebean.com
#          then it leads to a minor discrepancy:
#                $ make -n cpan
#                make: Nothing to be done for 'cpan'.
#                $ make -n cpan -d |grep Must
#                Must remake target 'cpan'.
com/perlplebean.com: ${NORMAL_CPAN} | com/sxs_perl.com com/zip.com com/unzip.com
	@echo "Packing cpan assets in $@ using com/sxs_perl.com made before"
	@cp com/sxs_perl.com $@
	@echo Zip Path root in archive starts at current dir so cpan files were copied to lib/perl5/$$PERL_VERSION
	# FIXME: why is zip.com having dlmalloc issues? use native zip -r for now
	#@cd cpan && ../com/zip.com --ftrace -r ../$@ lib/perl5/`../$@ -e '{ my $$v=$$^V; $$v=~s/^v//; print $$v }'` # cd effects are only for the given line so only need ../ here
	@cd cpan && zip -r ../$@ lib/perl5/`../$@ -e '{ my $$v=$$^V; $$v=~s/^v//; print $$v }'` # cd effects are only for the given line so only need ../ here
	# Check both the included XS and a few needed pm not from CPAN
	# like /usr/share/perl5/HTTP/Date.pm and /usr/share/perl5/LWP/MediaTypes.pm
	@com/unzip.com -vl $@ | grep -i Multicast.a$ || exit 2
	@com/unzip.com -vl $@ | grep -i Clone.a$     || exit 3
	@com/unzip.com -vl $@ | grep -i Gladiator.a$ || exit 4
	@com/unzip.com -vl $@ | grep -i PPI/XS/XS.a$ || exit 5
	@com/unzip.com -vl $@ | grep -A9999 bin/zipdetails |grep -v zipdetails || echo "No extra assets found inside $@"
	@touch $@


############################# When IPC::Run or IPC::Run3 will be used again

#cpan/lib/perl5/IPC/Run/IO.pm cpan/lib/perl5/IPC/Run/Debug.pm cpan/lib/perl5/IPC/Run/Win32Helper.pm cpan/lib/perl5/IPC/Run/Win32Process.pm cpan/lib/perl5/IPC/Run/Timer.pm cpan/lib/perl5/IPC/Run/Win32IO.pm cpan/lib/perl5/IPC/Run/Win32Pump.pm cpan/lib/perl5/IPC/Run.pm: IPC//Run
#cpan/lib/perl5/IPC/ProfArrayBuffer.pm cpan/lib/perl5/IPC/ProfLogReader.pm cpan/lib/perl5/IPC/ProfLogger.pm cpan/lib/perl5/IPC/ProfPP.pm cpan/lib/perl5/IPC/ProfReporter.pm cpan/lib/perl5/IPC/Simple.pm: IPC//Run3
## IPC::Run3 needs to use unlink1 as File::Temp doesn't know about cosmo, so patch it
#cpan/lib/perl5/IPC/Run3.pm: cpan/lib/perl5/IPC/ProfArrayBuffer.pm cpan/lib/perl5/IPC/ProfLogReader.pm cpan/lib/perl5/IPC/ProfLogger.pm cpan/lib/perl5/IPC/ProfPP.pm cpan/lib/perl5/IPC/ProfReporter.pm cpan/lib/perl5/IPC/Simple.pm
#	mv $@ $@.orig
#	cat $@.orig | sed -e 's/tempfile;$/tempfile(UNLINK => 1);/' > $@
#	@touch $@

############################# Previous nobuild apparoch
# TODO: can't use XS like gladiator then, so broken/deprecated until a conditional use of the XS is simple
# need a workflow that doesn't separate xs and non_xs to allow nobuild with noxs missing trivial features
#
# This let you play with PerlPleBean much faster
#fast_nobuild: | com/small_perl.com
#	cp com/small_perl.com perlplebean.com
#	@com/zip.com -r perlplebean.com lib/ bin/ cgi/ html/ tsv/
#	@com/unzip.com -vl perlplebean.com | grep -A9999 bin/zipdetails |grep -v zipdetails || echo "No extra assets found inside perlplebean.com"
#
# Prepare the directory where the binaries will go
#.apperl/user-project.json: 
#	@mkdir -p com/
#	@mkdir -p .apperl
# Ugly and very wrong but avoids a lot of checkout
#	PPB=`pwd` ; echo "{\n   \"nobuild_perl_bin\" : \"$$PPB/com/sxs_perl.com\",\n   \"apperl_output\" : \"$$PPB/.apperl/o\",\n   \"current_apperl\" : \"sxs_perl.com\"\n}" > .apperl/user-project.json

# Get APPerl from lib/perl5/5.36.0/cpan
#CPAN/bin/apperlm: .apperl/user-project.json
#	PPB=`pwd` ; PERL5LIB="$$PPB/cpan/lib/perl5" PERL_MB_OPT="--install_base \"$$PPB/cpan\"" PERL_MM_OPT="INSTALL_BASE=$$PPB/cpan" PERL_LOCAL_LIB_ROOT="$$PPB/cpan" PATH="$$PATH:$$PPB/cpan/bin" ; env |grep perl && cpan install Perl::Dist::APPerl
#	@touch $@
