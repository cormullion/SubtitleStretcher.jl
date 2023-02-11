"""
Modify an .srt (subrip) subtitle file.

    using SubtitleStretcher
    cd("/Movies/")
    st = loadsubtitles("Pirates of the Caribbean The Curse of the Black Pearl (2003).eng.srt")
    stretch!(st, ["00:01:18" => "00:01:24", "2:03:08" => 7400])
    shift!(st, "00:00:05")
    savesubtitles(st, filename)
"""
module SubtitleStretcher

using IterTools

import Base: convert

export loadsubtitles, savesubtitles, stretch!, shift!, Timestamp

# hold start and finish times for each subtitle
mutable struct Timestamp
    starttime::Float64  # seconds
    finishtime::Float64 #
end

# convert a timestring ("00:18:29,040") into Float64 seconds
function convert(::Type{Float64}, timestring::S where {S<:AbstractString})
    if occursin(",", timestring)
        starttime, startmilli = split(timestring, ",")
    else
        starttime, startmilli = timestring, "0"
    end
    h1, m1, s1 = map(Meta.parse, split(starttime, ":"))
    return ((h1 * 60) + m1) * 60 + s1 + Meta.parse(startmilli) / 1000
end

# convert two timestrings to a Timestamp
# eg "00:18:29,040 --> 00:18:30,201" -> Timestamp(1109.04, 1110.201)
function convert(::Type{Timestamp}, tstamp::S where {S<:AbstractString})
    rawstarttime, rawfinishtime = split(tstamp, " --> ")
    return Timestamp(
        convert(Float64, rawstarttime),
        convert(Float64, rawfinishtime))
end

# forgot why I needed this
#convert(::Type{Timestamp}, t::Timestamp) = (t.starttime, t.finishtime)

"""
    timestamptostring(timecode)

Take part of a Timestamp and format it to the required string.

Example:

    timestamptostring(1528.32) -> "02:13:28,320"
"""
function timestamptostring(timecode)
    _min, _sec = divrem(timecode, 60)
    hr, mn = divrem(_min, 60)
    sc, milli = fldmod(_sec, 1)
    h = lpad(Int(floor(hr)), 2, "0")
    m = lpad(Int(floor(mn)), 2, "0")
    s = lpad(Int(floor(sc)), 2, "0")
    mill = lpad(convert(Int, round(milli, digits=3) * 1000), 3, "0")
    return "$h:$m:$s,$mill"
end

# convert both parts of a Timestamp to the full timestring
# Eg Timestamp(1528.32, 1530.163) -> "02:13:28,320 --> 02:13:30,163"
function convert(::Type{String}, tstamp::Timestamp)
    return timestamptostring(tstamp.starttime) * " --> " * timestamptostring(tstamp.finishtime)
end

"""
    loadsubtitles(filename)

Read subtitles from a file and load them into a dictionary. Files can be `.srt`
or `.sub` format.
"""
function loadsubtitles(filename)
    fn, ext = splitext(filename)
    file = open(filename) do f
        map(chomp, readlines(f)) # get rid of \r\n
    end
    subd = Dict{Int64,Tuple}()
    if ext == ".srt"
        #redo the numbers, this will correct any errors in the original
        global subcounter = 1
        # each group of lines is a subtitle
        for s in groupby(x -> x == "", file) # look for the blank line
            try # some problems with non-Unicode chars?
                if s[1] != ""
                    ts = convert(Timestamp, s[2])
                    l = length(s)
                    # more than one text line is possible
                    subd[subcounter] = (ts, [s[n] for n in 3:l])
                    subcounter += 1
                end
            catch
                println("skipping content at subtitle #$subcounter")
            end
        end
    elseif ext == ".sub"
        # each line is a subtitle
        for n in 1:length(file)
            l = file[n]
            g1, g2, g3, g4 = ["", "", "", ""]
            try # some problems with non-Unicode chars?
                # look for 3
                rm = match(r"\{(.*?)\}\{(.*?)\}(\{.*?\})(.*$)?", l)
                if rm == nothing
                    # look for 2 instead
                    rm = match(r"\{(.*?)\}\{(.*?)\}(.*$)?", l)
                    g1, g2, g4 = rm.captures
                else
                    g1, g2, g3, g4 = rm.captures
                end
            catch
                println("skipping content at line #$n")
            end
            fromtime = Meta.parse(g1) / 25
            totime = Meta.parse(g2) / 25
            textlines = split(g4, "|")
            subd[n] = (Timestamp(fromtime, totime), [textlines...])
        end
    end
    return subd
end

# change value depending on one scale, to another
# eg rescale(0.5, 0, 1, 100, 200) changes the value 0.5
# (midway between 0 and 1) to 150, midway between 100 and 200
rescale(x, from_min, from_max, to_min, to_max) =
    ((x - from_min) / (from_max - from_min)) * (to_max - to_min) + to_min
rescale(x, from::NTuple{2,Number}, to::NTuple{2,Number}) =
    ((x - from[1]) / (from[2] - from[1])) * (to[2] - to[1]) + to[1]

