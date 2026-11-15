# Video Split Reference

## Default pipeline

Probe the source duration with FFprobe, resolve the split point, then encode both parts independently:

```bash
# Part 1: start to split point
ffmpeg -i input.mp4 -t SPLIT_SECONDS \
  -map 0:v:0 -map 0:a:0? \
  -c:v libx264 -preset medium -crf 18 -pix_fmt yuv420p \
  -c:a aac -b:a 192k -movflags +faststart output_part1.mp4

# Part 2: split point to end
ffmpeg -ss SPLIT_SECONDS -i input.mp4 -t REMAINING_SECONDS \
  -map 0:v:0 -map 0:a:0? \
  -c:v libx264 -preset medium -crf 18 -pix_fmt yuv420p \
  -c:a aac -b:a 192k -movflags +faststart output_part2.mp4
```

The optional audio mapping supports silent videos. No scale or frame-rate filter is applied, so source resolution and frame rate are preserved.

## Why re-encode?

Stream-copy cuts normally begin on nearby keyframes rather than the requested frame. That can make two nominal halves visibly unequal. Re-encoding decodes at the requested timestamp and produces precise segment boundaries.

## Output layout

For `Video/intro.mov`:

```text
Video/video-split/intro_part1.mp4
Video/video-split/intro_part2.mp4
```

Use `--output` to select another directory. The source is never modified.
