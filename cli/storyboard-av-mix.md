# storyboard-av-mix

Both paths are required on every run — no positional path, no auto-detection:

- `--audio <dir>` — VO work dir containing `Chinese/` and `English/`.
- `--video <dir>` — per-shot clips (`01.mp4`, `02.mp4`, …), matched by filename stem.

Outputs are written to `<audio>/Video-Chinese/` and `<audio>/Video-English/`.

```bash
.dependency/python/python .ai/storyboard-av-mix/mix.py --audio path/to/<vo-dir> --video path/to/Video
```

unit tests:

```bash
.dependency/python/python .ai/storyboard-av-mix/test_mix.py
```

Chinese VO only:

```bash
.dependency/python/python .ai/storyboard-av-mix/mix.py --audio path/to/<vo-dir> --video path/to/Video --lang chinese
```

English VO only:

```bash
.dependency/python/python .ai/storyboard-av-mix/mix.py --audio path/to/<vo-dir> --video path/to/Video --lang english
```

Missing either flag → argparse stops with `the following arguments are required: --audio, --video`. Existing path that is not a directory → `Audio dir not found: …` / `Video dir not found: …`, exit code 1.
