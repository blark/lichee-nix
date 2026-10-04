# CanMV fallback comparison

Checked 2026-10-04. Upstream source pinned to revision `437f4da9d9d09202b7e9d4ec6dd90ef6ea5c7d37`:
https://github.com/canmv-k230/mpp/blob/437f4da9d9d09202b7e9d4ec6dd90ef6ea5c7d37/kernel/connector/src/panels/mipi_ili9881.c

The original source and BSD redistribution terms are retained in
`reference/canmv-mipi_ili9881.c`. Converted 202 upstream DCS commands
into `ili9881c-canmv-two-lane.experimental.txt`, preserving every payload and
delay and adding only `B7 03` immediately after page-1 selection.
The upstream explicitly selects four lanes and never writes page-1 B7.
Neither initialization has been confirmed for the LCKFB glass.

| Mode | HSA/HBP/HFP | VSA/VBP/VFP | Pixel clock | Refresh | RGB888 two-lane payload rate |
|---|---|---|---|---|---|
| Current LCKFB documented mode | 12/18/18 | 4/12/24 | 66 MHz | 58.963 Hz | 792 Mbps/lane |
| CanMV | 8/48/52 | 8/20/40 | 73.439 MHz (integer upstream) | ~60 Hz | 881.268 Mbps/lane |
| CanMV reduced refresh candidate | 8/48/52 | 8/20/40 | 61.199 MHz | ~50 Hz | 734.388 Mbps/lane |

**Correction to the supplied notes:** those CanMV porches yield 73.439 MHz,
not 78.3 MHz: `908 * 1348 * 60 / 1000` using upstream integer arithmetic.

Both use command pages 3, 4, 1, then 0, but their register values differ
substantially: gate mapping/timing (page 3), panel power settings (page 4),
and positive/negative gamma and other settings (page 1).
There are 116 different or missing register entries, by page: {0: 3, 1: 48, 3: 55, 4: 10}.
The register comparison below uses each sequence's last write per register.

Our Waveshare profile sends sleep-out before the main table with 120 ms delay,
then again at its end with 150 ms delay; display-on is followed by 20 ms.
CanMV sends sleep-out once at the end with 120 ms delay and no display-on delay.
Waveshare sets page-0 RGB888 `3A=77` and orientation `36=00`; CanMV omits both.
Waveshare sends `35 00`; CanMV sends a one-byte `35`, preserved verbatim.

## Using the fallback

Start by changing only `hardware.licheervNano.display.initialization` to
`./display/ili9881c-canmv-two-lane.experimental.txt` while keeping the current
LCKFB timings. This isolates the initialization-table change.
To reproduce the entire CanMV mode, also change `display/nano-panel.c` porches
and pixel clock to the CanMV values above, then rebuild `.#display-sd-image`.
Changing the text file alone does **not** change transmitter timings.
No default image/profile or board state was changed by this comparison.

## Register differences

