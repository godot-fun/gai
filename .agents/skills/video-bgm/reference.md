# Video BGM Reference

The script naturally sorts the supported audio files directly inside one folder. It then probes the video duration and audio streams and performs two FFmpeg stages:

1. Normalize supplied audio to stereo 48 kHz PCM and join tracks with an `acrossfade` of up to one second. This temporary WAV is the reusable playlist bed.
2. Loop the playlist bed, trim it to the video duration, apply 20% gain and an ending fade, then mix it with the original audio using `amix`. If the video is silent, use the bed directly.

The video stream is always copied (`-c:v copy`). Only the final audio stream is encoded. Temporary files are removed automatically.

The output keeps the source filename and container. The audio encoder is selected for the container: AAC for MP4/MOV/MKV/MPEG transport containers, Vorbis for WebM/OGV, and MP3 for AVI.
