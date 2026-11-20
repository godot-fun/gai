# storyboard-av-mix

Inputs are separated by language:

- `--audio <dir>` — VO root containing `Chinese/` and `English/`.
- `--video <dir>` — video root containing `Chinese/` and `English/`.
- `--output <dir>` — optional output root; default `<audio>/Video/`.

Outputs are `<output>/Chinese/` and `<output>/English/`.

```bash
.dependency/python/python .ai/storyboard-av-mix/mix.py --audio path/to/Audio --video path/to/Video --output path/to/Output
```

Default output:

```bash
.dependency/python/python .ai/storyboard-av-mix/mix.py --audio path/to/Audio --video path/to/Video
```

Chinese only:

```bash
.dependency/python/python .ai/storyboard-av-mix/mix.py --audio path/to/Audio --video path/to/Video --lang chinese
```

English only:

```bash
.dependency/python/python .ai/storyboard-av-mix/mix.py --audio path/to/Audio --video path/to/Video --lang english
```

Legacy flat `Video/01.mp4` is accepted only when neither language subfolder
exists. The script never falls back from one language folder to the other.

Unit tests:

```bash
.dependency/python/python .ai/storyboard-av-mix/test_mix.py
```
