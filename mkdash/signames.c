#include <signal.h>

const char *const signal_names[] = {
    [0] = "EXIT",
#ifdef SIGHUP
    [SIGHUP] = "HUP",
#endif
#ifdef SIGINT
    [SIGINT] = "INT",
#endif
#ifdef SIGQUIT
    [SIGQUIT] = "QUIT",
#endif
#ifdef SIGILL
    [SIGILL] = "ILL",
#endif
#ifdef SIGTRAP
    [SIGTRAP] = "TRAP",
#endif
#ifdef SIGABRT
    [SIGABRT] = "ABRT",
#endif
#ifdef SIGBUS
    [SIGBUS] = "BUS",
#endif
#ifdef SIGFPE
    [SIGFPE] = "FPE",
#endif
#ifdef SIGKILL
    [SIGKILL] = "KILL",
#endif
#ifdef SIGUSR1
    [SIGUSR1] = "USR1",
#endif
#ifdef SIGSEGV
    [SIGSEGV] = "SEGV",
#endif
#ifdef SIGUSR2
    [SIGUSR2] = "USR2",
#endif
#ifdef SIGPIPE
    [SIGPIPE] = "PIPE",
#endif
#ifdef SIGALRM
    [SIGALRM] = "ALRM",
#endif
#ifdef SIGTERM
    [SIGTERM] = "TERM",
#endif
#ifdef SIGCHLD
    [SIGCHLD] = "CHLD",
#endif
#ifdef SIGCONT
    [SIGCONT] = "CONT",
#endif
#ifdef SIGSTOP
    [SIGSTOP] = "STOP",
#endif
#ifdef SIGTSTP
    [SIGTSTP] = "TSTP",
#endif
#ifdef SIGTTIN
    [SIGTTIN] = "TTIN",
#endif
#ifdef SIGTTOU
    [SIGTTOU] = "TTOU",
#endif
#ifdef SIGURG
    [SIGURG] = "URG",
#endif
#ifdef SIGXCPU
    [SIGXCPU] = "XCPU",
#endif
#ifdef SIGXFSZ
    [SIGXFSZ] = "XFSZ",
#endif
#ifdef SIGVTALRM
    [SIGVTALRM] = "VTALRM",
#endif
#ifdef SIGPROF
    [SIGPROF] = "PROF",
#endif
#ifdef SIGWINCH
    [SIGWINCH] = "WINCH",
#endif
#ifdef SIGIO
    [SIGIO] = "IO",
#endif
#ifdef SIGPWR
    [SIGPWR] = "PWR",
#endif
#ifdef SIGSYS
    [SIGSYS] = "SYS",
#endif
    (char *)0x0
};
