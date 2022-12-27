# PerlPleBean: Writing CGI as if we're back in the 1990s!

## What?

PerlPleBean lets you write CGI scripts or even raw HTTP responses, then serves the result.

This lets look at the traffic with tcpdump, so you can experiment with HTML responses, to see what works and what doesn't.

But since port 8080 is sooo overdone, PerlPleBean uses port 8765 instead, which might (?) limit the risks of your private experiments finding their way to the great internet?

Actually, no, let's not pretend otherwise: NO IT WON'T. It's just that 8765 is cuter, so I picked it over 8080.

PerlPleBean also serves files and directories.

## Which?

There are different kind of files:

 - "virtual files": the files you upload to the %mem hash by visiting the /mem url are available under /mem/, which is saved to a mem.bin file. So when you stop PerlPleBean to add a handler, you can restart with the same content you uploaded.

 - "embedded files": the single perlplebean.com binary can include any file you want to always be present: they are available under /zip, which represents the embedded zip payload of the binary. Check it with unzip!

 - "local files": which should be none by default, as it could be a security risk. But since I'm playful I'm exposing both the current directory and the root directory.

Hopefully, this default behavior for local files will entice you to edit the sourcecode to remove these glaring security holes if you decide to use perplebean.com!

Anyway, I think you will really want to play with perlplebean.com because there's a small twist: it's all contained into a single binary called perlplebean.com which is multiplatform: it works on Windows, Linux and MacOS!

It also contains it own Makefile so you can recreate it with approximately nothing else: at the moment you still need make and curl, but they will not be needed for long.

This is possible thanks to cosmopolitan + APPerl and of course Perl!

So try to play with perplebean.com!

## How?

Just double click on perplebean.com or start it from a commandline like `./perlplebean.com`

If you want to bake your own PerlPlebean, make sure you have perl (!), wget and make installed, then type: `make && ./perlplebean.com` (in future versions, the Make processing will be embedded, to give a full bootstrapped experience)

You can then go to [http://localhost:8765](http://localhost:8765) or any other public IPv4 or IPv6 that is listed in the output, [drop a file in http://localhost:8765/mem](http://localhost:8765/mem) or use [the included spreadsheet demo](http://localhost:8765/html/interface.template.html): click "demo.stats.tsv" on the top-left to download the file from /tsv, edit it if you want, then click on "Keep" to upload it to %mem and then "Process" to compute some statistics with another perl script: bin/stats.pl. It will cause a refresh and show you some basic statistics concluding that 9 is an outlier in the set {1,1,2,2,4,6,9}, even when 1 is weighted 0.7 in case C.

You can also drag and drop an Excel file (XLSX) into the spreadsheet to do the same: it will be converted to TSV then uploaded to %mem when you click "Keep": you can see a list of the files you can use on top of the screen. The filenames are prefixed by the hours and minutes (by default) or anything you want if you edit the prefix field. Click on the (x) to delete the file from %mem.

The files from bin/ are called by IPC, with the input file fed on STDIN by whatever was uploaded to %meme when you clicked on "Keep". The output file is created on STDOUT, then saved to %mem. A future version will also save the STDERR and may provide a text editor to do more. Actually, a RTF editor would be a nice addition to the spreadsheet :)

For debug or devel, you don't *HAVE* to use perlplebean.com: you can also extract the scripts with `unzip ./perlplebean.com` then run from the extracted directory (containing all the assets like bin/ html/ tsv/) `perl ./bin/perlplebean`

## Why?

I love vintage technology! I love perl! But I never got a chance to really play with CGI scripts.

