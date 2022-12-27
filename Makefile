all: perlplebean.com

.PHONY: all clean refresh

# remove the build artefacts, but keep the build output
clean:
	rm -fr .apperl src/perl.com cpan/ lib/ perlplebean.com.full dep

# Core modules that are not present in perl.com must be included.
# We could copy the system files into the cpan directory like:
#perl5/HTTP/Date.pm:
#	mkdir -p cpan/perl5/lib/perl5/HTTP 
#	cp /usr/share/perl5/HTTP/Date.pm cpan/perl5/lib/perl5/HTTP/Date.pm
# An alternative would to be to force the install of these modules with cpan install -f
# However, APPerl should eventually handles cpan dependencies!

# For now, apperl-project.json directly uses their pm files from /usr/share/perl5/
# and this Makefile tries to handle the dependancies (TODO: still, automate this)
#dep: $(grep pm apperl-project.json  | sed -e 's/.*\[//g' -e 's/].*//g' |sed -e 's/\",//g' -e 's/\"//g' -e 's/^\s\+//g'|grep ^cpan)
dep: cpan/perl5/lib/perl5/CGI.pm cpan/perl5/lib/perl5/CGI/Carp.pm cpan/perl5/lib/perl5/CGI/Cookie.pm cpan/perl5/lib/perl5/CGI/Pretty.pm cpan/perl5/lib/perl5/CGI/Push.pm cpan/perl5/lib/perl5/CGI/Util.pm cpan/perl5/lib/perl5/CGI/File/Temp.pm cpan/perl5/lib/perl5/CGI/HTML/Functions.pm cpan/perl5/lib/perl5/HTML/HTML5/Entities.pm cpan/perl5/lib/perl5/IPC/Run/IO.pm cpan/perl5/lib/perl5/IPC/Run/Debug.pm cpan/perl5/lib/perl5/IPC/Run/Win32Helper.pm cpan/perl5/lib/perl5/IPC/Run/Win32Process.pm cpan/perl5/lib/perl5/IPC/Run/Timer.pm cpan/perl5/lib/perl5/IPC/Run/Win32IO.pm cpan/perl5/lib/perl5/IPC/Run/Win32Pump.pm cpan/perl5/lib/perl5/IPC/Run.pm cpan/perl5/lib/perl5/MIME/Types.pm cpan/perl5/lib/perl5/MIME/Type.pm cpan/perl5/lib/perl5/MIME/types.db cpan/perl5/lib/perl5/Statistics/Descriptive.pm cpan/perl5/lib/perl5/Statistics/Descriptive/Full.pm cpan/perl5/lib/perl5/Statistics/Descriptive/Sparse.pm cpan/perl5/lib/perl5/Statistics/Descriptive/Weighted.pm cpan/perl5/lib/perl5/Statistics/Descriptive/Smoother/Exponential.pm cpan/perl5/lib/perl5/Statistics/Descriptive/Smoother/Weightedexponential.pm

# Just refresh the assets if the json file is unchanged, then give a visual confirmation of what's inside the .com
perlplebean.com: perlplebean.com.full bin/perlplebean html/css/xspreadsheet.css html/interface.template.html html/js/glue.sheetjs.xspreadsheet.js html/js/sheetjs.shim.min.js html/js/sheetjs.xlsx.full.min.js html/js/xspreadsheet.js html/svg/xspreadsheet.svg
	zip -r perlplebean.com lib/ bin/ html/ && unzip -l perlplebean.com | grep pm$ |grep -A9999 pl2pm

bin/perlplebean html/css/xspreadsheet.css html/interface.template.html html/js/glue.sheetjs.xspreadsheet.js html/js/sheetjs.shim.min.js html/js/sheetjs.xlsx.full.min.js html/js/xspreadsheet.js html/svg/xspreadsheet.svg apperl-project.json:

# Fully rebuild the APE container using ./src/perl.com and ./apperl-project.json then touch dep to mark the dependencies as completed
perlplebean.com.full: src/perl.com cpan/perl5/bin/apperlm .apperl/user-project.json apperl-project.json dep
	PPB=`pwd` ; PERL5LIB="$$PPB/cpan/perl5/lib/perl5" PERL_MB_OPT="--install_base \"$$PPB/cpan/perl5\"" PERL_MM_OPT="INSTALL_BASE=$$PPB/cpan/perl5" PERL_LOCAL_LIB_ROOT="$$PPB/cpan/perl5" PATH="$$PATH:$$PPB/cpan/perl5/bin" ./cpan/perl5/bin/apperlm build && cp perlplebean.com perlplebean.com.full && touch dep && unzip -l perlplebean.com | grep pm$ |grep -A9999 pl2pm

# Check new versions on https://github.com/G4Vi/Perl-Dist-APPerl/releases/
src/perl.com:
	wget https://github.com/G4Vi/Perl-Dist-APPerl/releases/download/v0.2.1/perl.com -O src/perl.com

cpan/perl5/bin/apperlm: .apperl/user-project.json
	PPB=`pwd` ; PERL5LIB="$$PPB/cpan/perl5/lib/perl5" PERL_MB_OPT="--install_base \"$$PPB/cpan/perl5\"" PERL_MM_OPT="INSTALL_BASE=$$PPB/cpan/perl5" PERL_LOCAL_LIB_ROOT="$$PPB/cpan/perl5" PATH="$$PATH:$$PPB/cpan/perl5/bin" ; env |grep perl ; cpan install Perl::Dist::APPerl
# ; apperlm install-build-deps

.apperl/user-project.json: src/perl.com
	mkdir -p .apperl
	PPB=`pwd` ; echo "{\n   \"nobuild_perl_bin\" : \"$$PPB/src/perl.com\",\n   \"apperl_output\" : \"$$PPB/.apperl/o\",\n   \"current_apperl\" : \"PerlPleBean\"\n}" > .apperl/user-project.json

