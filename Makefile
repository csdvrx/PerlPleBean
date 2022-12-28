############################# Basics of Makefile rules
# PHONY has dependancies but no rules
.PHONY: all bin/example.fake example.first example.second \
	clean fast fast_nobuild fast_build apes \
	mrproper step1 step2 step3 remake dep

# Other rules use constraint propagation, where each rule is:
#
#target: prerequisite1 prerequisite2:
#	do this and if it worked
#	then do that
#
# The prerequisites are done in order
# The doing syntax *REQUIRES* starting with a tab, and can then use:
#   $$    -> just the dollar sign
#   $@    -> the target
#   $(@D) -> the directory part of $@ (the same D also works on $< etc)
#   $(@F) -> the file part of $@      (the same F also works on $< etc)
#   $<    -> the first prerequisite
#   $^    -> all the deduplicated prerequisites
#   $+    -> all the prerequisites as-is
#
# The first rule is the default one, use this to showcase the syntax first
all: bin/example.fake apes perlplebean.com

# The syntax is showcased with duplicate prerequisites
bin/example.fake: example.first example.second example.first
	@echo "First explaining the syntax with a phony $@ (no such file will be created)"
	@echo "\$$\$$" is the dollar sign: $$
	@echo "\$$@" is the target: $@
	@echo "\$$(@D)" is the directory part of the target: $(@D)
	@echo "\$$(@F)" is the file part of the target: $(@F)
	@echo "\$$<" is the first prerequisite: $<
	@echo "\$$^" is all the deduplicated prerequisites: $^
	@echo "\$$+" is all the prerequisites as-is: $+
	@echo Done explaining the Makefile syntax