Recently, [I saw CGIservlet](https://github.com/mdmonk/perl_snippets/blob/master/CGIservlet-1.3.pl) and found its simplicity admirable.

Then I realized that like Jedis make their own lightsabers, an ancient rite of passage for hackers was to write your own webserver!

So I did.

I started from a simple goal: understanding how hard it would be to create a multiplatform electron-like spreadsheet that could also handle files (downloads and uploads).

I hacked together a bunch of things, and it was a lot of fun to do everything by hand!

And I learned a whole lot about HTTP and JS thanks to perlplebean. I hope it can help you too learn interesting things.

I was very happy when I reached the first milestone and could mserve a html+css+js payload on weekend 1: the file emulation to receive (by HTTP POST) and serve (by HTTP GET) files from the %mem hash was all that was needed to make perlplebean quite practical for simple things like sharing files on my lan with just a drag and drop.

I also felt very happy after a Christmas miracle make the JavaScript interface work on weekend 2: having a frontend to run scripts to copy/paste directly into Excel is very handy!

Now I use PerlPleBean to share files on my lan, as a front-end to run perl scripts doing parsing tasks, then to copy paste things into Excel.

## Who?

Since most of the features came premade, I mostly did some minor Ikea-like assembly and:

- the HTTP server part using HTTP::Server::Simple::CGI,

- some glue code and fileupload code in the JavaScript frontend (ugly)

For the interface, the html payload [uses sheetjs to convert files](https://github.com/SheetJS/sheetjs) [then xspreadsheet to visualize](https://github.com/myliang/x-spreadsheet).

Currently, I'm experimenting with [adding sqlitevis](https://github.com/lana-k/sqliteviz) to query the data but this requires handling multiple files (and multiple sheets) better, while I don't know enough JS to do that yet.

Fortunately, the New Year weekend is coming so I'll have some time to learn a little more :)

For the language, perl.com comes from [the APPerl distribution](https://computoid.com/APPerl/) and is inspired by the [MHFS example](https://github.com/G4Vi/MHFS/) from G4Vi who did it.

For the binary format, [the APE polyglot format](https://justine.lol/ape.html) is enabled by [the cosmopolitan libc](https://github.com/jart/cosmopolitan) from the same author, jart.

So most of the thanks should go to:

- myliang, who wrote x-spreadsheet used in the demo,

- lana-k, who wrote sqliteviz also used in the demo,

- G4Vi, who did APPerl

- jart, who did most of the heavy lifting with αcτµαlly pδrταblε εxεcµταblε

I'm the one to blame for the JavaScript.

## JavaScript?

You may not be spooked by JavaScript, but I'm: there are many things I still don't really understand, like when to prefer a FunctionDeclaration over a FunctionExpression. I just know it can sometimes be handy to be able to use a function in the lines above it's declaration.

The language seems super well made, but it's very verbose and dense. Some differences are not easy to understand for beginners. It may be my least favorite language after Python, but hey, the user interface wasn't going to write itself (actually, I could have tried to ask GPT lol)

What may spook you is CGI. But you shouldn't: CGI is a friend. CGI means no harm!

## CGI?

Yes, I know, that's not the best thing to do in 2022.

In the old days, CGI seems to have been the cause of many problems and security holes, so much that now the best practice is to avoid CGI altogether, even [according to the CGI page itself](https://metacpan.org/pod/CGI::Alternatives)

For serious stuff, it may be better to use HTML::Tiny, Mojolicious and Template::Toolkit [as documented](https://metacpan.org/dist/Template-Toolkit/view/lib/Template/Tutorial/Web.pod), if only to avoid manually constructing things like HTTP replies by hand.

But it wouldn't be as fun! And PerlPleBean is not intended as a replacement for Mojolicious!

This is just a weekend project, a learning experience!

Even then, I don't plan to use CGI.pm forever: a future version may either use CGI::Emulate::PSGI or follow the initial plans and move to something like Net::Server::HTTP to better control the forking behavior and the number of clients served.

In either case, I intend to do most of the things myself, because this is the way to learn.

Instead of CGI, maybe I should say IPC?

It would evoke less security fears, while still preserving the core concept: it's just a way to do pipelines easily on the server side, a bit like how electron applications work.

## Security?

I told you how by default, PerlPleBean exposes [your C:\ files on http://localhost:8765///](http://localhost:8765///) and [your C: files on http://localhost:8765//](http://localhost:8765//)

These 2 security holes are there as an incentive, to invite you to edit bin/perlplebean.com to remove them, in the hope you will then want to add your own handlers after seeing how simple it is.

The code isn't very complicated: it's meant to be easy to understand.

Having everything inside one big perl file is a feature: it facilitates playfulness and exploration, as you can more easily understand how the whole thing work and tweak it as needed.

Look at @par to handle parameters: you can pass them as environment variables to your scripts! Isn't that fun?

And you get to create the full HTTP reply, so you see what happens if you tweak or omit something. Have you even tried removing the carriage return? Now you can!

You can also make your own handlers, to isolate that "test". For example, if you want to support a new url like /test, just write a new sub: call it g_test(). Add it to the get handlers hash. Check g_env() or g_slash() if you want skeleton examples to start from.

This is also why unsanitized inputs are processed: it's all done in one memory space, and %mem accepts everything you upload under whatever the name you want before making it available on the /mem/ path.

To give an example on how files can be fed from the commandline, check pipetopost.pl: you can use it like `cat tsv/demo.stats.tsv | perl pipetopost.pl commandline.stats.tsv http://localhost:8765/mem/add.cgi`

After you do that, the file will show up in [http://localhost:8765/mem](http://localhost:8765/mem) and be available for curl at [http://localhost:8765/mem/commandline.stats.tsv](http://localhost:8765/mem/commandline.stats.tsv).

You can then delete it with an unauthenticated GET request to  [http://localhost:8765/mem/delete/commandline.stats.tsv](http://localhost:8765/mem/delete/commandline.stats.tsv) (authentication is coming soon, with Bearer tokens)

And yes, that's not a typo: it's HTTP not HTTPS.

## HTTPS?

By default? Thanks but no thanks!

We're talking about localhost, so I don't see any striking need for security.

Also, it's nice to be able to see what's being sent and what's replied with `tcpdump -i lo -AA -XX -vvv -e -s0 port 8765`

However, there could be an option for https support on non-localhost interfaces, along with the use of Bonjour/DNS-SD to advertise the features on the LAN. Along with authentication, it could make sharing files even better!

## Files?

In the main script, above the post and get handlers hashes, you will see hashes:

- %served_dirs: for the directories you serve assets from (which will be part of the perlplebean.com binary), so /tsv would be a tsv directory visible with `unzip -l perlplebean.com`

- %served_local: for the directories outside perlplebean.com: the convention is to use
 - a double slash if from the same directory as perlplebean.com, so //tsv would be a tsv directory *outside* perlplebean.com
 - a triple slash if from the root directory, so ///tsv would be C:\tsv\ on Windows 

- %served_local_wildcard: if you want to allow everything under a given path. I added there:
 - // to expose everything from the same directory as perlplebean.com, and
 - /// to expose everything at all from your harddrive.

Keeping that one may be a *VERY* bad idea :)

Check [http://localhost:8765///](http://localhost:8765///) if you want some proof.

Templates are also supported, following magic formulas detailed in the %template hash.

## Templates?

If you look at the template hash, you will see BUTTONSTSV when surrounded by a minus and a underscore will be replaced by a blurb of code adding links to these files when they are found in /mem.

This is how the spreadsheet demo integrates new TSV files uploaded to %mem:

```{magic}
   'BUTTONSTSV' => {
    'default' => "(nothing yet)",
    'type' => 'file',
    'file' => {
     'extension' => "tsv",
     'replacement' => "<div class=\"rFile\" id=\"_-file-_\"><input type=\"submit\" value=\"/mem/_-file-_\" textContent=\"_-file-_\" class=\"import\" onclick=\"htmlssheet_loadremote(this.value);\" /><a href=\"/mem/del/_-file-_\" onclick=\"filebutton     ↪_hide(\'_-file-_\');\">x</a></div>",
}
```

For now, it only appends the replacements for each file, replacing the BUTTONTSV magic keyword by div. But hat was mostly to get things working quickly: this behavior could be finetuned, with regex etc.

For now, it's already quite practical to use as simple as it is.

But the best part about PerlPleBean is the "cgi-like" handling: you can have your data parsed by script in /bin, as long as they take their input on STDIN and give you the result on STDOUT! (and I plan to do something cool with STDERR later)

## Huh?

"Your scientists were so preoccupied with whether or not they could, they didn't stop to think if they should!"

This, but seriously.

It may be a very bad idea to run PerlPleBean on a regular server and expose it to the whole internet, since:

1) it's litteraly my very first HTTP server. I had some partial things. I threw them together and did the "shake shake shake"

2) it's a security nightmare on purpose, as I voluntarily expose *by default* (!) not just all the files in the same directory as perlplebean.com binary (!!), but also IN THE ROOT DIRECTORY (!!!), just for the fun of it(!!!!).

Should you run PerlPleBean as root, nothing prevents a malicious user to curl or wget http://localhost/etc/passwd or anything else.

3) anyone can upload any file, and you will share them with everyone! And there's no log yet to say which uploaded what!

And I have absolutely no idea how many genuine security holes PerlPleBean may have, besides these ones I added in the default configuration (and told you to change to stop exposing your files).

## Deps?

It's not exactly a bug, but as of today (December 25, 2022) APPerl doesn't seem support downloading modules dependencies listed like:

         "perl_repo_files" : {"cpan" : [
            "HTTP-Server-Simple-CGI",
            "CGI",
            "HTTP-Date"
         }

If make fails due to apperlm dying, see why with `strace ./cpan/perl5/bin/apperlm build`: it's often due to missing dependancy files: if you add dependencies, you must include their .pm files in the build.

If perl modules are required, the simplest way to include them is to install them from CPAN, but directly into the directory where they're expected to be in by the json file.

This is done with:

```
PPB=`pwd`
PERL5LIB="$PPB/cpan/perl5/lib/perl5"
PERL_MB_OPT="--install_base \"$PPB/cpan/perl5\""
PERL_MM_OPT="INSTALL_BASE=$PPB/cpan/perl5"
PERL_LOCAL_LIB_ROOT="$PPB/cpan/perl5"
cpan install CGI
```

The you can add to the apperl-project.json a line like:

            "__perllib__" : ["cpan/perl5/lib/perl5/CGI.pm"],

For now cpan-add.sh script does the installation step:

        ./cpan-add.sh CGI

Eventually I may add something that would parse the module includes and requires, and update the __perllib__ elements of the apperl-project.json file.

## Limits?

I have no idea how much slower PerlPleBean may be compared to something serious like nginx, it just works.

Premature optimization being the root of all evil, I decided to not care. It can always be improved later!

All text files served from the allowed directories are assumed to be UTF-8, with no verification or transcoding.

So if you are serving text files, [you may get mojibake](https://en.wikipedia.org/wiki/Mojibake)

However:

- it's a choice to limit dependencies: it avoids using Encode::decode which depends on Encode::Detect

- by design, this limitation should have very few consequences:

 - the static payloads (embedded in the APE and accessible through /zip) will have to be enumerated in the apperl-project.json: as part of the make process, you could add a transcoding step
 - most of the useful content should come from %mem, where it's possible to enforce UTF-8 content at the upload step: pipetopost.pl shows how this can be done with Encode::decode
 - this should only be a problem if you decide to expose content from a local directory: but you shouldn't do that for security reasons,
 - if you insist on doing that, it's more likely you will want to serve binary files (zip, jpg, gif, ...) than text files,
 - even for text files, it's unlikely they will be in an encoding that's not UTF-8 (in 2022, 98% of the web content is https://en.wikipedia.org/wiki/UTF-8#Adoption) also since any ASCII file is a valid UTF-8 file thanks to backwards compatibility) 

The %mem hash where files are uploaded to doesn't support directories:

 - this should be relatively easy to fix, either by making a nested HoH (nice) or using boundary prefixes as part of the hash keys (ugly quick hack)

The spreadsheet interface does not support the drag and drop of multiple files as different sheets:

- dragging more than 1 files should at least create 1 sheet per file (or more if the file has more)

- maybe a different format than TSV could be used, like sqlite?

- alternatively, if TSV is still being used, maybe the individual sheets should be stuffed into in %mem under a directory named after the Excel file containing, containing one directory per sheet in numerical order, each containing a TSV file named after each individual sheet? (like /expenses.tsv/1/2022.tsv /expenses.tsv/2/2023.tsv etc)

These last 2 points require:

- a few changes in bin/perlplebean, as the %mem hash should support directories one way or the other

- more changes on the htmlssheet javascript functions handling wb (made of individual sheets), ws (the sheet objects that can be converted to tsv) and the file handlers (for direct selection or drag and drop)

- a lot of experimentation to find what works best, as when it comes to JavaScript I'm like SpongeBob: I have no idea what I'm doing!

## That seems cool!

Good! If you want to throw a penny, maybe I should put my wallet here :)

## That seems bad!

Good! I like to learn and improve! If you want to provide suggestion, help or patches, I'm all ears!

## No, it's an abomination!

[De gustibus non est disputandum](https://en.wikipedia.org/wiki/De_gustibus_non_est_disputandum)

## Why don't you use rust?

Why don't *you*?

Rewriting things in rust in the 2010s *was* edgy. Not anymore.

Writing new things in perl in the 2020s *will* be edgy!

## Or not! Because Perl is DEAD!

[Rumors of perl demise have been greatly exaggerated](https://phoenixtrap.com/2021/10/19/the-reports-of-perls-death-have-been-greatly-exaggerated/)

## It's cute!

Thank you! APE and cosmopolitan made that project a lot of fun!

## It's ugly!

Beauty is in the eye of the beholder.

## Seriously?

Well, yeah!

## I mean it shouldn't even exist!

Too late for this!

## I like your ideas and I wish to subscribe to your newsletter

Send an email to my nickname at outlook.com

## Why for Christmas?

It's a [perl cultural tradition](https://github.com/perladvent/Perl-Advent) and I wanted to do my part.

Merry Christmas and Happy New Year :)
