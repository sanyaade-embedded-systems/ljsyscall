local ffi = require "ffi"
local bit = require "bit"

-- note should wrap more conditionals around stuff that might not be there

local S = {} -- exported functions

-- from bits/typesizes.h - underlying types, create as typedefs, mostly fix size.
--[[
#define __DEV_T_TYPE            __UQUAD_TYPE
#define __UID_T_TYPE            __U32_TYPE
#define __GID_T_TYPE            __U32_TYPE
#define __INO_T_TYPE            __ULONGWORD_TYPE
#define __INO64_T_TYPE          __UQUAD_TYPE
#define __MODE_T_TYPE           __U32_TYPE
#define __NLINK_T_TYPE          __UWORD_TYPE
#define __OFF_T_TYPE            __SLONGWORD_TYPE
#define __OFF64_T_TYPE          __SQUAD_TYPE
#define __PID_T_TYPE            __S32_TYPE
#define __RLIM_T_TYPE           __ULONGWORD_TYPE
#define __RLIM64_T_TYPE         __UQUAD_TYPE
#define __BLKCNT_T_TYPE         __SLONGWORD_TYPE
#define __BLKCNT64_T_TYPE       __SQUAD_TYPE
#define __FSBLKCNT_T_TYPE       __ULONGWORD_TYPE
#define __FSBLKCNT64_T_TYPE     __UQUAD_TYPE
#define __FSFILCNT_T_TYPE       __ULONGWORD_TYPE
#define __FSFILCNT64_T_TYPE     __UQUAD_TYPE
#define __ID_T_TYPE             __U32_TYPE
#define __CLOCK_T_TYPE          __SLONGWORD_TYPE
#define __TIME_T_TYPE           __SLONGWORD_TYPE
#define __USECONDS_T_TYPE       __U32_TYPE
#define __SUSECONDS_T_TYPE      __SLONGWORD_TYPE
#define __DADDR_T_TYPE          __S32_TYPE
#define __SWBLK_T_TYPE          __SLONGWORD_TYPE
#define __KEY_T_TYPE            __S32_TYPE
#define __CLOCKID_T_TYPE        __S32_TYPE
#define __TIMER_T_TYPE          void *
#define __BLKSIZE_T_TYPE        __SLONGWORD_TYPE
#define __FSID_T_TYPE           struct { int __val[2]; }
#define __SSIZE_T_TYPE          __SWORD_TYPE

/* Number of descriptors that can fit in an `fd_set'.  */
#define __FD_SETSIZE            1024
]]

--[[
/* The machine-dependent file <bits/typesizes.h> defines __*_T_TYPE
   macros for each of the OS types we define below.  The definitions
   of those macros must use the following macros for underlying types.
   We define __S<SIZE>_TYPE and __U<SIZE>_TYPE for the signed and unsigned
   variants of each of the following integer types on this machine.

        16              -- "natural" 16-bit type (always short)
        32              -- "natural" 32-bit type (always int)
        64              -- "natural" 64-bit type (long or long long)
        LONG32          -- 32-bit type, traditionally long
        QUAD            -- 64-bit type, always long long
        WORD            -- natural type of __WORDSIZE bits (int or long)
        LONGWORD        -- type of __WORDSIZE bits, traditionally long

   We distinguish WORD/LONGWORD, 32/LONG32, and 64/QUAD so that the
   conventional uses of `long' or `long long' type modifiers match the
   types we define, even when a less-adorned type would be the same size.
   This matters for (somewhat) portably writing printf/scanf formats for
   these types, where using the appropriate l or ll format modifiers can
   make the typedefs and the formats match up across all GNU platforms.  If
   we used `long' when it's 64 bits where `long long' is expected, then the
   compiler would warn about the formats not matching the argument types,
   and the programmer changing them to shut up the compiler would break the
   program's portability.

   Here we assume what is presently the case in all the GCC configurations
   we support: long long is always 64 bits, long is always word/address size,
   and int is always 32 bits.  */

#define __S16_TYPE              short int
#define __U16_TYPE              unsigned short int
#define __S32_TYPE              int
#define __U32_TYPE              unsigned int
#define __SLONGWORD_TYPE        long int
#define __ULONGWORD_TYPE        unsigned long int
#if __WORDSIZE == 32
# define __SQUAD_TYPE           __quad_t
# define __UQUAD_TYPE           __u_quad_t
# define __SWORD_TYPE           int
# define __UWORD_TYPE           unsigned int
# define __SLONG32_TYPE         long int
# define __ULONG32_TYPE         unsigned long int
# define __S64_TYPE             __quad_t
# define __U64_TYPE             __u_quad_t
/* We want __extension__ before typedef's that use nonstandard base types
   such as `long long' in C89 mode.  */
# define __STD_TYPE             __extension__ typedef
#elif __WORDSIZE == 64
# define __SQUAD_TYPE           long int
# define __UQUAD_TYPE           unsigned long int
# define __SWORD_TYPE           long int
# define __UWORD_TYPE           unsigned long int
# define __SLONG32_TYPE         int
# define __ULONG32_TYPE         unsigned int
# define __S64_TYPE             long int
# define __U64_TYPE             unsigned long int
]]

