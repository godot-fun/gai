# video-to-mp4

Unit tests:

```bash
.dependency/python/python .ai/video-to-mp4/test_convert.py
```

Convert one video (default output: `<video-dir>/video-to-mp4/<basename>.mp4`):

```bash
.dependency/python/python .ai/video-to-mp4/convert.py --video .ai/test/video/opening.mp4
```

Custom output and quality:

```bash
.dependency/python/python .ai/video-to-mp4/convert.py --video input.webm --output output/clip.mp4 --crf 20 --preset medium
```

Force re-encode of a compatible MP4:

```bash
.dependency/python/python .ai/video-to-mp4/convert.py --video input.mp4 --force-encode
```