"""
    stretch!(subd, markers)

Stretch all timestamps in a subtitle dictionary `subd`.

The `markers` argument is an array of 2 pairs of numbers:

    [subtitletime1 => actualmovietime1, subtitletime2 => actualmovietime2]

For example, say the first subtitle has a time stamp
of 1:40, but in the movie the matching scene appears at 1:32; and similarly, the
final subtitle has a time stamp of 01:29:13, matching the movie at time
01:30:42, you can adjust all the subtitles with:

```julia
stretch!(subd, ["00:01:40" => "00:01:32", "01:29:13,009" => "01:30:42"])
```
"""
function stretch!(subd, markers::Vector{Pair{T1,T2}} where {T1<:Real} where {T2<:Real})
    println("...adjusting subtitle times")

    if length(markers) == 1
        # assume start at 0
        currentstart, requiredstart = 0, 0
        currentfinish, requiredfinish = markers[1]
    elseif length(markers) == 2
        currentstart, requiredstart = markers[1]
        currentfinish, requiredfinish = markers[2]
    else
        throw(error("not enough markers to stretch the timecodes!"))
    end
    for key in sort(collect(keys(subd)))
        ts = subd[key][1]
        ttxt = subd[key][2]
        newstart = rescale(ts.starttime, currentstart, currentfinish, requiredstart, requiredfinish)
        newfinish = rescale(ts.finishtime, currentstart, currentfinish, requiredstart, requiredfinish)
        newts = Timestamp(newstart, newfinish)
        subd[key] = (newts, ttxt)
    end
    println("...subtitle times adjusted")
    return (requiredfinish - requiredstart) / (currentfinish - currentstart)
end

"""
    stretch!(subd, markers::Vector{Pair{T, T}} where T <: String)

Stretch all timestamps in a subtitle dictionary, using timestrings:

```julia
# [subtitletime => actualmovietime]
stretch!(subd, ["01:48:35,820" => "01:48:37"]

# [subtitletime1 => actualmovietime1, subtitletime2 => actualmovietime2]
stretch!(subd, ["00:06:44,580" =>"00:06:48", "01:48:35,820" => "01:48:37"]
```

Timestrings are H:M:S:
```
"00:18:29,040"
"00:18:29"
```
"""
function stretch!(subd, markers::Vector{Pair{T,T}} where {T<:String})
    if length(markers) == 1
        # assume start at 0
        currentstart, requiredstart = "00:00:00", "00:00:00"
        currentfinish, requiredfinish = markers[1]
    elseif length(markers) == 2
        currentstart, requiredstart = markers[1]
        currentfinish, requiredfinish = markers[2]
    else
        throw(error("not enough markers to stretch the timecodes!"))
    end
    cstart, rstart = map(s -> convert(Float64, s), (currentstart, requiredstart))
    cfinish, rfinish = map(s -> convert(Float64, s), (currentfinish, requiredfinish))
    stretch!(subd, [cstart => rstart, cfinish => rfinish])
end

"""
    stretch!(subd, markers::Vector)

Stretch using mixture of numeric timestamps and strings.

    stretch!(st, [100 => "00:01:18", "2:03:08" => 7400])
"""
function stretch!(subd, markers::Vector)
    length(markers) !== 2 && error("not enough markers to stretch the timecodes!")
    r = []
    for a in [markers[1][1], markers[1][2], markers[2][1], markers[2][1]]
        if typeof(a) <: Real
            push!(r, a)
        else
            push!(r, convert(Float64, a))
        end
    end
    cstart, rstart, cfinish, rfinish = r
    stretch!(subd, [cstart => rstart, cfinish => rfinish])
end

"""
    shift!(subd, seconds::Float64)

Shift all timestamps in a subtitle dictionary `subd` by `duration`.

Example

    shift!(subd, seconds)) 
"""
function shift!(subd, seconds)
    println("...adjusting subtitle times")
    for key in sort(collect(keys(subd)))
        ts = subd[key][1]
        ttxt = subd[key][2]
        newstart = ts.starttime + seconds
        newfinish = ts.finishtime + seconds
        if newstart < 0.0 || newfinish < 0.0
            throw(error("timestamps are now negative!"))
        end
        newts = Timestamp(newstart, newfinish)
        subd[key] = (newts, ttxt)
    end
    println("...subtitle times shifted by $seconds")
end

"""
    shift!(subd, timestring::String)

Shift all timestamps in a subtitle dictionary `subd` by `timestring`.

# convert a timestring ("00:18:29,040") into Float64 seconds
function convert(::Type{Float64}, timestring::S where {S<:AbstractString})

Example

    shift!(subd, seconds)) 
"""
function shift!(subd, timestring::String)
    println("...adjusting subtitle times")
    seconds = convert(Float64, timestring)
    for key in sort(collect(keys(subd)))
        ts = subd[key][1]
        ttxt = subd[key][2]
        newstart = ts.starttime + seconds
        newfinish = ts.finishtime + seconds
        if newstart < 0.0 || newfinish < 0.0
            throw(error("timestamps are now negative!"))
        end
        newts = Timestamp(newstart, newfinish)
        subd[key] = (newts, ttxt)
    end
    println("...subtitle times shifted by $seconds")
end

"""
    savesubtitles(subd, filename)

Save a dictionary of subtitles to a file.
"""
function savesubtitles(subd, filename)
    open(filename, "w") do f
        for key in sort(collect(keys(subd)))
            println(f, key)
            println(f, convert(String, subd[key][1]))
            for i in subd[key][2]
                println(f, i)
            end
            println(f)
        end
    end
end

end # module
