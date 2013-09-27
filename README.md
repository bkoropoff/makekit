MakeKit
=======

MakeKit is a new build system for Linux and UNIX that lets you write build rules in pure POSIX shell script. It can be used as a replacement for automake/autoconf/libtool to build a standalone source project. Multiple interdependent projects can be seamlessly integrated into one build.

Feature Highlights
==================

- **One build script, one language**

  Write your build scripts in plain POSIX shell -- MakeKit will generate a Makefile for you. No m4, no separate files for configure checks and build rules with different syntaxes.
  
- **Simple system requirements**

  MakeKit only requires a standard POSIX environment to run.
  
- **Flexible project structure**

  Use a single flat build file or a hierarchy of snippets split across subdirectories
  
- **Optimized for parallel building**

  MakeKit does a single configuration pass and generates a single global Makefile regardless of how many discrete subprojects are present in your build. This lets you efficiently saturate all your CPU cores with work.
