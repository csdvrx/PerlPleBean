# Forking tests for IPC

## Why is there a problem

If the ape is named perlplebean.com and contains /bin/perlplebean, it will
default to start /bin/perlplebean

This will happen regardless of the arguments, due to a required patch to perl.c

## Why the problem is serious

This is an issue if forking to execute another script while using the same ape
is required: $^X will contain the scriptname, which will execute from /zib/bin
in the fork before anything can be done, potentially causing fork-bomb behavior.

To complicate the issues, if the fork creates a file, the file can't be removed
by the default unlink [used by File::Temp](https://perldoc.perl.org/File::Temp)
[due to the selection of unlink0 by exclusion of some platforms](https://perldoc.perl.org/File::Temp.txt)
for which unlink1 should be preferred:

```
# internal routine to determine whether unlink works on this
# platform for files that are currently open.
# Returns true if we can, false otherwise.

# Currently WinNT, OS/2 and VMS can not unlink an opened file
# On VMS this is because the O_EXCL flag is used to open the
# temporary file. Currently I do not know enough about the issues
# on VMS to decide whether O_EXCL is a requirement.

sub _can_unlink_opened_file {

  if (grep $^O eq $_, qw/MSWin32 os2 VMS dos MacOS haiku/) {
    return 0;
  } else {
    return 1;
  }

}
```

IPC::Run uses files to capture STDOUT, so on top of the fork-bomb behavior there's a file locking problem.

On my Windows 11 test machine a reboot was required, as the processes couldn't be killed with Task Manager or [even group killed in Process Hacker 2](https://github.com/fengjixuchui/ProcessHacker-2) by selecting all the affectec processes.

It's not clear why it happens, but as each process opens a file to capture the STDOUT of the next process before starting it, the cascading dependancy (with new process and files always added) may be larger that the reasonable defaults used in the structures designed to handle such issues.

Changing this list to include cosmo needlessly defaults to unlink1 on Linux, and isn't enough to solve the situation on Windows as explained below.

## The patch to perl.c

https://github.com/G4Vi/perl5/commit/9719db2dfbb19454177a31d8ce874a61f17a30da#diff-f4fcf861484a0d159aeef20b3d0c409a33f3bbad83b1447eae6e4d514878caae

    const char *programname = argv[0];
    const char *slash = strrchr(programname, '/');
    if(slash != NULL)
    {
        programname = slash + 1;
    }
    if(programname[0])
    {
        unsigned namelen = strlen(programname);
        const char *dot = strrchr(programname, '.');
        if(dot != NULL)
        {
            namelen = dot - programname;
        }
        static char name[256];
        snprintf(name, sizeof(name), "/zip/bin/%.*s", namelen, programname);
        struct stat st;
        if((stat(name, &st) == 0) && S_ISREG(st.st_mode))
        {
            scriptname = name;
        }
    }
    if(scriptname == NULL)

## Definitive fix

A definitive fix would require claiming an unused flag (ex: -z) and using that
to override setting scripname=name to set it instead to this argument.

However, to avoid further troubles, it may be better to keep the changes to
perl.com to a bare minimum and explore alternatives.

## Possible workarounds

The easiest one is for the perl payload in /zip/bin matching the ape name to be
aware of this risk, and refuse to fork itself.

This compares 2 approches using fork:
 - one following a regular fork approach: fork.pl
 - another one leveraging a BEGIN block effect on fork: begin.pl

[The effect of a BEGIN block is described in perlfork documentation](https://perldoc.perl.org/perlfork#CAVEATS-AND-LIMITATIONS):
```
The fork() emulation will not work entirely correctly when called from within
a BEGIN block. The forked copy will run the contents of the BEGIN block, but
will not continue parsing the source stream after the BEGIN block
```
With a simple fork (and no exit), begin.pl seem better: the parent can't even
say stop.

With a fork followed by an exit, there isn't any practical difference.

So at first sight, the simple approach from fork.pl may seem better, since we
can avoid the stop from the parent without requiring fork and exit.

However, the approach from begin.pl is both more robust and flexible:
 - more flexible, because except run_in_main which is required by construction,
   all other constraints can be relaxed (no fork and exit,...) while
   maintaining the desired behavior
 - also, if not going past stop is desired, the same behavior can be reached
   by reintroducing the die_in_main constraint
 - but more robust, because by construction, it guarantees the child can't see
   what's after the BEGIN block: this protects from potential future errors

Therefore, from both a risk-assessement and a future flexibility approach,
begin.pl seems more robust:
 - the constraints are not required and could be later relaxed
 - but I will try to use the extra constraints (die_in_child, fork_and_exit)
   for as long as possible, since it seems safer

To limit clutter, begin.pl can also check ARGV to make the BEGIN block
conditional: this is illustrated in ipc-test.pl, the final version.

## Testing ipc-test.pl from WSL2

From WSL2, perlplebean.com is repacked with ipc-test.pl to replace /zip/bin/perlplebean and an extra bin/hello.pl as the test payload:
    
    ./repack.sh ipc-test.pl
    cp hello.pl bin/
    zip -r perlplebean.com bin/hello.pl
    perlplebean.com bin/hello.pl