# remove the build artefacts, but keep the build output
clean:
	rm -fr .apperl com/* cpan/* perlplebean.com.full

# Just update the payloads using the retained building artifacts
fast: fast_nobuild # fast_build

# This let you play with PerlPleBean much faster
fast_nobuild: src/perl.com
	cp src/perl.com perlplebean.com
#       grep after pl2pm to only show the updated assets
	@com/zip.com -r perlplebean.com lib/ bin/ html/
	@com/unzip.com -l perlplebean.com | grep pm$ |grep -A9999 pl2pm

# FIXME: XS is a WIP, not working yet
fast_build: src/xs_perl.com
	cp src/xs_perl.com perlplebean.com
#       grep after pl2pm to only show the updated assets
	@com/zip.com -r perlplebean.com lib/ bin/ html/
	@com/unzip.com -l perlplebean.com | grep pm$ |grep -A9999 pl2pm

# FIXME: add argument to apperlm build to build a specific apperl_configs from apperl-project.json
# this would allow having both the nobuild and build using different names in apperl-project.json
# without having to edit current_apperl in .apperl/user-project.json
src/xs_perl.com:
	PPB=`pwd` ; PERL5LIB="$$PPB/cpan/perl5/lib/perl5" PERL_MB_OPT="--install_base \"$$PPB/cpan/perl5\"" PERL_MM_OPT="INSTALL_BASE=$$PPB/cpan/perl5" PERL_LOCAL_LIB_ROOT="$$PPB/cpan/perl5" PATH="$$PATH:$$PPB/cpan/perl5/bin" ; env |grep perl
	apperlm build

############################# APE binaries
# FIXME: replace wget by a perl script until openssl is aped which will provide curl.com
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

# FIXME: add grep.com
redbeans=zip.com unzip.com assimilate.com blackholed.com sqlite3.com
redbean_site=https://redbean.dev
perl_git_url=https://github.com/G4Vi/Perl-Dist-APPerl/releases/download/v0.2.1/perl.com

apes: com/perl.com $(redbeans:%=com/%)
	@echo $+

# Get perl.com from github, check new releases on https://github.com/G4Vi/Perl-Dist-APPerl/releases/
com/perl.com:
	@wget $(perl_git_url) -O $(@D)/perl.com
	@touch  $@

# Get other binaries from redbean.dev
com/%:
	wget -O com/$(@F) $(redbean_site)/$(@F)
	@touch  $@

############################# PerlPleBean
# FIXME: replace cpan by perl.com cpan.pl
# FIXME: replace make by perl.com make.pl fatpacked with a pure perl make https://metacpan.org/pod/Make

# Just refresh the assets if the json file is unchanged, then give a visual confirmation of what's inside the .com
perlplebean.com: perlplebean.com.full bin/perlplebean html/css/xspreadsheet.css html/interface.template.html html/js/glue.sheetjs.xspreadsheet.js html/js/sheetjs.shim.min.js html/js/sheetjs.xlsx.full.min.js html/js/xspreadsheet.js html/svg/xspreadsheet.svg
	cp perlplebean.com.full perlplebean.com
#       grep after pl2pm to only show the updated assets
	com/zip.com -r perlplebean.com lib/ bin/ html/
	com/unzip.com -l perlplebean.com | grep pm$ |grep -A9999 pl2pm
#       FIXME: could add something to only print this if we didn't just make perplebean.com.full
	@echo "This last step only refreshed the assets of $@ using the $< made before"

############################# old nobuild approach

.apperl/user-project.json: com/perl.com
	mkdir -p .apperl
	PPB=`pwd` ; echo "{\n   \"nobuild_perl_bin\" : \"$$PPB/com/perl.com\",\n   \"apperl_output\" : \"$$PPB/.apperl/o\",\n   \"current_apperl\" : \"PerlPleBean\"\n}" > .apperl/user-project.json

cpan/perl5/bin/apperlm: .apperl/user-project.json
	PPB=`pwd` ; PERL5LIB="$$PPB/cpan/perl5/lib/perl5" PERL_MB_OPT="--install_base \"$$PPB/cpan/perl5\"" PERL_MM_OPT="INSTALL_BASE=$$PPB/cpan/perl5" PERL_LOCAL_LIB_ROOT="$$PPB/cpan/perl5" PATH="$$PATH:$$PPB/cpan/perl5/bin" ; env |grep perl && cpan install Perl::Dist::APPerl
	touch $@

# Fully rebuild the APE container using ./com/perl.com and ./apperl-project.json
perlplebean.com.full: com/perl.com cpan/perl5/bin/apperlm .apperl/user-project.json apperl-project.json \
        cpan/perl5/lib/perl5/CGI.pm cpan/perl5/lib/perl5/CGI/Carp.pm cpan/perl5/lib/perl5/CGI/Cookie.pm cpan/perl5/lib/perl5/CGI/Pretty.pm cpan/perl5/lib/perl5/CGI/Push.pm cpan/perl5/lib/perl5/CGI/Util.pm cpan/perl5/lib/perl5/CGI/File/Temp.pm cpan/perl5/lib/perl5/CGI/HTML/Functions.pm cpan/perl5/lib/perl5/HTML/HTML5/Entities.pm cpan/perl5/lib/perl5/IPC/Run/IO.pm cpan/perl5/lib/perl5/IPC/Run/Debug.pm cpan/perl5/lib/perl5/IPC/Run/Win32Helper.pm cpan/perl5/lib/perl5/IPC/Run/Win32Process.pm cpan/perl5/lib/perl5/IPC/Run/Timer.pm cpan/perl5/lib/perl5/IPC/Run/Win32IO.pm cpan/perl5/lib/perl5/IPC/Run/Win32Pump.pm cpan/perl5/lib/perl5/IPC/Run.pm cpan/perl5/lib/perl5/MIME/Decoder/Base64.pm cpan/perl5/lib/perl5/MIME/Types.pm cpan/perl5/lib/perl5/MIME/Type.pm cpan/perl5/lib/perl5/MIME/types.db cpan/perl5/lib/perl5/Statistics/Descriptive.pm cpan/perl5/lib/perl5/Statistics/Descriptive/Full.pm cpan/perl5/lib/perl5/Statistics/Descriptive/Sparse.pm cpan/perl5/lib/perl5/Statistics/Descriptive/Weighted.pm cpan/perl5/lib/perl5/Statistics/Descriptive/Smoother/Exponential.pm cpan/perl5/lib/perl5/Statistics/Descriptive/Smoother/Weightedexponential.pm
	PPB=`pwd` ; PERL5LIB="$$PPB/cpan/perl5/lib/perl5" PERL_MB_OPT="--install_base \"$$PPB/cpan/perl5\"" PERL_MM_OPT="INSTALL_BASE=$$PPB/cpan/perl5" PERL_LOCAL_LIB_ROOT="$$PPB/cpan/perl5" PATH="$$PATH:$$PPB/cpan/perl5/bin" cpan/perl5/bin/apperlm build
	cp perlplebean.com perlplebean.com.full
	touch $@
#       grep after pl2pm to only show the updated assets
	com/unzip.com -l perlplebean.com | grep pm$ |grep -A9999 pl2pm

############################# new approach building perl to link some XS modules
# Step 0: rm -fr ~/.config/apperl/site.json ~/.local/share/apperl # clean to avoid problems
# Step 1: apperlm install-build-deps # download perl5 fork and cosmopolitan source, save config to ~/.config/apperl/site.json
# Step 2: apperlm checkout PerlPleBean # use apperl-project.json to copy things to perl, reset git head, build cosmopolitan
# Step 3: apperlm build # currently problem with the makefile, wip
#.apperl/user-project.json:
#	PPB=`pwd` ; PERL5LIB="$$PPB/cpan/perl5/lib/perl5" PERL_MB_OPT="--install_base \"$$PPB/cpan/perl5\"" PERL_MM_OPT="INSTALL_BASE=$$PPB/cpan/perl5" PERL_LOCAL_LIB_ROOT="$$PPB/cpan/perl5" PATH="$$PATH:$$PPB/cpan/perl5/bin" ; env |grep perl && cpan install Perl::Dist::APPerl
#	apperlm install-build-deps
#	apperlm checkout PerlPleBean

mrproper:
	rm -fr ~/.config/apperl/site.json ~/.local/share/apperl

step1:
	apperlm install-build-deps

step2: step1
	apperlm checkout PerlPleBean

step3: step2 step1
	apperlm build

# blind remake, forced by a mrproper
remake: mrproper step3

############################# Depedencies: cpan modules

# Core modules that are not present in perl.com must be included.
# For now, apperl-project.json directly uses:
#  - some pm files from /usr/share/perl5/
#  - some pm files from ./cpan
#  and this Makefile tries to handle the latter
# FIXME: automate this by extracting the modules from the json, and the .pm files from the matching directories in ./cpan/
#  - output is cpan install the module in ./cpan, which could use the json
#dep: $(grep pm apperl-project.json  | sed -e 's/.*\[//g' -e 's/].*//g' |sed -e 's/\",//g' -e 's/\"//g' -e 's/^\s\+//g'|grep ^cpan)
#  - input would be the pm files found in this module, which would requite getting and exploring the source of the module
# If we don't want to separate system vs cpan in the json file, we could copy the system files into the cpan directory like:
#perl5/HTTP/Date.pm:
#	mkdir -p cpan/perl5/lib/perl5/HTTP 
#	cp /usr/share/perl5/HTTP/Date.pm cpan/perl5/lib/perl5/HTTP/Date.pm
# An alternative would to be to force the install of these modules with cpan install -f
# However, APPerl should eventually handles cpan dependencies!