-- should we allow constants as strings as well, put in table and have function to look up? Not useful??

local octal = function (s) return tonumber(s, 8) end

-- open, fcntl
S.O_ACCMODE   = octal('0003')
S.O_RDONLY    = octal('00')
S.O_WRONLY    = octal('01')
S.O_RDWR      = octal('02')
S.O_CREAT     = octal('0100')
S.O_EXCL      = octal('0200')
S.O_NOCTTY    = octal('0400')
S.O_TRUNC     = octal('01000')
S.O_APPEND    = octal('02000')
S.O_NONBLOCK  = octal('04000')
S.O_NDELAY    = S.O_NONBLOCK
S.O_SYNC      = octal('04010000')
S.O_FSYNC     = S.O_SYNC
S.O_ASYNC     = octal('020000')
S.O_DIRECTORY = octal('0200000')
S.O_NOFOLLOW  = octal('0400000')
S.O_CLOEXEC   = octal('02000000')
S.O_DIRECT    = octal('040000')
S.O_NOATIME   = octal('01000000')
S.O_DSYNC     = octal('010000')
S.O_RSYNC     = S.O_SYNC

-- modes
S.S_IFMT   = octal('0170000') -- bit mask for the file type bit fields
S.S_IFSOCK = octal('0140000') -- socket
S.S_IFLNK  = octal('0120000') -- symbolic link
S.S_IFREG  = octal('0100000') -- regular file
S.S_IFBLK  = octal('0060000') -- block device
S.S_IFDIR  = octal('0040000') -- directory
S.S_IFCHR  = octal('0020000') -- character device
S.S_IFIFO  = octal('0010000') -- FIFO
S.S_ISUID  = octal('0004000') -- set UID bit
S.S_ISGID  = octal('0002000') -- set-group-ID bit
S.S_ISVTX  = octal('0001000') -- sticky bit

S.S_IRWXU = octal('00700') -- user (file owner) has read, write and execute permission
S.S_IRUSR = octal('00400') -- user has read permission
S.S_IWUSR = octal('00200') -- user has write permission
S.S_IXUSR = octal('00100') -- user has execute permission
S.S_IRWXG = octal('00070') -- group has read, write and execute permission
S.S_IRGRP = octal('00040') -- group has read permission
S.S_IWGRP = octal('00020') -- group has write permission
S.S_IXGRP = octal('00010') -- group has execute permission
S.S_IRWXO = octal('00007') -- others have read, write and execute permission
S.S_IROTH = octal('00004') -- others have read permission
S.S_IWOTH = octal('00002') -- others have write permission
S.S_IXOTH = octal('00001') -- others have execute permission

if ffi.abi('32bit') then S.O_LARGEFILE = octal('0100000') else S.O_LARGEFILE = 0 end -- not supported yet

-- access
S.R_OK = 4
S.W_OK = 2
S.X_OK = 1
S.F_OK = 0

--mmap
S.PROT_READ  = 0x1
S.PROT_WRITE = 0x2
S.PROT_EXEC  = 0x4
S.PROT_NONE  = 0x0
S.PROT_GROWSDOWN = 0x01000000
S.PROT_GROWSUP   = 0x02000000

-- Sharing types
S.MAP_SHARED  = 0x01
S.MAP_PRIVATE = 0x02
S.MAP_TYPE    = 0x0f
S.MAP_FIXED     = 0x10
S.MAP_FILE      = 0
S.MAP_ANONYMOUS = 0x20
S.MAP_ANON      = S.MAP_ANONYMOUS
S.MAP_32BIT     = 0x40
-- These are Linux-specific.
S.MAP_GROWSDOWN  = 0x00100
S.MAP_DENYWRITE  = 0x00800
S.MAP_EXECUTABLE = 0x01000
S.MAP_LOCKED     = 0x02000
S.MAP_NORESERVE  = 0x04000
S.MAP_POPULATE   = 0x08000
S.MAP_NONBLOCK   = 0x10000
S.MAP_STACK      = 0x20000
S.MAP_HUGETLB    = 0x40000

