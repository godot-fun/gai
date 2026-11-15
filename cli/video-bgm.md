# video-bgm

Unit tests:

```bash
.dependency/python/python .ai/video-bgm/test_add_bgm.py
```

Add a background-audio folder (default output: `<video-dir>/video-bgm/<basename>`):

```bash
.dependency/python/python .ai/video-bgm/add_bgm.py --video .ai/test/video/opening.mp4 --audio path/to/music-folder
```

Add a folder of audio files in natural filename order:

```bash
.dependency/python/python .ai/video-bgm/add_bgm.py --video .ai/test/video/opening.mp4 --audio path/to/music-folder
```

Custom output path:

```bash
.dependency/python/python .ai/video-bgm/add_bgm.py --video .ai/test/video/opening.mp4 --audio path/to/music-folder --output .ai/test/video/video-bgm/opening.mp4
```