| Page | Register | Waveshare profile | CanMV upstream |
|---|---|---|---|
| 0 | 35 | 00 | absent |
| 0 | 36 | 00 | absent |
| 0 | 3A | 77 | absent |
| 1 | 31 | 00 | 0A |
| 1 | 40 | 33 | absent |
| 1 | 50 | 96 | AE |
| 1 | 51 | 96 | A9 |
| 1 | 52 | absent | 00 |
| 1 | 53 | 71 | 56 |
| 1 | 54 | absent | 00 |
| 1 | 55 | 8F | 59 |
| 1 | 60 | 23 | 1F |
| 1 | 62 | absent | 07 |
| 1 | 63 | absent | 00 |
| 1 | A1 | 1D | 20 |
| 1 | A2 | 2A | 2D |
| 1 | A3 | 10 | 13 |
| 1 | A4 | 15 | 16 |
| 1 | A5 | 28 | 29 |
| 1 | A6 | 1C | 1D |
| 1 | A7 | 1D | 1E |
| 1 | A8 | 7E | 77 |
| 1 | A9 | 1D | 17 |
| 1 | AA | 29 | 24 |
| 1 | AB | 6B | 6A |
| 1 | AC | 1A | 22 |
| 1 | AD | 18 | 24 |
| 1 | AE | 4B | 5A |
| 1 | AF | 20 | 2B |
| 1 | B0 | 27 | 2C |
| 1 | B1 | 50 | 4D |
| 1 | B2 | 64 | 6F |
| 1 | B3 | 39 | 3F |
| 1 | B7 | 03 | absent |
| 1 | C1 | 1D | 1E |
| 1 | C2 | 2A | 2B |
| 1 | C3 | 10 | 13 |
| 1 | C4 | 15 | 16 |
| 1 | C6 | 1C | 1A |
| 1 | C8 | 7E | 75 |
| 1 | C9 | 1D | 18 |
| 1 | CA | 29 | 25 |
| 1 | CB | 6B | 71 |
| 1 | CC | 1A | 23 |
| 1 | CD | 18 | 28 |
| 1 | CE | 4B | 59 |
| 1 | CF | 20 | 2C |
| 1 | D0 | 27 | 30 |
| 1 | D1 | 50 | 55 |
| 1 | D2 | 64 | 6B |
| 1 | D3 | 39 | 3F |
| 3 | 03 | 73 | 53 |
| 3 | 04 | 00 | 13 |
| 3 | 06 | 0A | 04 |
| 3 | 09 | 61 | 22 |
| 3 | 0A | 00 | 22 |
| 3 | 0F | 61 | 25 |
| 3 | 10 | 61 | 25 |
| 3 | 1E | 40 | 44 |
| 3 | 20 | 06 | 02 |
| 3 | 21 | 01 | 03 |
| 3 | 3A | 00 | 40 |
| 3 | 3B | 00 | 40 |
| 3 | 50 | 10 | 01 |
| 3 | 51 | 32 | 23 |
| 3 | 52 | 54 | 45 |
| 3 | 53 | 76 | 67 |
| 3 | 54 | 98 | 89 |
| 3 | 55 | BA | AB |
| 3 | 56 | 10 | 01 |
| 3 | 57 | 32 | 23 |
| 3 | 58 | 54 | 45 |
| 3 | 59 | 76 | 67 |
| 3 | 5A | 98 | 89 |
| 3 | 5B | BA | AB |
| 3 | 5C | DC | CD |
| 3 | 5D | FE | EF |
| 3 | 5E | 00 | 11 |
| 3 | 5F | 0E | 01 |
| 3 | 60 | 0F | 00 |
| 3 | 61 | 0C | 15 |
| 3 | 62 | 0D | 14 |
| 3 | 63 | 06 | 0C |
| 3 | 64 | 07 | 0D |
| 3 | 65 | 02 | 0E |
| 3 | 66 | 02 | 0F |
| 3 | 67 | 02 | 06 |
| 3 | 69 | 01 | 02 |
| 3 | 6A | 00 | 02 |
| 3 | 6C | 15 | 02 |
| 3 | 6D | 14 | 02 |
| 3 | 6E | 02 | 08 |
| 3 | 75 | 0E | 01 |
| 3 | 76 | 0F | 00 |
| 3 | 77 | 0C | 15 |
| 3 | 78 | 0D | 14 |
| 3 | 79 | 06 | 0C |
| 3 | 7A | 07 | 0D |
| 3 | 7B | 02 | 0E |
| 3 | 7C | 02 | 0F |
| 3 | 7D | 02 | 08 |
| 3 | 7F | 01 | 02 |
| 3 | 80 | 00 | 02 |
| 3 | 82 | 14 | 02 |
| 3 | 83 | 15 | 02 |
| 3 | 84 | 02 | 06 |
| 4 | 30 | absent | 03 |
| 4 | 31 | absent | 75 |
| 4 | 33 | absent | 14 |
| 4 | 35 | absent | 1F |
| 4 | 38 | 01 | 02 |
| 4 | 3A | 94 | 24 |
| 4 | 6E | 2A | 3B |
| 4 | 6F | 33 | 55 |
| 4 | 7A | absent | 10 |
| 4 | B5 | 06 | 27 |
