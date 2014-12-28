import dunit;

void assertEqual(T, U)(T actual, U expected, lazy string msg = null,
        string file = __FILE__,
        size_t line = __LINE__)
{
    assertEquals(expected, actual, msg, file, line);
}

