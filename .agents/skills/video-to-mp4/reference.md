# Video to MP4 Reference

## Default encode

```bash
ffmpeg -i input.webm -map 0:v:0 -map 0:a:0? \
  -c:v libx264 -preset slow -crf 18 -profile:v high -pix_fmt yuv420p \
  -c:a aac -b:a 192k -movflags +faststart output.mp4
```

The script preserves resolution and frame rate because it supplies no scale or FPS filter. It preserves the source audio sample rate and channel layout because it supplies no `-ar` or `-ac` override.

## Compatible MP4 stream copy

An `.mp4` whose first video stream is H.264 with `yuv420p` or `yuvj420p`, and whose optional first audio stream is AAC, is remuxed without re-encoding:

```bash
ffmpeg -i input.mp4 -map 0:v:0 -map 0:a:0? -c copy -movflags +faststart output.mp4
```

Pass `--force-encode` to use the default encode pipeline instead.

## Quality

Lower CRF values produce higher quality and larger files. The default CRF 18 is visually lossless for many sources. Valid values are 0–51. Presets trade encoding time for compression efficiency without directly changing the quality target.
