__precompile__()

"""
Modify an .srt (subrip) subtitle file.
"""
module SubtitleStretcher

using IterTools

import Base: convert

export loadsubtitles, savesubtitles, stretch!, Timestamp

# hold start and finish times for each subtitle
mutable struct Timestamp
    starttime::Float64  # seconds
    finishtime::Float64 #
end

# convert a timestring ("00:18:29,040") into Float64 seconds
function convert(::Type{Float64}, timestring)
    if contains(timestring, ",")
        starttime, startmilli = split(timestring, ",")
    else
        starttime, startmilli = timestring, "0"
    end
    h1, m1, s1 = map(parse, split(starttime, ":"))
    return ((h1 * 60) + m1) * 60 + s1 + parse(startmilli)/1000
end

# convert two timestrings to a Timestamp
# eg "00:18:29,040 --> 00:18:30,201" -> Timestamp(1109.04, 1110.201)
function convert(::Type{Timestamp}, tstamp)
    rawstarttime, rawfinishtime = split(tstamp, " --> ")
    return Timestamp(convert(Float64, rawstarttime), convert(Float64, rawfinishtime))
end

# forgot why I needed this
convert(::Type{Timestamp}, t::Timestamp) = (t.starttime, t.finishtime)

"""
    timestamptostring(timecode)

Take part of a Timestamp and format it to the required string.

Example:

    timestamptostring(1528.32) -> "02:13:28,320"
"""
function timestamptostring(timecode)
    _min, _sec = divrem(timecode, 60)
    hr, mn    = divrem(_min, 60)
    sc, milli   = fldmod(_sec, 1)
    h = lpad(Int(floor(hr)), 2, "0")
    m = lpad(Int(floor(mn)), 2, "0")
    s = lpad(Int(floor(sc)), 2, "0")
    mill = lpad(convert(Int, round(milli, 3) * 1000), 3, "0")
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
    subd = Dict{Int64, Tuple}()
    if ext == ".srt"
        #redo the numbers, this will correct any errors in the original
        subcounter = 1
        # each group of lines is a subtitle
        for s in groupby(x -> x == "", file) # look for the blank line
           try # some problems with non-Unicode chars?
               if s[1] != ""
                   l = length(s)
                   ts = convert(Timestamp, s[2])
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
                    g1, g2, g4     = rm.captures
                else
                    g1, g2, g3, g4 = rm.captures
                end
            catch
                println("skipping content at line #$n")
            end
            fromtime = parse(g1)/25
            totime   = parse(g2)/25
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
rescale(x, from::NTuple{2,Number}, to::NTuple{2, Number}) =
    ((x - from[1]) / (from[2] - from[1])) * (to[2] - to[1]) + to[1]

"""
    stretch!(subd, markers)

Stretch all timestamps in a subtitle dictionary `subd`.

The `markers` argument is an array of 2 pairs of numbers:

    [oldsubtitletime1 => actualmovietime1, oldsubtitletime2 => actualmovietime2]

Example

    stretch!(subd, [1 => 1.0,  200.0 => 201.0]))
"""
function stretch!(subd, markers::Vector{Pair{T1, T2}} where T1 <: Real where T2 <: Real)
    println("...adjusting subtitle times")
    length(markers) < 2 && error("not enough markers to stretch the timecodes!")
    currentstart, requiredstart = markers[1]
    currentfinish, requiredfinish = markers[2]
    for key in sort(collect(keys(subd)))
           ts = subd[key][1]
           ttxt = subd[key][2]
           newstart = rescale(ts.starttime, currentstart, currentfinish, requiredstart, requiredfinish)
           newfinish = rescale(ts.finishtime, currentstart, currentfinish, requiredstart, requiredfinish)
           newts = Timestamp(newstart, newfinish)
           subd[key] = (newts, ttxt)
    end
    println("...subtitle times adjusted")
    return (requiredfinish - requiredstart)/(currentfinish - currentstart)
end

"""
    stretch!(subd, markers::Vector{Pair{T, T}} where T <: String)

Stretch all timestamps in a subtitle dictionary, using timestrings:

    stretch!(subd, ["00:06:44,580" =>"00:06:48",  "01:48:35,820" => "01:48:37"]
"""
function stretch!(subd, markers::Vector{Pair{T, T}} where T <: String)
    length(markers) < 2 && error("not enough markers to stretch the timecodes!")
    cstart,  rstart = map(s -> convert(Float64, s), markers[1])
    cfinish, rfinish = map(s -> convert(Float64, s), markers[2])
    stretch!(subd, [cstart => rstart, cfinish => rfinish])
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