-- Flags to `msync'.
S.MS_ASYNC       = 1
S.MS_SYNC        = 4
S.MS_INVALIDATE  = 2

-- Flags for `mlockall'.
S.MCL_CURRENT    = 1
S.MCL_FUTURE     = 2

-- Flags for `mremap'.
S.MREMAP_MAYMOVE = 1
S.MREMAP_FIXED   = 2

-- sockets -- linux has flags against this, so provided as enum and constants
S.SOCK_STREAM    = 1
S.SOCK_DGRAM     = 2
S.SOCK_RAW       = 3
S.SOCK_RDM       = 4
S.SOCK_SEQPACKET = 5
S.SOCK_DCCP      = 6
S.SOCK_PACKET    = 10

S.SOCK_CLOEXEC = octal('02000000') -- flag
S.SOCK_NONBLOCK = octal('04000')   -- flag

-- address families. -- should be able to just use enum, once fix type initialisation
S.AF_UNSPEC     = 0
S.AF_LOCAL      = 1
S.AF_UNIX       = S.PF_LOCAL
S.AF_FILE       = S.PF_LOCAL
S.AF_INET       = 2
S.AF_AX25       = 3
S.AF_IPX        = 4
S.AF_APPLETALK  = 5
S.AF_NETROM     = 6
S.AF_BRIDGE     = 7
S.AF_ATMPVC     = 8
S.AF_X25        = 9
S.AF_INET6      = 10
S.AF_ROSE       = 11
S.AF_DECnet     = 12
S.AF_NETBEUI    = 13
S.AF_SECURITY   = 14
S.AF_KEY        = 15 
S.AF_NETLINK    = 16
S.AF_ROUTE      = S.PF_NETLINK
S.AF_PACKET     = 17
S.AF_ASH        = 18
S.AF_ECONET     = 19
S.AF_ATMSVC     = 20
S.AF_RDS        = 21
S.AF_SNA        = 22
S.AF_IRDA       = 23
S.AF_PPPOX      = 24
S.AF_WANPIPE    = 25
S.AF_LLC        = 26
S.AF_CAN        = 29
S.AF_TIPC       = 30
S.AF_BLUETOOTH  = 31
S.AF_IUCV       = 32
S.AF_RXRPC      = 33
S.AF_ISDN       = 34
S.AF_PHONET     = 35
S.AF_IEEE802154 = 36
S.AF_CAIF       = 37
S.AF_ALG        = 38
S.AF_MAX        = 39

-- misc socket constants -- move to enum??
S.SOL_RAW        = 255
S.SOL_DECNET     = 261
S.SOL_X25        = 262
S.SOL_PACKET     = 263
S.SOL_ATM        = 264
S.SOL_AAL        = 265
S.SOL_IRDA       = 266

-- Maximum queue length specifiable by listen.
S.SOMAXCONN = 128

-- waitpid 3rd arg
S.WNOHANG       = 1
S.WUNTRACED     = 2

--waitid 4th arg
S.WSTOPPED      = 2
S.WEXITED       = 4
S.WCONTINUED    = 8
S.WNOWAIT       = 0x01000000

S.symerror = { -- symbolic error names, indexed by errno
'EPERM',  'ENOENT', 'ESRCH',   'EINTR',
'EIO',    'ENXIO',  'E2BIG',   'ENOEXEC',
'EBADF',  'ECHILD', 'EAGAIN',  'ENOMEM',
'EACCES', 'EFAULT', 'ENOTBLK', 'EBUSY',
'EEXIST', 'EXDEV',  'ENODEV',  'ENOTDIR',
'EISDIR', 'EINVAL', 'ENFILE',  'EMFILE',
'ENOTTY', 'ETXTBSY','EFBIG',   'ENOSPC',
'ESPIPE', 'EROFS',  'EMLINK',  'EPIPE',
'EDOM',   'ERANGE'
}

-- optional garbage collection support
S.gc = ffi.gc

local nogc = function(d, f) return d end

function S.gcollect(bool) if bool then S.gc = ffi.gc else S.gc = nogc end end

local errorret, retint, retbool, retptr, retfd, getfd

function S.strerror(errno) return ffi.string(ffi.C.strerror(errno)), errno end

-- standard error return
function errorret()
  return nil, S.strerror(ffi.errno())
end

function retint(ret)
  if ret == -1 then
    return errorret()
  end
  return ret
end

-- used for no return value, return true for use of assert
function retbool(ret)
  if ret == -1 then
    return errorret()
  end
  return true
end

-- used for pointer returns, -1 is failure, optional gc function
function retptr(ret, f)
  if ffi.cast("long", ret) == -1 then
     return errorret()
  end
  if f then return S.gc(ret, f) end
  return ret
end

-- define types
ffi.cdef[[
// typedefs for word size independent types

// 16 bit
typedef uint16_t in_port_t;

// 32 bit
typedef uint32_t mode_t;
typedef uint32_t uid_t;
typedef uint32_t gid_t;
typedef uint32_t socklen_t;
typedef int32_t pid_t;

// 64 bit
typedef uint64_t dev_t;

// posix standards
typedef unsigned short int sa_family_t;

// typedefs which are word length
typedef unsigned long size_t;
typedef long ssize_t;
typedef long off_t;
typedef long time_t;
typedef unsigned long ino_t;
typedef unsigned long nlink_t;
typedef long blksize_t;
typedef long blkcnt_t;

// structs
struct timespec {
  time_t tv_sec;        /* seconds */
  long   tv_nsec;       /* nanoseconds */
};
// for uname. may well differ by OS
struct utsname {
  char sysname[65];
  char nodename[65];
  char release[65];
  char version[65];
  char machine[65];
  char domainname[65];
};

struct sockaddr {
  sa_family_t sa_family;
  char sa_data[14];
};
// ipv4 sockets
struct in_addr {
  uint32_t       s_addr;
};
struct sockaddr_in {
  sa_family_t    sin_family; /* address family: AF_INET */
  in_port_t      sin_port;   /* port in network byte order */
  struct in_addr sin_addr;   /* internet address */
  unsigned char sin_zero[8]; /* padding, should not vary by arch */
};

// enums, LuaJIT will allow strings to be used, so we provide for appropriate parameters
enum SEEK {
  SEEK_SET,
  SEEK_CUR,
  SEEK_END
};
enum EXIT {
  EXIT_SUCCESS,
  EXIT_FAILURE
};
enum F {
  F_DUPFD       = 0,
  F_GETFD       = 1,
  F_SETFD       = 2,
  F_GETFL       = 3,
  F_SETFL       = 4,
  F_GETLK       = 5,
  F_SETLK       = 6,
  F_SETLKW      = 7,
  F_SETOWN      = 8,
  F_GETOWN      = 9,
  F_SETSIG      = 10,
  F_GETSIG      = 11,
//F_GETLK64     = 12,      -- 64 on 32 file ops still TODO
//F_SETLK64     = 13,      -- 64 on 32 file ops still TODO
//F_SETLKW64    = 14,      -- 64 on 32 file ops still TODO
  F_SETOWN_EX   = 15,
  F_GETOWN_EX   = 16,
  F_SETLEASE    = 1024,
  F_GETLEASE    = 1025,
  F_NOTIFY      = 1026,
  F_SETPIPE_SZ  = 1031,
  F_GETPIPE_SZ  = 1032,
  F_DUPFD_CLOEXEC = 1030
};
enum MADV {
  MADV_NORMAL      = 0,
  MADV_RANDOM      = 1,
  MADV_SEQUENTIAL  = 2,
  MADV_WILLNEED    = 3,
  MADV_DONTNEED    = 4,
  MADV_REMOVE      = 9,
  MADV_DONTFORK    = 10,
  MADV_DOFORK      = 11,
  MADV_MERGEABLE   = 12,
  MADV_UNMERGEABLE = 13,
  MADV_HUGEPAGE    = 14,
  MADV_NOHUGEPAGE  = 15,
  MADV_HWPOISON    = 100,
  // POSIX madvise names
  POSIX_MADV_NORMAL      = 0,
  POSIX_MADV_RANDOM      = 1,
  POSIX_MADV_SEQUENTIAL  = 2,
  POSIX_MADV_WILLNEED    = 3,
  POSIX_MADV_DONTNEED    = 4,
};
enum SOCK {
  SOCK_STREAM    = 1,
  SOCK_DGRAM     = 2,
  SOCK_RAW       = 3,
  SOCK_RDM       = 4,
  SOCK_SEQPACKET = 5,
  SOCK_DCCP      = 6,
  SOCK_PACKET    = 10,
};
enum AF {
  AF_UNSPEC     = 0,
  AF_LOCAL      = 1,
  AF_UNIX       = AF_LOCAL,
  AF_FILE       = AF_LOCAL,
  AF_INET       = 2,
  AF_AX25       = 3,
  AF_IPX        = 4,
  AF_APPLETALK  = 5,
  AF_NETROM     = 6,
  AF_BRIDGE     = 7,
  AF_ATMPVC     = 8,
  AF_X25        = 9,
  AF_INET6      = 10,
  AF_ROSE       = 11,
  AF_DECnet     = 12,
  AF_NETBEUI    = 13,
  AF_SECURITY   = 14,
  AF_KEY        = 15,
  AF_NETLINK    = 16,
  AF_ROUTE      = AF_NETLINK,
  AF_PACKET     = 17,
  AF_ASH        = 18,
  AF_ECONET     = 19,
  AF_ATMSVC     = 20,
  AF_RDS        = 21,
  AF_SNA        = 22,
  AF_IRDA       = 23,
  AF_PPPOX      = 24,
  AF_WANPIPE    = 25,
  AF_LLC        = 26,
  AF_CAN        = 29,
  AF_TIPC       = 30,
  AF_BLUETOOTH  = 31,
  AF_IUCV       = 32,
  AF_RXRPC      = 33,
  AF_ISDN       = 34,
  AF_PHONET     = 35,
  AF_IEEE802154 = 36,
  AF_CAIF       = 37,
  AF_ALG        = 38,
  AF_MAX        = 39,
};
]]

-- stat structure is architecture dependent in Linux
-- this is the way glibc versions stat via __xstat, may need to change for other libc, eg if define stat as a non inline function
local STAT_VER_LINUX

if ffi.abi("32bit") then
STAT_VER_LINUX = 3
ffi.cdef[[
struct stat {
  dev_t st_dev;                       /* Device.  */
  unsigned short int __pad1;
  ino_t __st_ino;                     /* 32bit file serial number.    */
  mode_t st_mode;                     /* File mode.  */
  nlink_t st_nlink;                   /* Link count.  */
  uid_t st_uid;                       /* User ID of the file's owner. */
  gid_t st_gid;                       /* Group ID of the file's group.*/
  dev_t st_rdev;                      /* Device number, if device.  */
  unsigned short int __pad2;
  off_t st_size;                      /* Size of file, in bytes.  */
  blksize_t st_blksize;               /* Optimal block size for I/O.  */
  blkcnt_t st_blocks;                 /* Number 512-byte blocks allocated. */
  struct timespec st_atim;            /* Time of last access.  */
  struct timespec st_mtim;            /* Time of last modification.  */
  struct timespec st_ctim;            /* Time of last status change.  */   unsigned long int __unused4;
  unsigned long int __unused5;
};
]]
else -- 64 bit arch
STAT_VER_LINUX = 1
ffi.cdef[[
struct stat {
  dev_t st_dev;             /* Device.  */
  ino_t st_ino;             /* File serial number.  */
  nlink_t st_nlink;         /* Link count.  */
  mode_t st_mode;           /* File mode.  */
  uid_t st_uid;             /* User ID of the file's owner. */
  gid_t st_gid;             /* Group ID of the file's group.*/
  int __pad0;
  dev_t st_rdev;            /* Device number, if device.  */
  off_t st_size;            /* Size of file, in bytes.  */
  blksize_t st_blksize;     /* Optimal block size for I/O.  */
  blkcnt_t st_blocks;       /* Number 512-byte blocks allocated. */
  struct timespec st_atim;  /* Time of last access.  */
  struct timespec st_mtim;  /* Time of last modification.  */
  struct timespec st_ctim;  /* Time of last status change.  */
  long int __unused[3];
};
]]
end

ffi.cdef[[
int close(int fd);
int open(const char *pathname, int flags, mode_t mode);
int chdir(const char *path);
int mkdir(const char *pathname, mode_t mode);
int rmdir(const char *pathname);
int unlink(const char *pathname);
int acct(const char *filename);
int chmod(const char *path, mode_t mode);
int link(const char *oldpath, const char *newpath);
mode_t umask(mode_t mask);
int uname(struct utsname *buf);
int gethostname(char *name, size_t len);
int sethostname(const char *name, size_t len);
pid_t getpid(void);
pid_t getppid(void);
pid_t fork(void);
pid_t wait(int *status);
pid_t waitpid(pid_t pid, int *status, int options);
void _exit(enum EXIT status);

ssize_t read(int fd, void *buf, size_t count);
ssize_t write(int fd, const void *buf, size_t count);
ssize_t pread(int fd, void *buf, size_t count, off_t offset);
ssize_t pwrite(int fd, const void *buf, size_t count, off_t offset);
off_t lseek(int fd, off_t offset, enum SEEK whence); 

int dup(int oldfd);
int dup3(int oldfd, int newfd, int flags);
int fchdir(int fd);
int fsync(int fd);
int fdatasync(int fd);
int fcntl(int fd, enum F cmd, long arg); /* arg can be a pointer though */
int fchmod(int fd, mode_t mode);

int socket(enum AF domain, enum SOCK type, int protocol);
int bind(int sockfd, const struct sockaddr *addr, socklen_t addrlen);

void *mmap(void *addr, size_t length, int prot, int flags, int fd, off_t offset);
int munmap(void *addr, size_t length);
int msync(void *addr, size_t length, int flags);
int mlock(const void *addr, size_t len);
int munlock(const void *addr, size_t len);
int mlockall(int flags);
int munlockall(void);
void *mremap(void *old_address, size_t old_size, size_t new_size, int flags, void *new_address);
int madvise(void *addr, size_t length, enum MADV advice);

int pipe2(int pipefd[2], int flags);

int unlink(const char *pathname);
int access(const char *pathname, int mode);
char *getcwd(char *buf, size_t size);

int nanosleep(const struct timespec *req, struct timespec *rem);

// stat glibc internal functions
int __fxstat(int ver, int fd, struct stat *buf);
int __xstat(int ver, const char *path, struct stat *buf);
int __lxstat(int ver, const char *path, struct stat *buf);
int gnu_dev_major(dev_t dev);
int gnu_dev_minor(dev_t dev);


// functions from libc ie man 3 not man 2
void exit(enum EXIT status);

// functions from libc that could be exported as a convenience, used internally
void *calloc(size_t nmemb, size_t size);
void *malloc(size_t size);
void free(void *ptr);
void *realloc(void *ptr, size_t size);
char *strerror(int errnum);
]]

--[[ -- not defined yet
 int creat(const char *pathname, mode_t mode); -- defined using open instead
]]


local fd_t -- type for a file descriptor
local fd2_t = ffi.typeof("int[2]")
local timespec_t = ffi.typeof("struct timespec")
local stat_t

-- endian conversion
if ffi.abi("be") then -- nothing to do
  function S.htonl(b) return b end
else
  function S.htonl(b) return bit.bswap(b) end
  function S.htons(b) return bit.rshift(bit.bswap(b), 16) end
end
S.ntohl = S.htonl -- reverse is the same
S.ntohs = S.htons

--get fd from standard string, integer, or cdata
function getfd(fd)
  if type(fd) == 'number' then return fd end
  if ffi.istype(fd_t, fd) then return fd.fd end
  if type(fd) == 'string' then
    if fd == 'stdin' or fd == 'STDIN_FILENO' then return 0 end
    if fd == 'stdout' or fd == 'STDOUT_FILENO' then return 1 end
    if fd == 'stderr' or fd == 'STDERR_FILENO' then return 2 end
  end
end

function retfd(ret)
  if ret == -1 then return errorret() end
  return S.gc(fd_t(ret), S.close)
end

function S.open(pathname, flags, mode) return retfd(ffi.C.open(pathname, flags or 0, mode or 0)) end

function S.dup(oldfd, newfd, flags)
  if newfd == nil then return retfd(ffi.C.dup(getfd(oldfd))) end
  return retfd(ffi.C.dup3(getfd(oldfd), getfd(newfd), flags or 0))
end
S.dup2 = S.dup -- flags optional, so do not need new function
S.dup3 = S.dup -- conditional on newfd set

function S.pipe(flags)
  local fd2 = fd2_t()
  local ret = ffi.C.pipe2(fd2, flags or 0)
  if ret == -1 then
    return nil, errorret() -- extra nil as we return two fds normally
  end
  return fd_t(fd2[0]), fd_t(fd2[1])
end
S.pipe2 = S.pipe

function S.close(fd)
  local ret = ffi.C.close(getfd(fd))
  if ret == -1 then return errorret() end
  if ffi.istype(fd_t, fd) then
    S.gc(fd, nil) -- remove gc finalizer as now closed; should we also remove if get EBADF?
  end
  return true
end

function S.creat(pathname, mode) return S.open(pathname, S.O_CREAT + S.O_WRONLY + S.O_TRUNC, mode) end
function S.unlink(pathname) return retbool(ffi.C.unlink(pathname)) end
function S.access(pathname, mode) return retbool(ffi.C.access(pathname, mode)) end
function S.chdir(path) return retbool(ffi.C.chdir(path)) end
function S.mkdir(path, mode) return retbool(ffi.C.mkdir(path, mode)) end
function S.rmdir(path) return retbool(ffi.C.rmdir(path)) end
function S.unlink(pathname) return retbool(ffi.C.unlink(pathname)) end
function S.acct(filename) return retbool(ffi.C.acct(filename)) end
function S.umask(mask) return ffi.C.umask(mask) end -- never fails
function S.chmod(path, mode) return retbool(ffi.C.chmod(path, mode)) end
function S.link(oldpath, newpath) return retbool(ffi.C.link(oldpath, newpath)) end
function S.getpid() return ffi.C.getpid() end
function S.getppid() return ffi.C.getppid() end
function S.fork() return retint(ffi.C.fork()) end
function S.wait() -- we always get and return the status value, need to add helpers
  local status = ffi.new("int[1]")
  local ret = ffi.C.wait(status)
  if ret == -1 then return nil, errorret() end -- extra padding where we would return status
  return ret, status[0]
end
function S.waitpid(pid, options) -- we always get and return the status value, need to add helpers
  local status = ffi.new("int[1]")
  local ret = ffi.C.waitpid(pid, status, options or 0)
  if ret == -1 then return nil, errorret() end -- extra padding where we would return status
  return ret, status[0]
end
function S._exit(status) ffi.C._exit(status or 0) end
function S.exit(status) ffi.C.exit(status or 0) end

function S.read(fd, buf, count) return retint(ffi.C.read(getfd(fd), buf, count)) end
function S.write(fd, buf, count) return retint(ffi.C.write(getfd(fd), buf, count)) end
function S.pread(fd, buf, count, offset) return retint(ffi.C.pread(getfd(fd), buf, count, offset)) end
function S.pwrite(fd, buf, count, offset) return retint(ffi.C.pwrite(getfd(fd), buf, count, offset)) end
function S.lseek(fd, offset, whence) return retint(ffi.C.lseek(getfd(fd), offset, whence)) end

function S.fchdir(fd) return retbool(ffi.C.fchdir(getfd(fd))) end
function S.fsync(fd) return retbool(ffi.C.fsync(getfd(fd))) end
function S.fdatasync(fd) return retbool(ffi.C.fdatasync(getfd(fd))) end
function S.fchmod(fd, mode) return retbool(ffi.C.fchmod(getfd(fd), mode)) end

function S.stat(path)
  local buf = stat_t()
  local ret = ffi.C.__xstat(STAT_VER_LINUX, path, buf)
  if ret == -1 then return errorret() end
  return buf
end
function S.lstat(path)
  local buf = stat_t()
  local ret = ffi.C.__lxstat(STAT_VER_LINUX, path, buf)
  if ret == -1 then return errorret() end
  return buf
end
function S.fstat(fd)
  local buf = stat_t()
  local ret = ffi.C.__fxstat(STAT_VER_LINUX, getfd(fd), buf)
  if ret == -1 then return errorret() end
  return buf
end

function S.getcwd(buf, size)
  local ret = ffi.C.getcwd(buf, size or 0)
  if buf == nil then -- Linux will allocate buffer here, return Lua string and free
    if ret == nil then return errorret() end
    local s = ffi.string(ret) -- guaranteed to be zero terminated if no error
    ffi.C.free(ret)
    return s
  end
  -- user allocated buffer
  if ret == nil then return errorret() end
  return true -- no point returning the pointer as it is just the passed buffer
end

function S.nanosleep(req)
  local rem = timespec_t()
  local ret = ffi.C.nanosleep(req, rem)
  if ret == -1 then return errorret() end
  return rem -- return second argument, Lua style
end

function S.mmap(addr, length, prot, flags, fd, offset)
  return retptr(ffi.C.mmap(addr, length, prot, flags, getfd(fd), offset), function(addr) ffi.C.munmap(addr, length) end) -- add munmap gc
end
function S.munmap(addr, length)
  return retbool(ffi.C.munmap(S.gc(addr, nil), length)) -- remove gc on unmap
end
function S.msync(addr, length, flags) return retbool(ffi.C.msync(addr, length, flags)) end
function S.mlock(addr, len) return retbool(ffi.C.mlock(addr, len)) end
function S.munlock(addr, len) return retbool(ffi.C.munlock(addr, len)) end
function S.mlockall(flags) return retbool(ffi.C.mlockall(flags)) end
function S.munlockall() return retbool(ffi.C.munlockall()) end
function S.mremap(old_address, old_size, new_size, flags, new_address) return retptr(ffi.C.mremap(old_address, old_size, new_size, flags, new_address)) end
function S.madvise(addr, length, advice) return retbool(ffi.C.madvise(addr, length, advice)) end

function S.socket(domain, stype, protocol) return retfd(ffi.C.socket(domain, stype, protocol or 0)) end

-- address types
local sockaddr_t = ffi.typeof("struct sockaddr")
local sockaddr_in_t = ffi.typeof("struct sockaddr_in")
local in_addr_t = ffi.typeof("struct in_addr")
S.INADDR_ANY = in_addr_t() -- is this best way? harder to compare against, for example

function S.bind(sockfd, addr, addrlen)
  if addrlen == nil then -- we can compute this, for known address types
    if ffi.istype(sockaddr_t, addr) then addrlen = ffi.sizeof(sockaddr_t)
    elseif ffi.istype(sockaddr_in_t, addr) then addrlen = ffi.sizeof(sockaddr_in_t)
    end
  end
  return retbool(ffi.C.bind(getfd(sockfd), ffi.cast("struct sockaddr *", addr), addrlen))
end

function S.fcntl(fd, cmd, arg)
  -- some uses have arg as a pointer, need handling TODO
  local ret = ffi.C.fcntl(getfd(fd), cmd, arg or 0)
  -- return values differ, some special handling needed
  if cmd == "F_DUPFD" or cmd == "F_DUPFD_CLOEXEC" then return retfd(ret) end
  if cmd == "F_GETFD" or cmd == "F_GETFL" or cmd == "F_GETLEASE" or cmd == "F_GETOWN" or cmd == "F_GETSIG" or cmd == "F_GETPIPE_SZ" then return retint(ret) end
  return retbool(ret)
end

local utsname_t = ffi.typeof("struct utsname")
function S.uname()
  local u = utsname_t()
  local ret = ffi.C.uname(u)
  if ret == -1 then return errorret() end
  return {sysname = ffi.string(u.sysname), nodename = ffi.string(u.nodename), release = ffi.string(u.release),
          version = ffi.string(u.version), machine = ffi.string(u.machine), domainname = ffi.string(u.domainname)}
end

-- 'macros' and helper functions etc

-- note that major and minor are inline in glibc, gnu provides these real symbols, else you might have to parse yourself
function S.major(dev) return ffi.C.gnu_dev_major(dev) end
function S.minor(dev) return ffi.C.gnu_dev_minor(dev) end

function S.S_ISREG(m)  return bit.band(m, S.S_IFREG)  ~= 0 end
function S.S_ISDIR(m)  return bit.band(m, S.S_IFDIR)  ~= 0 end
function S.S_ISCHR(m)  return bit.band(m, S.S_IFCHR)  ~= 0 end
function S.S_ISBLK(m)  return bit.band(m, S.S_IFBLK)  ~= 0 end
function S.S_ISFIFO(m) return bit.band(m, S.S_IFFIFO) ~= 0 end
function S.S_ISLNK(m)  return bit.band(m, S.S_IFLNK)  ~= 0 end
function S.S_ISSOCK(m) return bit.band(m, S.S_IFSOCK) ~= 0 end

-- not system functions
function S.nogc(d) ffi.gc(d, nil) end -- use ffi.gc not S.gc here

-- types

-- methods on an fd
local fdmethods = {'nogc', 'close', 'dup', 'dup2', 'dup3', 'read', 'write', 'pread', 'pwrite',
                   'lseek', 'fchdir', 'fsync', 'fdatasync', 'fstat', 'fcntl', 'bind', 'fchmod'}
local fmeth = {}
for i, v in ipairs(fdmethods) do fmeth[v] = S[v] end

fd_t = ffi.metatype("struct {int fd;}", {__index = fmeth})
stat_t = ffi.typeof("struct stat")

-- add char buffer type
local buffer_t = ffi.typeof("char[?]")
S.string = ffi.string -- convenience for converting buffers
S.sizeof = ffi.sizeof -- convenience so user need not require ffi

-- we could just return as S.timespec_t etc, not sure which is nicer?
S.t = {
fd = fd_t, timespec = timespec_t, buffer = buffer_t, stat = stat_t,
sockaddr = sockaddr_t, sockaddr_in = sockaddr_in_t, in_addr = in_addr_t,
utsname = utsname_t
}

return S


