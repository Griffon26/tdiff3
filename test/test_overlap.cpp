#include "gtest/gtest.h"
#include "../src/common.h"

TEST(TestOverlap, first_contained_in_second)
{
    /* First contained in second */
    ASSERT_EQ(overlap(LineNumberRange(0, 2), LineNumberRange(0, 5)), LineNumberRange(0, 2));
    ASSERT_EQ(overlap(LineNumberRange(2, 5), LineNumberRange(0, 5)), LineNumberRange(2, 5));
    ASSERT_EQ(overlap(LineNumberRange(1, 4), LineNumberRange(0, 5)), LineNumberRange(1, 4));
}

TEST(TestOverlap, second_contained_in_first)
{
    /* Second contained in first */
    ASSERT_EQ(overlap(LineNumberRange(0, 5), LineNumberRange(0, 2)), LineNumberRange(0, 2));
    ASSERT_EQ(overlap(LineNumberRange(0, 5), LineNumberRange(2, 5)), LineNumberRange(2, 5));
    ASSERT_EQ(overlap(LineNumberRange(0, 5), LineNumberRange(1, 4)), LineNumberRange(1, 4));
}

TEST(TestOverlap, some_overlap)
{
    /* Some overlap */
    ASSERT_EQ(overlap(LineNumberRange(0, 3), LineNumberRange(2, 5)), LineNumberRange(2, 3));
    ASSERT_EQ(overlap(LineNumberRange(0, 3), LineNumberRange(3, 5)), LineNumberRange(3, 3));
    ASSERT_EQ(overlap(LineNumberRange(2, 3), LineNumberRange(0, 3)), LineNumberRange(2, 3));
    ASSERT_EQ(overlap(LineNumberRange(3, 5), LineNumberRange(0, 3)), LineNumberRange(3, 3));
}

TEST(TestOverlap, no_overlap)
{
    /* No overlap */
    ASSERT_EQ(overlap(LineNumberRange(0, 2), LineNumberRange(3, 5)), LineNumberRange(-1, -1));
    ASSERT_EQ(overlap(LineNumberRange(3, 5), LineNumberRange(0, 2)), LineNumberRange(-1, -1));
}

TEST(TestOverlap, first_range_infinite__non_infinite_overlap)
{
    /* First range is infinite, non-infinite overlap */
    ASSERT_EQ(overlap(LineNumberRange(2, -1), LineNumberRange(0, 1)), LineNumberRange(-1, -1));
    ASSERT_EQ(overlap(LineNumberRange(2, -1), LineNumberRange(0, 2)), LineNumberRange(2, 2));
    ASSERT_EQ(overlap(LineNumberRange(2, -1), LineNumberRange(0, 5)), LineNumberRange(2, 5));
    ASSERT_EQ(overlap(LineNumberRange(2, -1), LineNumberRange(2, 5)), LineNumberRange(2, 5));
    ASSERT_EQ(overlap(LineNumberRange(2, -1), LineNumberRange(4, 5)), LineNumberRange(4, 5));
}

TEST(TestOverlap, second_range_infinite__non_infinite_overlap)
{
    /* Second range is infinite, non-infinite overlap */
    ASSERT_EQ(overlap(LineNumberRange(0, 1), LineNumberRange(2, -1)), LineNumberRange(-1, -1));
    ASSERT_EQ(overlap(LineNumberRange(0, 2), LineNumberRange(2, -1)), LineNumberRange(2, 2));
    ASSERT_EQ(overlap(LineNumberRange(0, 5), LineNumberRange(2, -1)), LineNumberRange(2, 5));
    ASSERT_EQ(overlap(LineNumberRange(2, 5), LineNumberRange(2, -1)), LineNumberRange(2, 5));
    ASSERT_EQ(overlap(LineNumberRange(4, 5), LineNumberRange(2, -1)), LineNumberRange(4, 5));
}

TEST(TestOverlap, infinite_overlap)
{
    /* Infinite overlap */
    ASSERT_EQ(overlap(LineNumberRange(2, -1), LineNumberRange(0, -1)), LineNumberRange(2, -1));
    ASSERT_EQ(overlap(LineNumberRange(2, -1), LineNumberRange(2, -1)), LineNumberRange(2, -1));
    ASSERT_EQ(overlap(LineNumberRange(2, -1), LineNumberRange(5, -1)), LineNumberRange(5, -1));
}

