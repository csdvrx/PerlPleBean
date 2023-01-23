#!/bin/sh

# add App::cpanminus then:
[ -z $1 ] && printf "Usage:\n\t$0 CPAN::Module::You::Dont::Want::Anymore\n" && exit 1

# PATH="$PATH:$PPB/cpan/bin"
PPB=`pwd`
PERL5LIB="$PPB/cpan/lib/perl5"
PERL_MB_OPT="--install_base \"$PPB/cpan\""
PERL_MM_OPT="INSTALL_BASE=$PPB/cpan"
PERL_LOCAL_LIB_ROOT="$PPB/cpan"
cpanm --uninstall $1