cpan/perl5/lib/perl5/CGI/Carp.pm cpan/perl5/lib/perl5/CGI/Cookie.pm cpan/perl5/lib/perl5/CGI/Pretty.pm cpan/perl5/lib/perl5/CGI/Push.pm cpan/perl5/lib/perl5/CGI/Util.pm cpan/perl5/lib/perl5/CGI/File/Temp.pm cpan/perl5/lib/perl5/CGI/HTML/Functions.pm:
	PPB=`pwd` ; PERL5LIB="$$PPB/cpan/perl5/lib/perl5" PERL_MB_OPT="--install_base \"$$PPB/cpan/perl5\"" PERL_MM_OPT="INSTALL_BASE=$$PPB/cpan/perl5" PERL_LOCAL_LIB_ROOT="$$PPB/cpan/perl5" PATH="$$PATH:$$PPB/cpan/perl5/bin" ; env |grep perl ; cpan install CGI
	touch $@

# CGI.pm depends on HTML::Entities, which is better provided by HTML::HTML5::Entities
cpan/perl5/lib/perl5/CGI.pm: cpan/perl5/lib/perl5/HTML/HTML5/Entities.pm cpan/perl5/lib/perl5/CGI/Carp.pm
	#patch -p0 --forward < CGI.pm.patch
	mv cpan/perl5/lib/perl5/CGI.pm cpan/perl5/lib/perl5/CGI.pm.orig
	cat cpan/perl5/lib/perl5/CGI.pm.orig | sed -e 's/HTML::Entities/HTML::HTML5::Entities/g' > cpan/perl5/lib/perl5/CGI.pm
	touch $@

cpan/perl5/lib/perl5/HTML/HTML5/Entities.pm:
	PPB=`pwd` ; PERL5LIB="$$PPB/cpan/perl5/lib/perl5" PERL_MB_OPT="--install_base \"$$PPB/cpan/perl5\"" PERL_MM_OPT="INSTALL_BASE=$$PPB/cpan/perl5" PERL_LOCAL_LIB_ROOT="$$PPB/cpan/perl5" PATH="$$PATH:$$PPB/cpan/perl5/bin" ; env |grep perl ; cpan install HTML::HTML5::Entities
	touch $@

cpan/perl5/lib/perl5/IPC/Run/IO.pm cpan/perl5/lib/perl5/IPC/Run/Debug.pm cpan/perl5/lib/perl5/IPC/Run/Win32Helper.pm cpan/perl5/lib/perl5/IPC/Run/Win32Process.pm cpan/perl5/lib/perl5/IPC/Run/Timer.pm cpan/perl5/lib/perl5/IPC/Run/Win32IO.pm cpan/perl5/lib/perl5/IPC/Run/Win32Pump.pm cpan/perl5/lib/perl5/IPC/Run.pm:
	PPB=`pwd` ; PERL5LIB="$$PPB/cpan/perl5/lib/perl5" PERL_MB_OPT="--install_base \"$$PPB/cpan/perl5\"" PERL_MM_OPT="INSTALL_BASE=$$PPB/cpan/perl5" PERL_LOCAL_LIB_ROOT="$$PPB/cpan/perl5" PATH="$$PATH:$$PPB/cpan/perl5/bin" ; env |grep perl ; cpan install IPC::Run
	touch $@

cpan/perl5/lib/perl5/MIME/Types.pm cpan/perl5/lib/perl5/MIME/Type.pm cpan/perl5/lib/perl5/MIME/types.db:
	PPB=`pwd` ; PERL5LIB="$$PPB/cpan/perl5/lib/perl5" PERL_MB_OPT="--install_base \"$$PPB/cpan/perl5\"" PERL_MM_OPT="INSTALL_BASE=$$PPB/cpan/perl5" PERL_LOCAL_LIB_ROOT="$$PPB/cpan/perl5" PATH="$$PATH:$$PPB/cpan/perl5/bin" ; env |grep perl ; cpan install MIME::Types
	touch $@

cpan/perl5/lib/perl5/Statistics/Descriptive.pm cpan/perl5/lib/perl5/Statistics/Descriptive/Full.pm cpan/perl5/lib/perl5/Statistics/Descriptive/Sparse.pm cpan/perl5/lib/perl5/Statistics/Descriptive/Smoother/Exponential.pm cpan/perl5/lib/perl5/Statistics/Descriptive/Smoother/Weightedexponential.pm:
	PPB=`pwd` ; PERL5LIB="$$PPB/cpan/perl5/lib/perl5" PERL_MB_OPT="--install_base \"$$PPB/cpan/perl5\"" PERL_MM_OPT="INSTALL_BASE=$$PPB/cpan/perl5" PERL_LOCAL_LIB_ROOT="$$PPB/cpan/perl5" PATH="$$PATH:$$PPB/cpan/perl5/bin" ; env |grep perl ; cpan install Statistics::Descriptive::Smoother
	touch $@

cpan/perl5/lib/perl5/Statistics/Descriptive/Weighted.pm:
	PPB=`pwd` ; PERL5LIB="$$PPB/cpan/perl5/lib/perl5" PERL_MB_OPT="--install_base \"$$PPB/cpan/perl5\"" PERL_MM_OPT="INSTALL_BASE=$$PPB/cpan/perl5" PERL_LOCAL_LIB_ROOT="$$PPB/cpan/perl5" PATH="$$PATH:$$PPB/cpan/perl5/bin" ; env |grep perl ; cpan install Statistics::Descriptive::Weighted
	touch $@
