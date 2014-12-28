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

    ref int line(int i)
    {
        switch(i)
        {
        case 0:
            return lineA;
        case 1:
            return lineB;
        case 2:
            return lineC;
        default:
            assert(false);
        }
    }

    ref bool equal(int i)
    {
        switch(i)
        {
        case 0:
            return bAEqB;
        case 1:
            return bAEqC;
        case 2:
            return bBEqC;
        default:
            assert(false);
        }
    }
}

alias Diff3LineList = DList!Diff3Line;

