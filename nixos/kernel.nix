# Mainline counterpart of Sipeed's sg2002_licheervnano_sd_defconfig:
# https://github.com/sipeed/LicheeRV-Nano-Build/blob/main/build/boards/sg200x/sg2002_licheervnano_sd/linux/sg2002_licheervnano_sd_defconfig
# Vendor-only CVI drivers are replaced by mainline Sophgo/DesignWare drivers.
{
  pkgs,
  lib,
  display ? false,
}:
let
  inherit (lib.kernel)
    yes
    no
    module
    freeform
    ;
in
pkgs.linux_7_0.override {
  defconfig = "allnoconfig";
  autoModules = false;
  enableCommonConfig = false;
  ignoreConfigErrors = false;
  kernelPatches = [
    pkgs.kernelPatches.bridge_stp_helper
    pkgs.kernelPatches.request_key_helper
    # Sound out: the CV1800B DMA support from mainline (applied upstream
    # after 7.0), then I2S3 + the internal DAC + a simple-audio-card.
    {
      name = "upstream-dt-bindings-cv1800b-axi-dma";
      patch = ../patches/upstream-dt-bindings-cv1800b-axi-dma.patch;
    }
    {
      name = "upstream-dw-axi-dmac-cv1800b";
      patch = ../patches/upstream-dw-axi-dmac-cv1800b.patch;
    }
    {
      name = "nano-audio-dt";
      patch = ../patches/nano-audio-dt.patch;
    }
  ]
  ++ lib.optional display {
    name = "nano-framebuffer-dma-helpers";
    patch = ../patches/nano-fb-helpers.patch;
  };
  structuredExtraConfig = (
    {
      # One Linux C906 core; the secondary MCU is not an SMP Linux CPU.
      ARCH_RV64I = yes;
      NONPORTABLE = yes;
      MMU = yes;
      ARCH_SOPHGO = yes;
      ERRATA_THEAD = yes;
      FPU = yes;
      RISCV_ISA_C = yes;
      SMP = no;
      CC_OPTIMIZE_FOR_SIZE = yes;
      EXPERT = yes;
      PRINTK = yes;
      PRINTK_TIME = yes;
      BUG = yes;
      ELF_CORE = yes;
      SYSVIPC = yes;
      POSIX_TIMERS = yes;
      POSIX_MQUEUE = yes;
      MULTIUSER = yes;
      FUTEX = yes;
      EPOLL = yes;
      SIGNALFD = yes;
      TIMERFD = yes;
      EVENTFD = yes;
      AIO = yes;
      ADVISE_SYSCALLS = yes;
      FILE_LOCKING = yes;
      UNIX98_PTYS = yes;
      HIGH_RES_TIMERS = yes;
      NO_HZ_IDLE = yes;
      HZ_100 = yes;
      BINFMT_ELF = yes;
      BINFMT_SCRIPT = yes;
      MODULES = yes;
      MODULE_UNLOAD = yes;
      BLK_DEV_INITRD = yes;
      KERNEL_UNCOMPRESSED = yes;
      RD_ZSTD = yes;
      RD_GZIP = yes;
      DEVTMPFS = yes;
      DEVTMPFS_MOUNT = yes;
      PROC_FS = yes;
      SYSFS = yes;
      TMPFS = yes;
      TMPFS_POSIX_ACL = yes;
      TMPFS_XATTR = yes;
      FHANDLE = yes;
      INOTIFY_USER = yes;
      DNOTIFY = yes;
      CGROUPS = yes;
      MEMCG = yes;
      CGROUP_PIDS = yes;
      CGROUP_SCHED = yes;
      CFS_BANDWIDTH = yes;
      CGROUP_CPUACCT = yes;
      CGROUP_DEVICE = yes;
      NAMESPACES = yes;
      UTS_NS = yes;
      IPC_NS = yes;
      PID_NS = yes;
      NET_NS = yes;
      USER_NS = yes;
      SECCOMP = yes;
      SECCOMP_FILTER = yes;
      CHECKPOINT_RESTORE = yes;
      SECURITY = yes;
      SECURITYFS = yes;
      AUDIT = yes;
      KEYS = yes;
      CRYPTO = yes;
      CRYPTO_USER_API_HASH = yes;
      CRYPTO_SHA256 = yes;
      CRYPTO_HMAC = yes;
      # Swap is essential here despite being disabled in the vendor config.
      SWAP = yes;
      ZRAM = module;
      CRYPTO_LZ4 = module;
      CRYPTO_LZO = module;
      BLK_DEV = yes;
      # resize2fs must open the mounted root block device for online growth.
      BLK_DEV_WRITE_MOUNTED = yes;
      BLK_DEV_LOOP = module;
      ZRAM_BACKEND_LZ4 = yes;
      ZRAM_BACKEND_LZO = yes;
      ZRAM_DEF_COMP_LZ4 = yes;
      MD = yes;
      BLK_DEV_DM = module;
      EXT4_FS = yes;
      EXT4_FS_POSIX_ACL = yes;
      EXT4_FS_SECURITY = yes;
      # Ruby's chroot keeps the supplied rootfs read-only under a tmpfs overlay.
      OVERLAY_FS = module;
      FAT_FS = yes;
      VFAT_FS = yes;
      NLS_CODEPAGE_437 = yes;
      NLS_ISO8859_1 = yes;
      FUSE_FS = module;
      AUTOFS_FS = yes;
      CONFIGFS_FS = module;
      MSDOS_PARTITION = yes;
      # UART, SD host, pin mux, clock, reset, and noncoherent DMA support.
      TTY = yes;
      SERIAL_8250 = yes;
      SERIAL_8250_CONSOLE = yes;
      SERIAL_8250_DW = yes;
      SERIAL_EARLYCON_RISCV_SBI = yes;
      SERIAL_8250_NR_UARTS = freeform "1";
      SERIAL_8250_RUNTIME_UARTS = freeform "1";
      COMMON_CLK = yes;
      CLK_SOPHGO_CV1800 = yes;
      PINCTRL = yes;
      PINCTRL_SOPHGO_CV1800B = yes;
      PINCTRL_SOPHGO_SG2002 = yes;
      GPIOLIB = yes;
      GPIO_DWAPB = yes;
      GPIO_CDEV = yes;
      MFD_SYSCON = yes;
      RESET_CONTROLLER = yes;
      RESET_SIMPLE = yes;
      MMC = yes;
      MMC_BLOCK = module;
      MMC_SDHCI = yes;
      MMC_SDHCI_PLTFM = yes;
      MMC_SDHCI_OF_DWCMSHC = yes;
      # Ethernet and DHCP/SSH; preserve the existing nftables firewall.
      NET = yes;
      UNIX = yes;
      PACKET = module;
      INET = yes;
      IPV6 = module;
      NETDEVICES = yes;
      ETHERNET = yes;
      NET_VENDOR_STMICRO = yes;
      STMMAC_ETH = module;
      STMMAC_PLATFORM = module;
      DWMAC_GENERIC = module;
      MDIO_BUS_MUX_MMIOREG = module;
      NETFILTER = yes;
      NETFILTER_ADVANCED = yes;
      NF_CONNTRACK = module;
      NF_TABLES = module;
      NF_TABLES_INET = yes;
      NFT_CT = module;
      NFT_COMPAT = module;
      NFT_LOG = module;
      NFT_FIB_INET = module;
      NFT_FIB_IPV4 = module;
      NFT_FIB_IPV6 = module;
      NFT_REJECT_INET = module;
      NETFILTER_XTABLES = module;
      NETFILTER_XT_MATCH_ADDRTYPE = module;
      NETFILTER_XT_MATCH_CONNTRACK = module;
      NETFILTER_XT_MATCH_STATE = module;
      NETFILTER_XT_MATCH_LIMIT = module;
      NETFILTER_XT_MATCH_PKTTYPE = module;
      NETFILTER_XT_TARGET_LOG = module;
      IP_NF_IPTABLES = module;
      IP6_NF_IPTABLES = module;
      NFT_REJECT = module;
      IP_NF_MATCH_RPFILTER = module;
      IP6_NF_MATCH_RPFILTER = module;
      IP_NF_TARGET_REJECT = module;
      IP6_NF_TARGET_REJECT = module;
      # Dynamically requested USB function drivers must remain packaged.
      USB_SUPPORT = yes;
      USB = yes;
      USB_GADGET = yes;
      USB_DWC2 = yes;
      USB_DWC2_DUAL_ROLE = yes;
      PHY_SOPHGO_CV1800_USB2 = yes;
      USB_G_SERIAL = module;
      USB_F_ACM = module;
      USB_F_SERIAL = module;
      USB_U_SERIAL = module;
      # Audio out through the SoC's internal DAC: the AXI DMA controller and
      # its request mux, ALSA/ASoC, the CV1800B I2S/TDM and DAC drivers, and
      # simple-audio-card (the card is in patches/nano-audio-dt.patch).
      DMADEVICES = yes;
      DW_AXI_DMAC = yes;
      SOPHGO_CV1800B_DMAMUX = yes;
      SOUND = yes;
      SND = yes;
      SND_SOC = yes;
      SND_SOC_CV1800B_TDM = yes;
      SND_SOC_CV1800B_DAC_CODEC = yes;
      SND_SIMPLE_CARD = yes;
      # No PCI, graphics, Wi-Fi, virtualization, tracing, or debug info.
      PCI = no;
      INPUT = no;
      VT = no;
      DRM = no;
      WLAN = no;
      WIRELESS = no;
      VIRTUALIZATION = no;
      EFI = no;
      DEBUG_INFO_NONE = yes;
      FTRACE = no;
      MEM_ALLOC_PROFILING = no;
      TRANSPARENT_HUGEPAGE = no;
    }
    // lib.optionalAttrs display {
      # Experimental framebuffer driver uses one RGB888 DMA buffer (~3 MiB).
      FB = yes;
      FB_DEVICE = yes;
      CMA = yes;
      DMA_CMA = yes;
      CMA_SIZE_MBYTES = freeform "8";
    }
  );
}
