#define SMOOSH 1
#define SMALL 1
#define BSD 1
#define SHELL 1
#define IFS_BROKEN 1
#define _LARGEFILE64_SOURCE 1
#if defined(__linux__)
#define HAVE_ALLOCA_H 1
#define HAVE_PATHS_H 1
#define HAVE_DECL_ISBLANK 1
#define HAVE_DECL_STRTOIMAX 1
#define HAVE_DECL_STRTOUMAX 1
#define HAVE_BSEARCH 1
#define HAVE_FACCESSAT 1
#define HAVE_GETPWNAM 1
#define HAVE_GETRLIMIT 1
#define HAVE_ISALPHA 1
#define HAVE_KILLPG 1
#define HAVE_STPCPY 1
#define HAVE_STRSIGNAL 1
#define HAVE_STRTOD 1
#define HAVE_SYSCONF 1
#define HAVE_DECL_STAT64 0
#elif defined(__FreeBSD__)
#define HAVE_PATHS_H 1
#define HAVE_DECL_ISBLANK 1
#define HAVE_DECL_STRTOIMAX 1
#define HAVE_DECL_STRTOUMAX 1
#define HAVE_BSEARCH 1
#define HAVE_FACCESSAT 1
#define HAVE_GETPWNAM 1
#define HAVE_GETRLIMIT 1
#define HAVE_ISALPHA 1
#define HAVE_KILLPG 1
#define HAVE_STPCPY 1
#define HAVE_STRSIGNAL 1
#define HAVE_STRTOD 1
#define HAVE_SYSCONF 1
#define HAVE_DECL_STAT64 0
#elif defined(__sun)
#define HAVE_DECL_STRTOIMAX 1
#define HAVE_DECL_STRTOUMAX 1
#define HAVE_BSEARCH 1
#define HAVE_FACCESSAT 1
#define HAVE_GETPWNAM 1
#define HAVE_GETRLIMIT 1
#define HAVE_ISALPHA 1
#define HAVE_KILLPG 1
#define HAVE_STPCPY 1
#define HAVE_STRSIGNAL 1
#define HAVE_STRTOD 1
#define HAVE_SYSCONF 1
#define HAVE_DECL_STAT64 0
#include <ctype.h>
#ifdef isblank
#define HAVE_DECL_ISBLANK 1
#else
#define HAVE_DECL_ISBLANK 0
#endif
#else
#error Unsupported platform
#endif

#include <sys/stat.h>
#include <fcntl.h>

#if !HAVE_DECL_STAT64
#define fstat64 fstat
#define lstat64 lstat
#define stat64 stat
#define open64 open
#endif

#ifndef HAVE_PATHS_H
#define _PATH_BSHELL  "/bin/sh"
#define _PATH_DEVNULL "/dev/null"
#define _PATH_TTY     "/dev/tty"
#endif

#include <inttypes.h>
#include <stdlib.h>
