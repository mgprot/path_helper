path_helper.pl
==============

This script is a replacement for the /usr/libexec/path_helper program provided
by Apple in OS-X 10.5 and above.

The reason for writing this script is simple, Apple's attempt is just too limited!

Apple's version restricts all path specifications to files located in /etc.

The is useless for personal use and flies directly in the face of Apples
otherwise stringent organisation of configuration files in:

    /System/Library
    /Library
    ~/Library

In fact, one could argue that a similar effect could be achieved by a single,
short line of perl, such as this:

    perl -ne 'chomp;push(@p,$_);END{printf"%s\n",join(":",@p)}' /etc/paths /etc/paths.d/* /etc/manpaths /etc/manpaths.d/*

This version doesn't go so far as to use the typical Library structure,
however, it does allow you to provide any number of personal path
specifications anywhere on your filesystem. As a bonus, it also includes the
/etc files automatically as well.

For more documentation, see the man page in the perl script. You can view it with a command such as:

pod2man path_helper.pl | nroff -man | less

Copyright
=========

Permission is granted to use, redistribute and modify this script in any way you like.
The inclusion of the original copyright and authorship details would be appreciated.

(C) Stephen Riehm, 2009-10-25
