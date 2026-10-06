/* No guest files or libc: exercise the i386 kernel syscall ABI directly. */
typedef unsigned int u32;
typedef unsigned long long u64;
static int stage;
static int sc(int n,u32 a,u32 b,u32 c,u32 d,u32 e)
{
 int r;
 __asm__ volatile("int $0x80":"=a"(r):"a"(n),"b"(a),"c"(b),"d"(c),"S"(d),"D"(e):"memory","cc");
 return r;
}
#define P(x) ((u32)(x))
#define S(n,a,b,c) sc(n,P(a),P(b),P(c),0,0)
#define CHECK(x) do { if(!(x)) { S(1,stage,0,0); __builtin_unreachable(); } } while(0)
static const char file[]="probe.dat", dir[]="probe.dir";
struct __attribute__((packed)) oldstat {
 u32 dev,ino; unsigned short mode,nlink,uid,gid;
 u32 rdev,size,blksize,blocks,atime,an,mtime,mn,ctime,cn,unused[2];
};
struct __attribute__((packed)) stat64 {
 u64 dev; u32 pad0,ino32,mode,nlink,uid,gid; u64 rdev;
 u32 pad1; u64 size; u32 blksize; u64 blocks;
 u32 atime,an,mtime,mn,ctime,cn; u64 ino;
};
struct __attribute__((packed)) lock32 {short type,whence;int start,len,pid;};
struct __attribute__((packed)) lock64 {short type,whence;long long start,len;int pid;};
void __attribute__((force_align_arg_pointer)) _start(void)
{
 stage=1;
 CHECK(S(39,dir,0700,0)==0);
 CHECK(S(39,dir,0700,0)==-17);
 CHECK(S(33,dir,0,0)==0);
 CHECK(S(40,dir,0,0)==0);
 CHECK(S(33,dir,0,0)==-2);
 stage=2;
 int fd=S(5,file,0x8242,0600); CHECK(fd>=0);
 CHECK(S(4,fd,"abc",3)==3);
 CHECK(S(19,fd,0,0)==0);
 CHECK(S(19,-1,0,0)==-9);
 int other=S(41,fd,0,0); CHECK(other>=0);
 CHECK(S(55,other,1,0)==0); CHECK(S(55,other,2,1)==0);
 CHECK(S(221,other,1,0)==1);
 CHECK(S(221,-1,1,0)==-9);
 CHECK(S(221,fd,4,0x800)==0);
 CHECK((S(55,fd,3,0)&0x800)!=0);
 struct lock32 lk={1,0,0,1,0};
 CHECK(S(55,fd,5,&lk)==0 && lk.type==2);
 struct lock64 lk64={1,0,0x100000000LL,1,0};
 CHECK(S(221,fd,12,&lk64)==0 && lk64.type==2);
 CHECK(S(6,other,0,0)==0);
 stage=3;
 u64 seek[2]={0,0x123456789abcdef0ULL};
 CHECK(sc(140,fd,1,123,P(seek),0)==0 && seek[0]==0x10000007bULL);
 CHECK(seek[1]==0x123456789abcdef0ULL);
 CHECK(S(4,fd,"x",1)==1);
 CHECK(sc(140,-1,0,0,P(seek),0)==-9 && seek[0]==0x10000007bULL);
 CHECK(sc(140,-1,0,0,1,0)==-9);
 CHECK(sc(140,fd,0,4321,1,0)==-14);
 CHECK(S(19,fd,0,1)==4321);
 stage=4;
 struct {struct stat64 st;u32 guard;} b;
 b.guard=0x12345678;
 CHECK(S(197,fd,&b,0)==0 && b.st.size==0x10000007cULL);
 CHECK(b.guard==0x12345678);
 CHECK(S(195,file,&b,0)==0 && b.st.size==0x10000007cULL);
 b.st.mode=0x87654321;
 CHECK(S(195,"does-not-exist",&b,0)==-2 && b.st.mode==0x87654321);
 CHECK(S(197,-1,&b,0)==-9 && b.st.mode==0x87654321);
 CHECK(S(195,file,1,0)==-14);
 struct {struct oldstat st;u32 guard;} old;
 old.guard=0x12345678;
 CHECK(S(106,"/dev/null",&old,0)==0 && (old.st.mode&0170000)==0020000);
 CHECK(old.guard==0x12345678 && old.st.size==0);
 CHECK(S(106,file,&old,0)==-75);
 stage=5;
 struct {unsigned char before;int sec,usec;unsigned char after;} __attribute__((packed)) t;
 t.before=0x21;t.after=0x43;
 CHECK(S(78,&t.sec,0,0)==0 && t.sec>1700000000 && t.usec>=0 && t.usec<1000000);
 CHECK(t.before==0x21 && t.after==0x43);
 CHECK(S(78,1,0,0)==-14);
 char path[1025]; path[1024]=0x21;
 CHECK(S(85,"/proc/self/exe",path,1024)>0 && path[1024]==0x21);
 CHECK(S(85,"does-not-exist",path,1024)==-2);
 stage=6;
 int pipes[2]; CHECK(S(42,pipes,0,0)==0);
 struct {int fd;short events,revents;} pf={pipes[0],1,123};
 CHECK(S(168,&pf,1,20)==0 && pf.revents==0);
 CHECK(S(4,pipes[1],"z",1)==1);
 CHECK(S(168,&pf,1,0)==1 && (pf.revents&1));
 int available[2]={0,0x12345678};
 CHECK(S(54,pipes[0],0x541b,available)==0 && available[0]==1);
 CHECK(available[1]==0x12345678);
 CHECK(S(54,-1,0x541b,available)==-9);
 CHECK(S(54,pipes[0],0x541b,1)==-14);
 CHECK(S(168,1,1,0)==-14);
 stage=7;
 int times[4]={0,1000000,0x12345678,0x87654321};
 CHECK(S(162,times,times+2,0)==0 && times[2]==0x12345678);
 CHECK(S(162,1,0,0)==-14);
 CHECK(S(199,0,0,0)>=0 && S(201,0,0,0)>=0);
 u32 vectors[4]={P("ab"),2,P("cd"),2};
 CHECK(S(146,pipes[1],vectors,2)==4);
 CHECK(S(146,pipes[1],1,2)==-14);
 char four[4];CHECK(S(3,pipes[0],four,4)==4); // the earlier z plus abc
 CHECK(four[0]=='z' && four[1]=='a');
 stage=8;
 u32 sockargs[6]={1,1,0,P(pipes),0,0};
 int sockets[2];sockargs[3]=P(sockets);
 CHECK(S(102,8,sockargs,0)==0);
 sockargs[0]=sockets[0];sockargs[1]=P("hey");sockargs[2]=3;sockargs[3]=0;
 CHECK(S(102,9,sockargs,0)==3);
 sockargs[0]=sockets[1];sockargs[1]=P(four);
 CHECK(S(102,10,sockargs,0)==3 && four[0]=='h' && four[2]=='y');
 CHECK(S(102,8,1,0)==-14);
 S(6,sockets[0],0,0);S(6,sockets[1],0,0);
 stage=9;
 int id=sc(117,23,0,4096,01000|0600,0);CHECK(id>=0);
 u32 shared=0;
 CHECK(sc(117,21,id,0,P(&shared),0)==0 && shared!=0);
 *(volatile u32*)shared=0x12345678;
 CHECK(*(volatile u32*)shared==0x12345678);
 CHECK(sc(117,24,id,0,0,0)==0); // IPC_RMID: delete after final detach
 CHECK(sc(117,22,0,0,0,shared)==0);
 CHECK(S(78,shared,0,0)==-14); // detached protection metadata must be gone
 S(6,fd,0,0);S(6,pipes[0],0,0);S(6,pipes[1],0,0);
 static const char msg[]="PASS ordinary i386 syscalls (files, time, descriptors, sockets, shared memory)\n";
 S(4,1,msg,sizeof(msg)-1); S(1,0,0,0);
 __builtin_unreachable();
}
