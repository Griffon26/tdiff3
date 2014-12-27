import std.container;

struct Diff
{
    uint nofEquals;

    uint diff1;
    uint diff2;

    this(uint eq, uint d1, uint d2)
    {
        nofEquals = eq;
        diff1 = d1;
        diff2 = d2;
    }
}

alias DiffList = DList!Diff;

struct Diff3Line
{
    int lineA = -1;
    int lineB = -1;
    int lineC = -1;

    bool bAEqB = false;
    bool bAEqC = false;
    bool bBEqC = false;
}

alias Diff3LineList = DList!Diff3Line;

