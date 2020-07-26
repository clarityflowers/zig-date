#ifndef ZIG_2D_DATE_H
#define ZIG_2D_DATE_H

#include <stdint.h>

struct mach_header_64 {
    uint32_t magic;
    int cputype;
    int cpusubtype;
    uint32_t filetype;
    uint32_t ncmds;
    uint32_t sizeofcmds;
    uint32_t flags;
    uint32_t reserved;
};

#ifdef __cplusplus
extern "C" {
#endif


#ifdef __cplusplus
} // extern "C"
#endif

extern struct mach_header_64 _mh_execute_header;

#endif // ZIG_2D_DATE_H
