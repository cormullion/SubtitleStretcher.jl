using SubtitleStretcher
using Test

subd = loadsubtitles(string(@__DIR__, "/test.srt"))

ts1, ttxt1 = subd[1]
@test ttxt1[1] == "I thought you'd never get back."

stretch!(subd, [1 => 1, 2 => 2.01])
stretch!(subd, [5.4 => "00:05:46,312", 5.5 => "00:05:48"])
stretch!(subd, ["00:05:46,312" => 5.4, 5.5 => "00:05:48"])
stretch!(subd, ["00:05:46,312" => "00:05:48", 5.4 => 5.5])
stretch!(subd, [5.4 => 5.5, "00:05:46,312" => "00:05:48"])
stretch!(subd, ["00:05:46,312" => "00:05:48"])

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

# reload original
subd = loadsubtitles(string(@__DIR__, "/test.srt"))

# test shift by 10 seconds
ts0, ttxt0 = subd[1]
shift!(subd, 10)

ts1, ttxt1 = subd[1]
@test isapprox(ts1.starttime, 313.517, atol=0.1)
@test isapprox(ts1.finishtime, 315.999, atol=0.1)

# reload original
subd = loadsubtitles(string(@__DIR__, "/test.srt"))

# test shift by "00:00:10.0"
ts0, ttxt0 = subd[1]
shift!(subd, "00:00:10.0")

ts1, ttxt1 = subd[1]
@test isapprox(ts1.starttime, 313.517, atol=0.1)
@test isapprox(ts1.finishtime, 315.999, atol=0.1)

