#ifndef CONFIG_H
#define CONFIG_H

#ifndef _GNU_SOURCE
#define _GNU_SOURCE
#endif

#include "config_gen.h"

#if defined (HAVE_LISTXATTR) && defined (HAVE_SETXATTR) && defined (HAVE_GETXATTR)
#define HAVE_XATTR
#endif

//for now statically define that to one
#define STRERROR_R_CHAR_P 1

#endif
