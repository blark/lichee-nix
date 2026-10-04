/* SPDX-License-Identifier: GPL-2.0-only */
#include <stdbool.h>
#include <stdint.h>
#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <errno.h>
#include <fcntl.h>
#include <sys/ioctl.h>
#include <unistd.h>
#include "linux/vo_mipi_tx.h"

/* LCKFB official 10.1-inch mode: H 800/818/830/848, V 1280/1304/1308/1320. */
static struct combo_dev_cfg_s config = {
 .lane_id = {MIPI_TX_LANE_0, MIPI_TX_LANE_CLK, MIPI_TX_LANE_1, -1, -1},
 .output_mode = OUTPUT_MODE_DSI_VIDEO, .video_mode = BURST_MODE,
 .output_format = OUT_FORMAT_RGB_24_BIT,
 .sync_info = {
  .vid_hsa_pixels = 12, .vid_hbp_pixels = 18, .vid_hfp_pixels = 18,
  .vid_hline_pixels = 800,
  .vid_vsa_lines = 4, .vid_vbp_lines = 12, .vid_vfp_lines = 24,
  .vid_active_lines = 1280, .vid_vsa_pos_polarity = false,
 },
 .pixel_clk = 66000,
};
struct command { uint8_t data[CMD_MAX_NUM]; unsigned size, delay; };

static void describe(void)
{
 printf("800x1280 RGB888, 58.96 Hz LCKFB mode; pixel clock %u kHz\n", config.pixel_clk);
 printf("2 lanes; TX0=data0, TX1=clock, TX2=data1; approximate lane rate %.3f Mbps\n",
        config.pixel_clk * 24.0 / 2 / 1000);
 puts("ILI9881C two-lane command: FF 98 81 01; B7 03; FF 98 81 00");
}

static int parse(const char *path, struct command *commands, size_t *count, bool *startup)
{
 FILE *file = fopen(path, "r");
 char line[1024]; unsigned number = 0, page = 0; bool two_lanes = false, sleep_out = false;
 if (!file) { perror(path); return -1; }
 while (fgets(line, sizeof(line), file)) {
  char *comment = strchr(line, '#'), *token, *save = NULL;
  struct command *cmd;
  number++;
  if (comment) *comment = 0;
  token = strtok_r(line, " \t\r\n", &save);
  if (!token) continue;
  if (*count >= 1024) goto invalid;
  cmd = &commands[(*count)++];
  if (!strcmp(token, "delay")) {
   char *end; token = strtok_r(NULL, " \t\r\n", &save);
   if (!token) goto invalid;
   unsigned long n = strtoul(token, &end, 10);
   if (*end || n > 5000 || strtok_r(NULL, " \t\r\n", &save)) goto invalid;
   cmd->delay = n; continue;
  }
  do {
   char *end; unsigned long n = strtoul(token, &end, 16);
   if (*end || n > 255 || cmd->size >= CMD_MAX_NUM) goto invalid;
   cmd->data[cmd->size++] = n;
  } while ((token = strtok_r(NULL, " \t\r\n", &save)));
  if (page == 0 && cmd->size == 1 && cmd->data[0] == 0x11) sleep_out = true;
  if (page == 0 && cmd->size == 1 && cmd->data[0] == 0x29 && sleep_out) *startup = true;
  if (cmd->size == 4 && cmd->data[0] == 0xff &&
      cmd->data[1] == 0x98 && cmd->data[2] == 0x81) page = cmd->data[3];
  if (page == 1 && cmd->size == 2 && cmd->data[0] == 0xb7) {
   if (cmd->data[1] != 0x03) goto invalid;
   two_lanes = true;
  }
 }
 if (ferror(file)) { perror(path); fclose(file); return -1; }
 fclose(file);
 if (!two_lanes || page != 0) {
  fputs("Sequence must select page 1, set B7=03, and return to page 0.\n", stderr);
  return -1;
 }
 return 0;
invalid:
 fprintf(stderr, "%s:%u: invalid command\n", path, number);
 fclose(file); return -1;
}

int main(int argc, char **argv)
{
 struct command *commands; size_t count = 0; int fd, ret = 1; bool startup = false;
 if (argc == 2 && !strcmp(argv[1], "--describe")) { describe(); return 0; }
 if (argc != 3 || (strcmp(argv[1], "--validate") && strcmp(argv[1], "--init"))) {
  fprintf(stderr, "Usage: %s --describe | --validate init.txt | --init init.txt\n", argv[0]); return 2;
 }
 commands = calloc(1024, sizeof(*commands));
 if (!commands) { perror("calloc"); return 1; }
 if (parse(argv[2], commands, &count, &startup)) { free(commands); return 1; }
 describe();
 if (!strcmp(argv[1], "--validate")) {
  printf("Validated %zu commands; full panel compatibility remains untested.\n", count);
  free(commands); return 0;
 }
 if (!startup) {
  fputs("Full initialization must include page-0 sleep-out (11) then display-on (29).\n", stderr);
  free(commands); return 1;
 }
 fd = open("/dev/mipi-tx", O_RDWR | O_CLOEXEC);
 if (fd < 0) { perror("/dev/mipi-tx"); free(commands); return 1; }
 struct hs_settle_s settle = {.prepare = 6, .zero = 32, .trail = 1};
 if (ioctl(fd, CVI_VIP_MIPI_TX_DISABLE) ||
     ioctl(fd, CVI_VIP_MIPI_TX_SET_DEV_CFG, &config) ||
     ioctl(fd, CVI_VIP_MIPI_TX_SET_HS_SETTLE, &settle)) goto error;
 for (size_t i = 0; i < count; i++) {
  struct command *cmd = &commands[i];
  if (!cmd->size) { usleep(cmd->delay * 1000); continue; }
  struct cmd_info_s request = {
   .data_type = cmd->size == 1 ? 0x05 : cmd->size == 2 ? 0x15 : 0x39,
   .cmd_size = cmd->size, .cmd = cmd->data,
  };
  if (ioctl(fd, CVI_VIP_MIPI_TX_SET_CMD, &request)) goto error;
 }
 if (ioctl(fd, CVI_VIP_MIPI_TX_ENABLE)) goto error;
 ret = 0; goto done;
error:
 perror("MIPI ioctl");
 ioctl(fd, CVI_VIP_MIPI_TX_DISABLE);
done:
 close(fd); free(commands); return ret;
}
