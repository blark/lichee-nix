/* Freestanding i386 probe for the 32-bit directory-cookie narrowing.
 *
 * Raw int $0x80 only, no libc, so the same binary runs natively and under a
 * translator and nothing from a guest rootfs is involved.
 *
 * glibc's 32-bit readdir() converts the kernel's linux_dirent64 into a 32-bit
 * struct dirent and range-checks BOTH d_ino and d_off. One value that does not
 * fit fails the WHOLE call with EOVERFLOW and the caller sees an empty
 * directory. A real i386 kernel never triggers that: ext4 tests is_32bit_api()
 * and hands 32-bit tasks a narrowed cookie. A 64-bit translator process is not
 * a 32-bit task, so it gets the full 64-bit cookie and passes it to a guest
 * whose libc refuses it.
 *
 * Exits 0 when every entry would survive that conversion, 1 when any would not.
 */
typedef unsigned long long u64; typedef long long s64;
typedef unsigned short u16; typedef unsigned char u8;

static int sys3(int n, int a, int b, int c)
{ int r; __asm__ volatile("int $0x80":"=a"(r):"a"(n),"b"(a),"c"(b),"d"(c):"memory"); return r; }
static int slen(const char* s){ int n=0; while(s[n]) n++; return n; }
static void ws(const char* s){ sys3(4, 1, (int)s, slen(s)); }
static void wx(u64 v){ char b[19]; int i=18; b[i--]=0; if(!v) b[i--]='0';
    while(v){ int d=(int)(v & 0xf); b[i--]= d<10 ? '0'+d : 'a'+d-10; v >>= 4; }
    ws("0x"); ws(b+i+1); }

struct d64 { u64 ino; s64 off; u16 reclen; u8 type; char name[]; };

/* The kernel hands _start a bare stack: argc, then argv[]. Capture ESP before
   the compiler can touch it, then hand it to C. */
void cmain(int* sp) __attribute__((noreturn, used));
__asm__(".globl _start\n_start:\n mov %esp,%eax\n and $-16,%esp\n push %eax\n call cmain\n");

void cmain(int* sp)
{
    int argc = sp[0];
    char** argv = (char**)(sp + 1);
    const char* path = (argc > 1) ? argv[1] : ".";

    static char buf[32768];
    int fd = sys3(5, (int)path, 0 /*O_RDONLY*/, 0);
    if(fd < 0) { ws("FAIL: cannot open the directory\n"); sys3(1, 2, 0, 0); }

    int total = 0, inoover = 0, offover = 0;
    for(;;) {
        int n = sys3(220 /*getdents64*/, fd, (int)buf, sizeof(buf));
        if(n < 0) { ws("FAIL: getdents64 returned an error\n"); sys3(1, 2, 0, 0); }
        if(n == 0) break;
        for(int p = 0; p < n; ) {
            struct d64* d = (struct d64*)(buf + p);
            if(d->reclen < 24) break;          /* cannot come from Linux */
            if(d->ino > 0xffffffffULL) inoover++;
            if(d->off != (s64)(int)d->off) offover++;
            total++;
            p += d->reclen;
        }
    }
    sys3(6, fd, 0, 0);

    ws("entries="); wx((u64)(unsigned)total);
    ws(" ino_over32="); wx((u64)(unsigned)inoover);
    ws(" off_over32="); wx((u64)(unsigned)offover);
    if(inoover || offover) {
        ws("\nFAIL: a 32-bit readdir would get EOVERFLOW and report an empty directory\n");
        sys3(1, 1, 0, 0);
    }
    ws("\nPASS: every entry survives the 32-bit dirent conversion\n");
    sys3(1, 0, 0, 0);
    __builtin_unreachable();
}
