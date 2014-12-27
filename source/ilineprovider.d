import std.typecons;

synchronized interface ILineProvider
{
    Nullable!string get(uint line);
    Nullable!string get(uint firstLine, uint lastLine);
    int getLastLineNumber();
}