# For now, just list the things unique to ./cpan/

# CGI.pm depends on HTML::Entities, which is better provided by HTML::HTML5::Entities
cpan/perl5/lib/perl5/CGI.pm: cpan/perl5/lib/perl5/HTML/HTML5/Entities.pm cpan/perl5/lib/perl5/CGI/Carp.pm
	#patch -p0 --forward < CGI.pm.patch
	mv cpan/perl5/lib/perl5/CGI.pm cpan/perl5/lib/perl5/CGI.pm.orig
	cat cpan/perl5/lib/perl5/CGI.pm.orig | sed -e 's/HTML::Entities/HTML::HTML5::Entities/g' > cpan/perl5/lib/perl5/CGI.pm
	touch $@
cpan/perl5/lib/perl5/CGI/Carp.pm cpan/perl5/lib/perl5/CGI/Cookie.pm cpan/perl5/lib/perl5/CGI/Pretty.pm cpan/perl5/lib/perl5/CGI/Push.pm cpan/perl5/lib/perl5/CGI/Util.pm cpan/perl5/lib/perl5/CGI/File/Temp.pm cpan/perl5/lib/perl5/CGI/HTML/Functions.pm:
	PPB=`pwd` ; PERL5LIB="$$PPB/cpan/perl5/lib/perl5" PERL_MB_OPT="--install_base \"$$PPB/cpan/perl5\"" PERL_MM_OPT="INSTALL_BASE=$$PPB/cpan/perl5" PERL_LOCAL_LIB_ROOT="$$PPB/cpan/perl5" PATH="$$PATH:$$PPB/cpan/perl5/bin" ; env |grep perl && cpan install CGI
	touch $@

# Everything else is much simpler: input is the pm files found in this module, output is cpan install the module in ./cpan
cpan/perl5/lib/perl5/HTML/HTML5/Entities.pm:
	PPB=`pwd` ; PERL5LIB="$$PPB/cpan/perl5/lib/perl5" PERL_MB_OPT="--install_base \"$$PPB/cpan/perl5\"" PERL_MM_OPT="INSTALL_BASE=$$PPB/cpan/perl5" PERL_LOCAL_LIB_ROOT="$$PPB/cpan/perl5" PATH="$$PATH:$$PPB/cpan/perl5/bin" ; env |grep perl && cpan install HTML::HTML5::Entities
	touch $@

