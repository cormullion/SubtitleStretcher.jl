# SubtitleStretcher

Load, save, and modify subtitle files in `.srt` (subrip) format.

```
subd = loadsubtitles(filename) # returns a dictionary:

Dict{Int64,Tuple} with 1047 entries:
  306 => (SubtitleStretcher.Timestamp(1603.09, 1604.93),
     SubString{String}["My mom told me to never let other people", "take advantage of you."])
  29  => (SubtitleStretcher.Timestamp(218.642, 219.841),
     SubString{String}["\"One could tell Lu Chan was born different\""])
  74  => (SubtitleStretcher.Timestamp(464.768, 467.126),
     SubString{String}["\"Ma must sleep now.\""])
  905 => (SubtitleStretcher.Timestamp(4931.95, 4933.35),
     SubString{String}["He is not of our family."])
  176 => (SubtitleStretcher.Timestamp(1044.37, 1045.53),
     SubString{String}["You should leave."])
  892 => (SubtitleStretcher.Timestamp(4758.17, 4758.81),
     SubString{String}["Lu Chan!"])
  ...
```

Timings can be stretched. For example, say the first subtitle has a time stamp of 1:40, but in the movie the matching scene appears at 1:32; and similarly, the final subtitle has a time stamp of 01:29:13, matching the movie at time 01:30:42, you can adjust all the subtitles with:

```
stretch(subd, ["00:01:40" => "00:01:32", "01:29:13,009" => "01:30:42"])
```

This changes every timestamp proportionally.

Save the subtitle dictionary with:

```
savesubtitles(subd, "movie.srt")
```

To load a `.sub` format file and save it as `.srt`, try:

```
subd = loadsubtitles("movie.sub")
savesubtitles(subd, filename * ".srt")
```

but this hasn't been thoroughly tested...

[![Build Status](https://travis-ci.org/cormullion/SubtitleStretcher.jl.svg?branch=master)](https://travis-ci.org/cormullion/SubtitleStretcher.jl)

[![Coverage Status](https://coveralls.io/repos/cormullion/SubtitleStretcher.jl/badge.svg?branch=master&service=github)](https://coveralls.io/github/cormullion/SubtitleStretcher.jl?branch=master)

[![codecov.io](http://codecov.io/github/cormullion/SubtitleStretcher.jl/coverage.svg?branch=master)](http://codecov.io/github/cormullion/SubtitleStretcher.jl?branch=master)
