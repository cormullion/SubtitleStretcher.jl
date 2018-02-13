using SubtitleStretcher
using Base.Test

subd = loadsubtitles(string(@__DIR__, "/test.srt"))

ts1, ttxt1 = subd[1]
@test ttxt1[1] == "I thought you'd never get back."

stretch!(subd, [1 => 1, 2 => 2.01])

l = length(subd)
ts2, ttxt2 = subd[l]

# check timestamps have stretched?
@test ts2.starttime > ts1.starttime
@test ts2.finishtime > ts1.finishtime

# but subtitle text unchanged
@test ttxt1[1] == "I thought you'd never get back."

# test save and load
subd1 = Dict()
mktempdir() do tmpdir
    global subd1
    cd(tmpdir)
    savesubtitles(subd, "testout.srt")
    subd1 = loadsubtitles("testout.srt")
end

#reload original
subd = loadsubtitles(string(@__DIR__, "/test.srt"))

# compare with modified, saved, and loaded version

ts0, ttxt0 = subd[1]
ts1, ttxt1 = subd1[1]

@test ts1.starttime < ts2.starttime
@test ttxt0[1] == ttxt1[1]
