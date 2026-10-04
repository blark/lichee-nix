// SPDX-License-Identifier: GPL-2.0-only
/* Minimal single-buffer fbdev scanout using the vendor display register code. */
#include <linux/dma-mapping.h>
#include <linux/fb.h>
#include <linux/module.h>
#include <linux/platform_device.h>
#include <linux/slab.h>
#include "scaler.h"

struct nano_fb {
 struct fb_info *info;
 struct device *dev;
 void *buffer;
 dma_addr_t dma;
 size_t size;
 u32 palette[16];
};

static int nano_fb_mmap(struct fb_info *info, struct vm_area_struct *vma)
{
 struct nano_fb *fb = info->par;
 return dma_mmap_coherent(fb->dev, vma, fb->buffer, fb->dma, fb->size);
}

static int nano_fb_check_var(struct fb_var_screeninfo *var, struct fb_info *info)
{
 if (var->xres != info->var.xres || var->yres != info->var.yres ||
     var->xres_virtual != info->var.xres || var->yres_virtual != info->var.yres ||
     var->bits_per_pixel != 24 || var->xoffset || var->yoffset)
  return -EINVAL;
 *var = info->var;
 return 0;
}

static int nano_fb_setcolreg(unsigned int reg, unsigned int r, unsigned int g,
                            unsigned int b, unsigned int transp, struct fb_info *info)
{
 struct nano_fb *fb = info->par;
 if (reg >= ARRAY_SIZE(fb->palette)) return -EINVAL;
 fb->palette[reg] = ((r >> 8) << 16) | ((g >> 8) << 8) | (b >> 8);
 return 0;
}

static const struct fb_ops nano_fb_ops = {
 .owner = THIS_MODULE,
 .fb_read = fb_sys_read,
 .fb_write = fb_sys_write,
 .fb_fillrect = sys_fillrect,
 .fb_copyarea = sys_copyarea,
 .fb_imageblit = sys_imageblit,
 .fb_mmap = nano_fb_mmap,
 .fb_check_var = nano_fb_check_var,
 .fb_setcolreg = nano_fb_setcolreg,
};

static void nano_fb_release(void *data)
{
 struct nano_fb *fb = data;
 struct sclr_top_cfg *top = sclr_top_get_cfg();
 unregister_framebuffer(fb->info);
 top->disp_enable = false;
 sclr_top_set_cfg(top);
 sclr_disp_tgen_enable(false);
 dma_free_coherent(fb->dev, fb->size, fb->buffer, fb->dma);
 framebuffer_release(fb->info);
}

int nano_fb_register(struct platform_device *pdev);
int nano_fb_register(struct platform_device *pdev)
{
 struct fb_info *info;
 struct nano_fb *fb;
 struct sclr_disp_cfg disp = {0};
 struct sclr_top_cfg *top;
 u32 width, height;
 int ret;
 /* Require explicit dimensions; this driver cannot negotiate panel modes. */
 if (device_property_read_u32(&pdev->dev, "width", &width) ||
     device_property_read_u32(&pdev->dev, "height", &height)) return -EINVAL;
 if (!width || !height || width > 2048 || height > 2048) return -EINVAL;
 ret = dma_set_mask_and_coherent(&pdev->dev, DMA_BIT_MASK(32));
 if (ret) return ret;
 info = framebuffer_alloc(sizeof(*fb), &pdev->dev);
 if (!info) return -ENOMEM;
 fb = info->par; fb->info = info; fb->dev = &pdev->dev;
 fb->size = PAGE_ALIGN(ALIGN(width * 3, 16) * height);
 fb->buffer = dma_alloc_coherent(fb->dev, fb->size, &fb->dma, GFP_KERNEL);
 if (!fb->buffer) { framebuffer_release(info); return -ENOMEM; }
 memset(fb->buffer, 0, fb->size);
 strscpy(info->fix.id, "nano-dsi", sizeof(info->fix.id));
 info->fix.type = FB_TYPE_PACKED_PIXELS;
 info->fix.visual = FB_VISUAL_TRUECOLOR;
 info->fix.line_length = ALIGN(width * 3, 16);
 info->fix.smem_start = fb->dma;
 info->fix.smem_len = fb->size;
 info->var.xres = info->var.xres_virtual = width;
 info->var.yres = info->var.yres_virtual = height;
 info->var.bits_per_pixel = 24;
 info->var.red.offset = 16; info->var.red.length = 8;
 info->var.green.offset = 8; info->var.green.length = 8;
 info->var.blue.offset = 0; info->var.blue.length = 8;
 info->var.activate = FB_ACTIVATE_NOW;
 info->fbops = &nano_fb_ops;
 info->screen_buffer = fb->buffer;
 info->screen_size = fb->size;
 info->pseudo_palette = fb->palette;
 nano_sclr_display_init();
 disp.cache_mode = true;
 disp.fmt = SCL_FMT_BGR_PACKED;
 disp.in_csc = disp.out_csc = SCL_CSC_NONE;
 disp.burst = 7; disp.out_bit = 8;
 disp.mem.width = width; disp.mem.height = height;
 disp.mem.pitch_y = info->fix.line_length;
 disp.mem.addr0 = fb->dma;
 sclr_disp_set_cfg(&disp);
 sclr_disp_enable_window_bgcolor(false);
 top = sclr_top_get_cfg(); top->disp_enable = true;
 sclr_top_set_cfg(top);
 ret = register_framebuffer(info);
 if (ret) {
  top->disp_enable = false; sclr_top_set_cfg(top);
  dma_free_coherent(fb->dev, fb->size, fb->buffer, fb->dma);
  framebuffer_release(info); return ret;
 }
 ret = devm_add_action_or_reset(&pdev->dev, nano_fb_release, fb);
 if (!ret) dev_info(&pdev->dev, "fb%d: %ux%u RGB888, %zu bytes\n", info->node, width, height, fb->size);
 return ret;
}
