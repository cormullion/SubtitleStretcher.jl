# SubtitleStretcher

Load, save, and modify subtitle files in `.srt` (subrip) format.

```julia
subd = loadsubtitles(filename) 
```

returns a dictionary of subtitles and timings.

To shift all subtitles by `s` seconds

```julia
shift!(subd, s)
```

To stretch subtitles, use `stretch!()`. For example, say the first subtitle has a time stamp of 1:40, but in the movie the matching scene appears at 1:32; and similarly, the final subtitle has a time stamp of 01:29:13, matching the movie at time 01:30:42, you can adjust all the subtitles with:

```julia
stretch!(subd, ["00:01:40" => "00:01:32", "01:29:13,009" => "01:30:42"])
```

which changes every timestamp proportionally, stretching them out as necessary. This might compensate for timestamps that gradually go adrift as the movie plays. It won't help if scenes have been cut, though.

To export the subtitle dictionary as a `.srt` file:

```julia
savesubtitles(subd, "movie.srt")
```

To load a `.sub` format file and save it as `.srt`, try:

```julia
subd = loadsubtitles("movie.sub")
savesubtitles(subd, filename * ".srt")
```

but this hasn't been thoroughly tested...

[![Coverage Status](https://coveralls.io/repos/cormullion/SubtitleStretcher.jl/badge.svg?branch=master&service=github)](https://coveralls.io/github/cormullion/SubtitleStretcher.jl?branch=master)

[![codecov.io](http://codecov.io/github/cormullion/SubtitleStretcher.jl/coverage.svg?branch=master)](http://codecov.io/github/cormullion/SubtitleStretcher.jl?branch=master)
