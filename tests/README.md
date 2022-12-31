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

## Normal results

```{normal}
Parent: child pid is 2330
Parent: child pid 2330 finished
Child: exiting: because arguments to preserve forking safety
Parent: on linux running /usr/bin/perl as ./ipc-test.pl
Parent: passed the Chinese wall, left child behind: 2330
Parent: requesting run of /usr/bin/perl hello.pl 2330
Parent: run: RISK OF FORKBOMB /usr/bin/perl due to previous child pid 2330 matching current child pid 2330
Parent: run: /usr/bin/perl with hello.pl instead of ipc-test.pl from ./ipc-test.pl
Parent: run: CAUTION: /usr/bin/perl hello.pl FINAL
Parent: run: received Hello /usr/bin/perl hello.pl
Parent: run: exiting with 1
```

Let's do it again!

```
# ./ipc-test.pl hello.pl
Parent: child pid is 2391
Parent: child pid 2391 finished
Child: exiting: because arguments to preserve forking safety
Parent: on linux running /usr/bin/perl as ./ipc-test.pl
Parent: passed the Chinese wall, left child behind: 2391
Parent: requesting run of /usr/bin/perl hello.pl 2391
Parent: run: RISK OF FORKBOMB /usr/bin/perl due to previous child pid 2391 matching current child pid 2391
Parent: run: /usr/bin/perl with hello.pl instead of ipc-test.pl from ./ipc-test.pl
Parent: run: CAUTION: /usr/bin/perl hello.pl FINAL
Parent: run: received Hello /usr/bin/perl hello.pl
Parent: run: exiting with 1
```

## In APE mode

From WSL2, perlplebean.com is repacked with ipc-test.pl to replace /zip/bin/perlplebean and an extra bin/hello.pl as the test payload:
    
    ./repack.sh ipc-test.pl
    cp hello.pl bin/
    zip -r perlplebean.com bin/hello.pl
    perlplebean.com bin/hello.pl

```{forkbombing}
$ ./perlplebean.com bin/hello.pl
Parent: child pid is 4
Parent: child pid 4 finished
Child: exiting: because arguments to preserve forking safety
Parent: on cosmo running perlplebean.com as /zip/bin/perlplebean
Parent: passed the Chinese wall, left child behind: 4
Parent: requesting run of perlplebean.com bin/hello.pl 4
Parent: run: RISK OF FORKBOMB perlplebean.com due to previous child pid 4 matching current child pid 4
Cosmo mode detected so prefixing bin/hello.pl with /zip
Parent: run: perlplebean.com with /zip/bin/hello.pl instead of perlplebean from /zip/bin/perlplebean
Parent: run: CAUTION: perlplebean.com bin/hello.pl FINAL
Parent: run: received Child: exiting: because arguments to preserve forking safety
Parent: child pid is 4   <=== HERE
Parent: child pid 4 finished
Parent: on cosmo running ./perlplebean.com as /zip/bin/perlplebean
Parent: passed the Chinese wall, left child behind: 4
Parent: requesting run of ./perlplebean.com bin/hello.pl 4 with output filename FINAL
Cosmo mode detected so prefixing bin/hello.pl with /zip
Parent: run: ./perlplebean.com with /zip/bin/hello.pl instead of perlplebean from /zip/bin/perlplebean
Parent: run: CAUTION: ./perlplebean.com bin/hello.pl FINAL
Parent: run: exiting with 1
Parent: run: exiting with 1
```

As we can see in the line indicated by "HERE", another ipc-test.pl is started instead of using the handcrafted ["$^X", "$ARGV[0]", "$pid"]

### What about strace?

It doesn't help much, as nothing much is shown, even when there are already hundreds of processes slowing the machine to a crawl.

It's possibly due to flushing issues, as even with all the prompt cuteness (PS0 PS1...) removed and when running in a regular /bin/sh, all I get is:

```
$ ./perlplebean.com bin/hello.pl --strace
SYS   3272          1'929'543 bell system five system call support 552 magnums loaded on the new technology
SYS   3272          2'235'144 __morph_begin()
SYS   3272          3'686'431 __morph_end()
```

### Conclusion

So far, despite all the various (and overkill!) precautions taken, it doesn't seem possible to nicely avoid this behavior.

The only possible workaround may be to look at the pid (as 4 is abormally low) with simple semaphore based on the existence of a locking file.

While it may be portable, it doesn't look very nice.

Overall, it may be better to further patch perl.c to hijack unused flags like -z to override the current default behavior:
 - -z to not do anything
 - -z scriptname to use this alternative name
 
However, it may be better to invert this and make instead the current behavior dependant of -z :
 - by default, don't alter scriptname
 - -z alone to alter scriptname to use $0 (like now)
 - -z scriptname to alter scriptname and use this alternative name