cpan/perl5/lib/perl5/IPC/Run/IO.pm cpan/perl5/lib/perl5/IPC/Run/Debug.pm cpan/perl5/lib/perl5/IPC/Run/Win32Helper.pm cpan/perl5/lib/perl5/IPC/Run/Win32Process.pm cpan/perl5/lib/perl5/IPC/Run/Timer.pm cpan/perl5/lib/perl5/IPC/Run/Win32IO.pm cpan/perl5/lib/perl5/IPC/Run/Win32Pump.pm cpan/perl5/lib/perl5/IPC/Run.pm:
	PPB=`pwd` ; PERL5LIB="$$PPB/cpan/perl5/lib/perl5" PERL_MB_OPT="--install_base \"$$PPB/cpan/perl5\"" PERL_MM_OPT="INSTALL_BASE=$$PPB/cpan/perl5" PERL_LOCAL_LIB_ROOT="$$PPB/cpan/perl5" PATH="$$PATH:$$PPB/cpan/perl5/bin" ; env |grep perl && cpan install IPC::Run
	touch $@

cpan/perl5/lib/perl5/MIME/Types.pm cpan/perl5/lib/perl5/MIME/Type.pm cpan/perl5/lib/perl5/MIME/types.db:
	PPB=`pwd` ; PERL5LIB="$$PPB/cpan/perl5/lib/perl5" PERL_MB_OPT="--install_base \"$$PPB/cpan/perl5\"" PERL_MM_OPT="INSTALL_BASE=$$PPB/cpan/perl5" PERL_LOCAL_LIB_ROOT="$$PPB/cpan/perl5" PATH="$$PATH:$$PPB/cpan/perl5/bin" ; env |grep perl && cpan install MIME::Types
	touch $@

cpan/perl5/lib/perl5/MIME/Decoder/Base64.pm:
	PPB=`pwd` ; PERL5LIB="$$PPB/cpan/perl5/lib/perl5" PERL_MB_OPT="--install_base \"$$PPB/cpan/perl5\"" PERL_MM_OPT="INSTALL_BASE=$$PPB/cpan/perl5" PERL_LOCAL_LIB_ROOT="$$PPB/cpan/perl5" PATH="$$PATH:$$PPB/cpan/perl5/bin" ; env |grep perl && cpan install MIME::Decoder
	touch $@

cpan/perl5/lib/perl5/Statistics/Descriptive.pm cpan/perl5/lib/perl5/Statistics/Descriptive/Full.pm cpan/perl5/lib/perl5/Statistics/Descriptive/Sparse.pm:
	PPB=`pwd` ; PERL5LIB="$$PPB/cpan/perl5/lib/perl5" PERL_MB_OPT="--install_base \"$$PPB/cpan/perl5\"" PERL_MM_OPT="INSTALL_BASE=$$PPB/cpan/perl5" PERL_LOCAL_LIB_ROOT="$$PPB/cpan/perl5" PATH="$$PATH:$$PPB/cpan/perl5/bin" ; env |grep perl && cpan install Statistics::Descriptive
	touch $@

cpan/perl5/lib/perl5/Statistics/Descriptive/Smoother/Exponential.pm cpan/perl4/lib/perl5/Statistics/Descriptive/Smoother/Weightedexponential.pm:
	PPB=`pwd` ; PERL5LIB="$$PPB/cpan/perl5/lib/perl5" PERL_MB_OPT="--install_base \"$$PPB/cpan/perl5\"" PERL_MM_OPT="INSTALL_BASE=$$PPB/cpan/perl5" PERL_LOCAL_LIB_ROOT="$$PPB/cpan/perl5" PATH="$$PATH:$$PPB/cpan/perl5/bin" ; env |grep perl && cpan install Statistics::Descriptive::Smoother
	touch $@

cpan/perl5/lib/perl5/Statistics/Descriptive/Weighted.pm:
	PPB=`pwd` ; PERL5LIB="$$PPB/cpan/perl5/lib/perl5" PERL_MB_OPT="--install_base \"$$PPB/cpan/perl5\"" PERL_MM_OPT="INSTALL_BASE=$$PPB/cpan/perl5" PERL_LOCAL_LIB_ROOT="$$PPB/cpan/perl5" PATH="$$PATH:$$PPB/cpan/perl5/bin" ; env |grep perl && cpan install Statistics::Descriptive::Weighted
	touch $@
