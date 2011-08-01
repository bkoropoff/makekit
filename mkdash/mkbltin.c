#include <stdlib.h>
#include <unistd.h>
#ifdef HAVE_ALLOCA_H
#include <alloca.h>
#endif
#include <string.h>
#include <errno.h>
#include <sys/stat.h>

#include "shell.h"
#include "builtins.h"
#include "options.h"
#include "var.h"
#include "error.h"
#include "memalloc.h"
#include "output.h"

static size_t strchrcount(const char* str, char c)
{
    size_t count = 0;
    char* ptr = NULL;

    for (ptr = strchr(str,c);
         ptr;
         count++, ptr = strchr(ptr+1,c));

    return count;
}

static char* copyquoted(char* dst, const char* src)
{
    for (; *src; *(dst++) = *(src++))
    {
        if (*src == '\'')
        {
            *dst++ = '\'';
            *dst++ = '\\';
            *dst++ = '\'';
        }
    }

    return dst;
}

static int setquoted(const char* var, int argc, char** argv)
{
    size_t needed = argc; /* spaces between strings plus NUL */
    int i = 0;
    char* str = NULL;
    char* pos = NULL;

    for (i = 0; i < argc; i++)
    {
        needed += 2 /* start and end quotes */
            + strlen(argv[i]) /* base string size */
            + 3 * strchrcount(argv[i], '\''); /* quote quoting */
    }

#ifdef HAVE_ALLOCA_H
    pos = str = alloca(needed);
#else
    pos = str = ckmalloc(needed);
#endif

    for (i = 0; i < argc; i++)
    {
        *pos++ = '\'';
        pos = copyquoted(pos, argv[i]);
        *pos++ = '\'';
        if (i < argc - 1)
        {
            *pos++ = ' ';
        }
    }

    *pos = '\0';
    
    setvar(var, str, 0);

#ifndef HAVE_ALLOCA_H
    ckfree(str);
#endif

    return 0;
}

int mk_quotecmd(int argc, char** argv)
{
    return setquoted("result", argc - 1, argv + 1);
}

int mk_quote_spacecmd(int argc, char** argv)
{
    size_t needed = argc - 1; /* spaces between strings plus NUL */
    int i = 0;
    int j = 0;
    char* str = NULL;
    char* pos = NULL;

    for (i = 1; i < argc; i++)
    {
        needed += strlen(argv[1]) + strchrcount(argv[1], ' ');
    }

#ifdef HAVE_ALLOCA_H
    pos = str = alloca(needed);
#else
    pos = str = ckmalloc(needed);
#endif

    for (i = 1; i < argc; i++)
    {
        for(j = 0; argv[i][j]; j++)
        {
            if (argv[i][j] == ' ')
                *pos++ = '\\';
            *pos++ = argv[i][j];
        }

        if (i < argc - 1)
        {
            *pos++ = ' ';
        }
    }

    *pos = '\0';

    setvar("result", str, 0);

#ifndef HAVE_ALLOCA_H
    ckfree(str);
#endif

    return 0;
}

int mk_push_varscmd(int argc, char** argv)
{
    int i = 0;

    for (i = 1; i < argc; i++)
    {
        mklocal(argv[i]);
        if (!strchr(argv[i], '='))
        {
            setvar(argv[i], "", 0);
        }
    }

    return 0;
}

static void shiftn(int n)
{
    char** ap1 = NULL;
    char** ap2 = NULL;

	if (n > shellparam.nparam)
		sh_error("can't shift that many");
	INTOFF;
	shellparam.nparam -= n;
	for (ap1 = shellparam.p ; --n >= 0 ; ap1++) {
		if (shellparam.malloc)
			ckfree(*ap1);
	}
	ap2 = shellparam.p;
	while ((*ap2++ = *ap1++) != NULL);
	shellparam.optind = 1;
	shellparam.optoff = -1;
	INTON;
}

int mk_parse_paramscmd(int argc, char** argv)
{
    int i = 0;
    int j = 0;

    for (i = 0; i < shellparam.nparam; i++)
    {
        if (!strcmp(shellparam.p[i], "--"))
        {
            i++;
            break;
        }
        else if (*shellparam.p[i] == '@' && 
                 !strcmp(shellparam.p[i] + strlen(shellparam.p[i]) - 2, "={"))
        {
            for (j = i+1; j < shellparam.nparam; j++)
            {
                if (!strcmp(shellparam.p[j], "}"))
                {
                    shellparam.p[i][strlen(shellparam.p[i]) - 2] = '\0';
                    setquoted(shellparam.p[i] + 1, j - i - 1, shellparam.p + i + 1);
                    shellparam.p[i][strlen(shellparam.p[i]) - 2] = '=';
                    i = j;
                    break;
                }
            }
            if (j == shellparam.nparam)
            {
                sh_error("missing closing }");
            }
        }
        else if (strchr(shellparam.p[i], '='))
        {
            setvareq(shellparam.p[i], 0);
        }
        else
        {
            break;
        }
    }

    shiftn(i);
}
